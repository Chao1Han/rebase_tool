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
            echo "=== Unresolvable conflicts found, force-continuing to preserve linear history ==="

            # Get current rebase commit info
            CURRENT_COMMIT=$(cat .git/rebase-merge/stopped-sha 2>/dev/null || echo "unknown")
            COMMIT_MSG=$(git log --format='%s' -1 "$CURRENT_COMMIT" 2>/dev/null || echo "unknown")

            # Write report
            {
                echo "### Conflicting Commit"
                echo ""
                echo "- **SHA:** \`$CURRENT_COMMIT\`"
                echo "- **Message:** $COMMIT_MSG"
                echo ""
                echo "### Conflicted Files"
                echo ""
                for file in "${UNHANDLED_FILES[@]}"; do
                    echo "#### \`$file\`"
                    echo ""
                    echo '<details><summary>Conflict diff</summary>'
                    echo ""
                    echo '```diff'
                    head -200 "$file" 2>/dev/null || echo "(file not readable)"
                    echo '```'
                    echo ""
                    echo '</details>'
                    echo ""
                done
                echo "---"
                echo ""
            } >> "$REPORT_FILE"

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
    # Append summary to report
    {
        echo "### How to reproduce locally"
        echo ""
        echo '```bash'
        echo "git fetch upstream"
        echo "git checkout $BRANCH_NAME"
        echo "git checkout -b $REBASE_BRANCH"
        echo "git rebase $REBASE_TARGET"
        echo '```'
    } >> "$REPORT_FILE"

    echo "Rebase completed (linear) but with conflict markers."
    echo "Conflict report written to $REPORT_FILE"
    exit 2
fi

echo "Rebase completed successfully."
exit 0
