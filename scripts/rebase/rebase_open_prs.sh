#!/bin/bash
# rebase_open_prs.sh — Rebase all open PR branches after a base branch rebase.
# Supports both same-repo and fork PRs with backup before modification.
#
# Usage: rebase_open_prs.sh <base_branch> <repo>
set -euo pipefail

BASE_BRANCH="$1"
REPO="$2"

echo "=== Rebase open PRs targeting ${BASE_BRANCH} in ${REPO} ==="

# Fetch rich PR data: number, branch, author, fork owner/repo
PR_JSON=$(gh pr list \
  --base "$BASE_BRANCH" \
  --state open \
  --json number,headRefName,author,headRepositoryOwner,headRepository \
  --repo "$REPO" \
  -L 500)

PR_COUNT=$(echo "$PR_JSON" | jq 'length')
if [[ "$PR_COUNT" -eq 0 ]]; then
  echo "No open PRs targeting ${BASE_BRANCH}"
  exit 0
fi

echo "Found ${PR_COUNT} open PR(s)"

FAILED_PRS=()
SUCCESS_PRS=()
SKIPPED_PRS=()

# Use process substitution to avoid subshell (pipe | while creates subshell,
# losing array modifications). This keeps arrays visible after the loop.
while read -r pr; do
  PR_NUM=$(echo "$pr" | jq -r '.number')
  HEAD_BRANCH=$(echo "$pr" | jq -r '.headRefName')
  AUTHOR=$(echo "$pr" | jq -r '.author.login')
  FORK_OWNER=$(echo "$pr" | jq -r '.headRepositoryOwner.login')
  FORK_REPO=$(echo "$pr" | jq -r '.headRepository.name')

  # Skip rebase/conflict branches
  if [[ "$HEAD_BRANCH" == rebase_* ]] || [[ "$HEAD_BRANCH" == dev_rebase_* ]] || [[ "$HEAD_BRANCH" == conflict/* ]]; then
    echo "  SKIP: #${PR_NUM} (${HEAD_BRANCH}) — rebase branch"
    SKIPPED_PRS+=("$PR_NUM")
    continue
  fi

  echo ""
  echo "--- PR #${PR_NUM}: ${HEAD_BRANCH} (by ${AUTHOR}) ---"

  # Determine if this is a fork PR
  REPO_OWNER=$(echo "$REPO" | cut -d'/' -f1)
  REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
  IS_FORK=false
  if [[ "$FORK_OWNER" != "$REPO_OWNER" ]] || [[ "$FORK_REPO" != "$REPO_NAME" ]]; then
    IS_FORK=true
    echo "  Fork PR: ${FORK_OWNER}/${FORK_REPO}"
  fi

  # Fetch the PR ref
  if ! git fetch origin "pull/${PR_NUM}/head:pr-${PR_NUM}" 2>/dev/null; then
    echo "  ERROR: Failed to fetch PR #${PR_NUM}"
    FAILED_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}|fetch_failure")
    continue
  fi

  # Backup the original PR branch before modification
  BACKUP_REF="pr-backup/pr-${PR_NUM}"
  echo "  Backing up to ${BACKUP_REF}"
  git push origin "pr-${PR_NUM}:refs/heads/${BACKUP_REF}" --force 2>/dev/null || {
    echo "  WARNING: Failed to push backup, continuing anyway"
  }

  # Checkout and attempt rebase
  git checkout -B "pr-${PR_NUM}" "pr-${PR_NUM}"

  if git rebase "origin/${BASE_BRANCH}"; then
    echo "  Rebase succeeded, pushing..."

    if [[ "$IS_FORK" == true ]]; then
      # Fork PR: push back to the fork repository
      FORK_URL="https://github.com/${FORK_OWNER}/${FORK_REPO}.git"
      git remote add "fork-${PR_NUM}" "$FORK_URL" 2>/dev/null || true
      if git push "fork-${PR_NUM}" "pr-${PR_NUM}:${HEAD_BRANCH}" --force-with-lease; then
        echo "  OK: Pushed to fork ${FORK_OWNER}/${FORK_REPO}:${HEAD_BRANCH}"
        SUCCESS_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}")
      else
        echo "  ERROR: Push to fork failed (likely no write access)"
        FAILED_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}|fork_push_failure")
      fi
      git remote remove "fork-${PR_NUM}" 2>/dev/null || true
    else
      # Same-repo PR: push to origin
      if git push origin "pr-${PR_NUM}:${HEAD_BRANCH}" --force-with-lease; then
        echo "  OK: Pushed to origin/${HEAD_BRANCH}"
        SUCCESS_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}")
      else
        echo "  ERROR: Push failed"
        FAILED_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}|push_failure")
      fi
    fi
  else
    git rebase --abort 2>/dev/null || true
    echo "  FAIL: Rebase conflicts"
    FAILED_PRS+=("${PR_NUM}|${HEAD_BRANCH}|${AUTHOR}|conflict")
  fi

  # Clean up local branch
  git checkout "${BASE_BRANCH}" 2>/dev/null || git checkout --detach
  git branch -D "pr-${PR_NUM}" 2>/dev/null || true
done < <(echo "$PR_JSON" | jq -c '.[]')

# Return to base branch
git checkout "${BASE_BRANCH}" 2>/dev/null || true

# Post comments on failed PRs
for entry in "${FAILED_PRS[@]:-}"; do
  [[ -z "$entry" ]] && continue
  IFS='|' read -r PR_NUM HEAD_BRANCH AUTHOR REASON <<< "$entry"
  COMMENT="The base branch \`${BASE_BRANCH}\` was rebased onto upstream.\n"
  COMMENT+="This PR branch \`${HEAD_BRANCH}\` could not be auto-rebased"
  if [[ "$REASON" == "fork_push_failure" ]]; then
    COMMENT+=" (no write access to fork).\n\n"
  else
    COMMENT+=" due to conflicts.\n\n"
  fi
  COMMENT+="Please rebase manually:\n\n"
  COMMENT+="    git fetch origin\n"
  COMMENT+="    git checkout ${HEAD_BRANCH}\n"
  COMMENT+="    git rebase origin/${BASE_BRANCH}\n"
  COMMENT+="    # resolve conflicts\n"
  COMMENT+="    git push --force-with-lease\n\n"
  COMMENT+="A backup of the original branch is at \`pr-backup/pr-${PR_NUM}\`.\n\n"
  COMMENT+="@${AUTHOR}"
  echo -e "$COMMENT" | gh pr comment "$PR_NUM" --repo "$REPO" -F - || true
done

# Post comments on successful PRs
for entry in "${SUCCESS_PRS[@]:-}"; do
  [[ -z "$entry" ]] && continue
  IFS='|' read -r PR_NUM HEAD_BRANCH AUTHOR <<< "$entry"
  gh pr comment "$PR_NUM" --repo "$REPO" \
    --body "The base branch \`${BASE_BRANCH}\` was rebased onto upstream. This PR branch \`${HEAD_BRANCH}\` has been automatically rebased. Please verify your changes." || true
done

# Summary
echo ""
echo "=== Summary ==="
echo "Success: ${#SUCCESS_PRS[@]} | Failed: ${#FAILED_PRS[@]} | Skipped: ${#SKIPPED_PRS[@]}"
if [[ ${#FAILED_PRS[@]} -gt 0 ]]; then
  echo "Failed PRs:"
  for entry in "${FAILED_PRS[@]}"; do
    IFS='|' read -r PR_NUM HEAD_BRANCH AUTHOR REASON <<< "$entry"
    echo "  - #${PR_NUM} (${HEAD_BRANCH}) — ${REASON}"
  done
fi
