#!/bin/bash
# check_auto_resolve_diff.sh
# Compare auto-resolve files before and after rebase to detect upstream changes
# that were silently applied (no conflict) but might break private functionality.
#
# Usage: check_auto_resolve_diff.sh <repo_name> <branch_name> <old_base_commit> [output_file]
#
# Arguments:
#   repo_name       - Repository name (for JSON lookup)
#   branch_name     - Branch being rebased (for JSON lookup)
#   old_base_commit - The pre-rebase base commit (to compare against HEAD)
#   output_file     - Optional: write diff report to this file (default: stdout)

set -e

REPO_NAME="$1"
BRANCH_NAME="$2"
OLD_BASE="$3"
OUTPUT_FILE="${4:-}"

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
JSON_PATH="${SCRIPT_DIR}/conflict_auto_resolve_files.json"

if [[ ! -f "$JSON_PATH" ]]; then
    echo "No conflict_auto_resolve_files.json found."
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: 'jq' not found, skipping auto-resolve diff check."
    exit 0
fi

# Load auto-resolve file list
mapfile -t AUTO_RESOLVE_FILES < <(jq -r --arg repo "$REPO_NAME" --arg branch "$BRANCH_NAME" '.[$repo][$branch][]?' "$JSON_PATH")

if [[ ${#AUTO_RESOLVE_FILES[@]} -eq 0 ]]; then
    echo "No auto-resolve files configured for $REPO_NAME/$BRANCH_NAME"
    exit 0
fi

CHANGED_FILES=()
DIFF_OUTPUT=""

for file in "${AUTO_RESOLVE_FILES[@]}"; do
    # Check if file was modified between old base and current HEAD
    if git diff --quiet "$OLD_BASE" HEAD -- "$file" 2>/dev/null; then
        continue
    fi
    CHANGED_FILES+=("$file")
    DIFF_OUTPUT+="### \`$file\`"$'\n'
    DIFF_OUTPUT+='```diff'$'\n'
    DIFF_OUTPUT+="$(git diff "$OLD_BASE" HEAD -- "$file" | head -80)"$'\n'
    DIFF_OUTPUT+='```'$'\n'$'\n'
done

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    echo "All auto-resolve files unchanged after rebase."
    exit 0
fi

# Generate report
REPORT="## Auto-Resolve Files Changed After Rebase

The following files are in \`conflict_auto_resolve_files.json\` (always keep private version on conflict) but received **non-conflicting upstream changes** during rebase. These changes were applied silently and may affect private functionality.

**Changed: ${#CHANGED_FILES[@]}/${#AUTO_RESOLVE_FILES[@]} files**

${DIFF_OUTPUT}

### Action Required
Review the above diffs to verify upstream changes don't break Intel-private behavior.
If a change is problematic, revert it on the rebase branch before merging."

if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$REPORT" > "$OUTPUT_FILE"
    echo "Auto-resolve diff report written to $OUTPUT_FILE"
    echo "changed_count=${#CHANGED_FILES[@]}" 
else
    echo "$REPORT"
fi

# Exit with code 0 (informational, not a failure)
exit 0
