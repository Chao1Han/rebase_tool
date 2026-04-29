#!/usr/bin/env python3
"""Generate issue body JSON for Copilot conflict resolution.

Usage:
    generate_issue_body.py <title> <report_file> <conflict_branch> <base_branch> <date_tag> \
                           <copilot_bot> <target_repo> <custom_instructions> [model]

Output: JSON payload for gh api to stdout.
"""
import json
import sys


def main():
    if len(sys.argv) < 9:
        print("Usage: generate_issue_body.py <title> <report_file> <conflict_branch> "
              "<base_branch> <date_tag> <copilot_bot> <target_repo> <custom_instructions> [model]",
              file=sys.stderr)
        sys.exit(1)

    title = sys.argv[1]
    report_file = sys.argv[2]
    conflict_branch = sys.argv[3]
    base_branch = sys.argv[4]
    date_tag = sys.argv[5]
    copilot_bot = sys.argv[6]
    target_repo = sys.argv[7]
    custom_instructions = sys.argv[8]
    model = sys.argv[9] if len(sys.argv) > 9 else ""

    # Read conflict report
    try:
        with open(report_file) as f:
            report = f.read().strip()
    except (FileNotFoundError, PermissionError):
        report = "Conflict details unavailable."

    if not report:
        report = "Conflict details unavailable."

    body_lines = [
        "## Weekly Rebase conflict",
        "",
        f"**Conflict branch:** `{conflict_branch}`",
        f"**Target branch:** `{base_branch}`",
        "",
        "### Conflict details",
        "",
        report,
        "",
        "### Requirements",
        "",
        f"1. Resolve all conflict markers on `{conflict_branch}`",
        "2. Prefer upstream, preserve Intel-specific code",
        f"3. Open PR targeting `{base_branch}`, title: `Weekly rebase {date_tag} - conflict resolution`",
    ]
    body = "\n".join(body_lines)

    payload = {
        "title": title,
        "body": body,
        "assignees": [copilot_bot],
        "labels": ["rebase", "copilot-task"],
        "agent_assignment": {
            "target_repo": target_repo,
            "base_branch": conflict_branch,
            "custom_instructions": custom_instructions,
            "model": model,
        },
    }

    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
