---
applyTo: "**"
---

# Rebase Conflict Resolution Guide

This instruction applies when resolving merge/rebase conflicts between
the Intel internal branches (`main`, `dev/upstream`) and `upstream/main` (intel/torch-xpu-ops).

## Why This Fork Exists

This is an Intel internal fork of torch-xpu-ops with two branches:

- **`main` (JGS):** Internal branch for Intel GPU Server products.
  Contains CRI testing, Acceptance testing, SYCL-TLA FlashAttention (XE4),
  oneDNN pin updates, and CI customized for internal infrastructure.
- **`dev/upstream`:** Preparation branch for upstreaming SYCL free function refactoring.

Intel patches are rebased **on top of** the latest `upstream/main` weekly.

During `git rebase`, when resolving conflicts with commands such as
`git checkout --ours <file>` / `git checkout --theirs <file>`:
- `ours` = `upstream/main` (the new base)
- `theirs` = the Intel commit being replayed

> **Note:** `ours` / `theirs` do **not** mean the same thing in every Git workflow.
> The mapping above is specific to this rebase flow and should not be generalized
> to normal `git merge` conflict resolution or all mergetool UIs.
## Intel-Private Features

### `main` branch
- CRI/Acceptance test infrastructure
- SYCL-TLA FlashAttention v4 kernels (XE4)
- oneDNN private branch pinning
- `cmake/BuildFlags.cmake`: `macro(set_build_flags)` wrapper, C++20, JGS AOT targets, `cri` device
- `cmake/SYCLTLA.cmake`: SYCL-TLA build support
- Internal CI runners and docker images

### `dev/upstream` branch
- SYCL free function kernel refactoring (~78 commits)
- UT container build/test infrastructure

## Rule 1: Intel-Private Files — ALWAYS keep Intel version

On conflict during rebase, choose the version from the Intel commit being replayed for:
- `.github/workflows/*` — CI is internal-specific
- `.github/scripts/build.sh`, `.github/scripts/env.sh`
- `.github/scripts/ut_result_check.sh`
- `cmake/BuildFlags.cmake` — substantial structural differences from upstream
- `cmake/SYCLTLA.cmake`

## Rule 2: Source Files — Merge both sides

When upstream refactors a kernel or operator file that Intel has also modified:
1. Start with the upstream version as the base
2. Re-apply Intel's changes on top
3. For SYCL free function refactoring (dev/upstream): Intel renames functor-based
   kernels to free function style. If upstream changed the same kernel, apply the
   free function transformation to upstream's new version.

## Rule 3: New Intel-Only Files — Keep by default during conflict resolution

Files that exist only in the Intel fork should not be deleted during merge/rebase
conflict resolution solely because they do not exist in upstream.

Keep these by default:
- `cmake/SYCLTLA.cmake`
- SYCL-TLA kernel files under `src/ATen/native/transformers/xpu/flash_attn/sycltla*`
- Any file in a directory that doesn't exist in upstream

Exceptions are allowed only when one of the following is true:
- the file is being intentionally renamed or moved, and the Intel-specific functionality
  is preserved in the new location
- upstream has adopted or replaced the functionality, and the Intel-only file is no
  longer needed
- the file is being intentionally cleaned up, and that cleanup is approved by the
  owning Intel maintainers/rebase owners and documented in the PR description

If an exception applies, describe the reason and the approving owner(s) in the PR body.
## Common Conflict Patterns

### `cmake/BuildFlags.cmake`
- Upstream may change compiler flags or AOT targets
- Intel has: `macro(set_build_flags)` wrapper, C++20 (vs upstream C++17),
  SYCL-TLA targets, `cri` device target
- Resolution: **keep Intel's version**. Structural differences are too large to merge.

### CI workflow files
- Internal CI uses different runner labels, docker images, test configs
- Resolution: **keep Intel's version entirely**

### SYCL kernel files (dev/upstream)
- Intel migrates functor-based kernels → free function style
- If upstream changed the same kernel's logic, apply Intel's refactoring pattern
  to the new upstream logic

## After Resolution

- Open a PR targeting the branch specified in the issue (`main` or `dev/upstream`)
- Title: `Weekly rebase YYYYMMDD - conflict resolution`
- List each conflicted file and resolution strategy in the PR body
- Ensure zero conflict markers remain
