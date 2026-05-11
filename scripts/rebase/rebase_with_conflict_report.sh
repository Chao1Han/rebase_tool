#!/bin/bash
# Enhanced rebase script that generates a conflict report for Copilot
# Usage: rebase_with_conflict_report.sh <repo_name> <branch_name> <rebase_target> <rebase_branch> <report_file>
#
# Exit codes:
#   0 = rebase completed successfully (no conflicts)
#   1 = rebase failed (unexpected error)
#   2 = rebase completed with conflict markers (linear history preserved)
set -e

REPO_NAME=$1
BRANCH_NAME=$2
REBASE_TARGET=$3
REBASE_BRANCH=$4
REPORT_FILE=${5:-/tmp/conflict_report.md}

echo "Attempting rebase: $REPO_NAME branch $BRANCH_NAME onto $REBASE_TARGET"

# Load auto-resolve list from JSON (same logic as original)
AUTO_RESOLVE_FILES=()
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
JSON_PATH="${SCRIPT_DIR}/conflict_auto_resolve_files.json"
if [[ -f "$JSON_PATH" ]]; then
    if command -v jq >/dev/null 2>&1; then
        mapfile -t AUTO_RESOLVE_FILES < <(jq -r --arg repo "$REPO_NAME" --arg branch "$BRANCH_NAME" '.[$repo][$branch][]?' "$JSON_PATH")
        echo "Loaded auto-resolve files: ${AUTO_RESOLVE_FILES[*]}"
    else
        echo "Warning: 'jq' not found, skipping auto-resolve list."
    fi
fi

is_in_auto_resolve_list() {
    local file="$1"
    for allowed in "${AUTO_RESOLVE_FILES[@]}"; do
        [[ "$file" == "$allowed" ]] && return 0
    done
    return 1
}

# Initialize report
: > "$REPORT_FILE"
HAS_UNRESOLVED_CONFLICTS=false
CONFLICT_STEP=0
# Track per-file conflict count (file -> count mapping via temp file)
FILE_CONFLICT_LOG=$(mktemp)
: > "$FILE_CONFLICT_LOG"

# Attempt rebase
if ! git rebase "$REBASE_TARGET"; then
    while true; do
        echo "Rebase hit conflicts, checking auto-resolvable files..."

        CONFLICTED_FILES=()
        mapfile -d '' -t CONFLICTED_FILES < <(git diff --name-only --diff-filter=U -z)
        UNHANDLED_FILES=()

        for file in "${CONFLICTED_FILES[@]}"; do
            if is_in_auto_resolve_list "$file"; then
                echo "Auto-resolving: $file (--theirs)"
                git checkout --theirs "$file"
                git add "$file"
            else
                UNHANDLED_FILES+=("$file")
            fi
        done

        if [[ ${#UNHANDLED_FILES[@]} -gt 0 ]]; then
            HAS_UNRESOLVED_CONFLICTS=true
            CONFLICT_STEP=$((CONFLICT_STEP + 1))
            echo "=== Unresolvable conflicts found (step $CONFLICT_STEP), force-continuing to preserve linear history ==="

            # Get current rebase commit info
            CURRENT_COMMIT=$(cat .git/rebase-merge/stopped-sha 2>/dev/null || echo "unknown")
            COMMIT_MSG=$(git log --format='%s' -1 "$CURRENT_COMMIT" 2>/dev/null || echo "unknown")

            # Record per-file conflict occurrences
            for file in "${UNHANDLED_FILES[@]}"; do
                echo "$file" >> "$FILE_CONFLICT_LOG"
            done

            # Log step info (commit + files) for summary (tab-delimited)
            printf '%s\t%s\t%s\t%s\n' "$CONFLICT_STEP" "$CURRENT_COMMIT" "$COMMIT_MSG" "${UNHANDLED_FILES[*]}" >> "${REPORT_FILE}.steps"

            # Force-add conflicted files (with markers) and continue rebase
            # This preserves linear history — Copilot will resolve markers later
            for file in "${UNHANDLED_FILES[@]}"; do
                git add "$file"
            done
        fi

        # Continue rebase (either all auto-resolved, or force-continued with markers)
        if GIT_EDITOR=true git rebase --continue 2>/dev/null; then
            break
        else
            echo "Continuing rebase (next commit)..."
        fi
    done
fi

if [[ "$HAS_UNRESOLVED_CONFLICTS" == true ]]; then
    # Generate report: conflict summary table + multi-conflict warnings
    {
        echo "## Conflict Steps ($CONFLICT_STEP total)"
        echo ""
        echo "| Step | Commit | Message | Conflicted Files |"
        echo "|------|--------|---------|------------------|"
        if [[ -f "${REPORT_FILE}.steps" ]]; then
            while IFS=$'\t' read -r step sha msg files; do
                echo "| $step | \`${sha:0:10}\` | $msg | $files |"
            done < "${REPORT_FILE}.steps"
        fi
        echo ""

        MULTI_CONFLICT_FILES=$(sort "$FILE_CONFLICT_LOG" | uniq -c | sort -rn | awk '$1 > 1 {print $1, $2}')
        if [[ -n "$MULTI_CONFLICT_FILES" ]]; then
            echo "## ⚠️ Multi-Conflict Files"
            echo ""
            echo "These files had conflicts in **multiple steps**. Resolve them strictly in step order."
            echo ""
            echo "| File | Conflict Count |"
            echo "|------|---------------|"
            while IFS=' ' read -r count file; do
                echo "| \`$file\` | $count |"
            done <<< "$MULTI_CONFLICT_FILES"
            echo ""
        fi
    } >> "$REPORT_FILE"
    rm -f "${REPORT_FILE}.steps"

    rm -f "$FILE_CONFLICT_LOG"
    echo "Rebase completed (linear) but with conflict markers ($CONFLICT_STEP steps)."
    echo "Conflict report written to $REPORT_FILE"
    exit 2
fi

rm -f "$FILE_CONFLICT_LOG"
echo "Rebase completed successfully."
exit 0
