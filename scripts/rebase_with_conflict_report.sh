#!/bin/bash
# Enhanced rebase script that generates a conflict report for Copilot
# Usage: rebase_with_conflict_report.sh <repo_name> <branch_name> <rebase_target> <rebase_branch> <report_file>
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
JSON_PATH="${SCRIPT_DIR}/../conflict_auto_resolve_files.json"
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
> "$REPORT_FILE"

# Attempt rebase
if ! git rebase "$REBASE_TARGET"; then
    while true; do
        echo "Rebase hit conflicts, checking auto-resolvable files..."

        CONFLICTED_FILES=$(git status --porcelain | awk '/^[AU][DU] |^UU |^AA / {print $2}')
        UNHANDLED_FILES=()

        for file in $CONFLICTED_FILES; do
            if is_in_auto_resolve_list "$file"; then
                echo "Auto-resolving: $file (--theirs)"
                git checkout --theirs "$file"
                git add "$file"
            else
                UNHANDLED_FILES+=("$file")
            fi
        done

        if [[ ${#UNHANDLED_FILES[@]} -gt 0 ]]; then
            echo "=== Unresolvable conflicts found ==="

            # Get current rebase commit info
            CURRENT_COMMIT=$(cat .git/rebase-merge/stopped-sha 2>/dev/null || echo "unknown")
            COMMIT_MSG=$(git log --format='%s' -1 "$CURRENT_COMMIT" 2>/dev/null || echo "unknown")

            # Write report header
            {
                echo "### Conflicting Commit"
                echo ""
                echo "- **SHA:** \`$CURRENT_COMMIT\`"
                echo "- **Message:** $COMMIT_MSG"
                echo ""
                echo "### Conflicted Files"
                echo ""
            } >> "$REPORT_FILE"

            # For each unhandled conflict, capture the diff
            for file in "${UNHANDLED_FILES[@]}"; do
                {
                    echo "#### \`$file\`"
                    echo ""
                    echo '<details><summary>Conflict diff</summary>'
                    echo ""
                    echo '```diff'
                    # Show the conflict content (limited to 200 lines per file)
                    head -200 "$file" 2>/dev/null || echo "(file not readable)"
                    echo '```'
                    echo ""
                    echo '</details>'
                    echo ""
                } >> "$REPORT_FILE"
            done

            # Also capture overall status
            {
                echo "### Git Status"
                echo ""
                echo '```'
                git status --short
                echo '```'
                echo ""
                echo "### How to reproduce locally"
                echo ""
                echo '```bash'
                echo "cd $REPO_NAME"
                echo "git fetch upstream"
                echo "git checkout $BRANCH_NAME"
                echo "git checkout -b $REBASE_BRANCH"
                echo "git rebase $REBASE_TARGET"
                echo "# Then resolve conflicts in: ${UNHANDLED_FILES[*]}"
                echo '```'
            } >> "$REPORT_FILE"

            echo "Conflict report written to $REPORT_FILE"
            echo "Unhandled conflicts in: ${UNHANDLED_FILES[*]}"
            exit 1
        fi

        # All conflicts in this step were auto-resolved, continue
        if GIT_EDITOR=true git rebase --continue; then
            break
        else
            echo "Continuing rebase after auto-resolve..."
        fi
    done
fi

echo "Rebase completed successfully."
exit 0
