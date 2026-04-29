#!/usr/bin/env python3
"""Generate PR body for weekly rebase PRs.

Usage:
    generate_pr_body.py <label> <commit_count> <old_base> <new_base> <date_tag> <base_branch> [commit_list_file]

Output: PR body markdown to stdout.
"""
import sys


def main():
    if len(sys.argv) < 7:
        print(
            "Usage: generate_pr_body.py <label> <commit_count>"
            " <old_base> <new_base> <date_tag> <base_branch>"
            " [commit_list_file]",
            file=sys.stderr,
        )
        sys.exit(1)

    label = sys.argv[1]
    commit_count = sys.argv[2]
    old_base = sys.argv[3][:12]
    new_base = sys.argv[4][:12]
    date_tag = sys.argv[5]
    base_branch = sys.argv[6]
    commit_list_file = sys.argv[7] if len(sys.argv) > 7 else None

    commit_list = "No new upstream commits."
    if commit_list_file:
        try:
            with open(commit_list_file) as f:
                commit_list = f.read().strip() or "No new upstream commits."
        except FileNotFoundError:
            pass

    # Derive tag prefix from base_branch to match post-rebase.yml tagging logic
    tag_map = {
        "main": "rebase",
        "master_next": "rebase-torch",
        "dev/upstream": "rebase-dev",
    }
    tag_prefix = tag_map.get(base_branch, f"rebase-{base_branch.replace('/', '-')}")

    print(f"## Automated Weekly Rebase ({label})")
    print()
    print("All conflicts auto-resolved.")
    print()
    print(f"### Upstream commits included ({commit_count} new)")
    print()
    print(f"Old base: `{old_base}` -> New base: `{new_base}`")
    print()
    print("<details><summary>Commit list</summary>")
    print()
    print("```")
    print(commit_list)
    print("```")
    print()
    print("</details>")
    print()
    print(f"> After merging, a tag `{tag_prefix}-{date_tag}` will be created automatically.")
    print(f"> Open PR branches based on `{base_branch}` will be rebased.")


if __name__ == "__main__":
    main()
