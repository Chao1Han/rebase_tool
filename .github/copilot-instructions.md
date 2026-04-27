# Copilot Instructions — Rebase Conflict Resolution

## Background: Why This Fork Exists

This is the rebase automation tooling for two Intel private forks:

### 1. `frameworks.ai.pytorch.private-gpu` (branch: `master_next`)
- **Upstream:** `pytorch/pytorch` (main)
- **Purpose:** Intel GPU (XPU) support private fork of PyTorch, containing patches not yet upstreamed
- **~66 Intel-only commits** on top of upstream, of which ~30 are `xpu.txt` pin updates
- **Key private features (will NOT be upstreamed soon):**
  - Level Zero API migration (`c10/xpu/`, SYCL Event → L0 API, SYCL memory → L0 API)
  - Bazel build system (`.bazelrc`, `BUILD.bazel`, `WORKSPACE`, `third_party/*.BUILD`)
  - XPU-specific cmake flags (`cmake/Modules/FindLevelZero.cmake`, `cmake/public/xpu.cmake`)
  - MXFP4/MXFP8 scaled_mm implementation for XPU
  - XE4 SDPA SYCL-TLA operator
  - Private `third_party/xpu.txt` pinning (torch-xpu-ops commit for private fork)
  - Certain `USE_LEVEL_ZERO` build flags
- **Files Intel always modifies vs upstream:**
  - `third_party/xpu.txt` — Intel pins a private torch-xpu-ops commit (different from upstream)
  - `torch/utils/cpp_extension.py` — Intel adds XPU/SYCL compilation support
  - `c10/xpu/XPUFunctions.cpp`, `c10/xpu/XPUCachingAllocator.cpp` — L0 API changes
  - `CMakeLists.txt` — XPU/L0 build options
  - `c10/macros/Macros.h` — XPU-specific macros
  - `cmake/Modules/FindMKLDNN.cmake` — Intel oneDNN integration

### 2. `frameworks.ai.pytorch.torch-xpu-ops` (branches: `main`, `dev/upstream`)
- **Upstream:** `intel/torch-xpu-ops` (main)
- **`main` branch (JGS):** Internal branch for Intel GPU Server products
  - Contains: CRI testing, Acceptance testing, SYCL-TLA FlashAttention (XE4), oneDNN pin updates
  - CI/CD workflows customized for internal infrastructure
  - `cmake/BuildFlags.cmake` has different compiler flags, AOT targets, C++20 (vs upstream C++17)
- **`dev/upstream` branch:** Preparation branch for upstreaming
  - Contains: SYCL free function refactoring (~78 commits of kernel migration)
  - These changes are being prepared for contribution to `intel/torch-xpu-ops`
- **Files Intel always modifies vs upstream:**
  - `.github/workflows/*` — CI customized for internal runners
  - `.github/scripts/build.sh`, `env.sh` — internal build configuration
  - `cmake/BuildFlags.cmake` — different SYCL targets, AOT options, C++ standard
  - `cmake/SYCLTLA.cmake` — SYCL-TLA build support (not in upstream)

## Rebase Direction

Intel patches are rebased **on top of** the latest upstream/main. The rebase replays each Intel commit onto the new upstream HEAD. In git rebase terminology during conflict resolution:
- `ours` = upstream/main (the new base)
- `theirs` = the Intel commit being replayed

## Conflict Resolution Rules

### Rule 1: Intel-Private Files — ALWAYS keep Intel version (`--theirs` in rebase)

These files have Intel-specific content that diverges from upstream intentionally. On conflict, **always keep the Intel (theirs) version**:

**For `private-gpu`:**
- `third_party/xpu.txt`
- `torch/utils/cpp_extension.py`
- `c10/macros/Macros.h`
- `cmake/Modules/FindMKLDNN.cmake`
- `c10/xpu/XPUFunctions.cpp`
- `c10/xpu/XPUCachingAllocator.cpp`
- Any file under `c10/xpu/`, `torch/xpu/`, `aten/src/ATen/xpu/`
- Any file under `cmake/Modules/FindLevelZero.cmake`, `cmake/public/xpu.cmake`
- Bazel files: `.bazelrc`, `BUILD.bazel`, `WORKSPACE`, `third_party/*.BUILD`

**For `torch-xpu-ops`:**
- `.github/workflows/*` (CI is internal-specific)
- `.github/scripts/build.sh`, `.github/scripts/env.sh`
- `cmake/BuildFlags.cmake`
- `cmake/SYCLTLA.cmake`
- `.github/scripts/ut_result_check.sh`

### Rule 2: Core PyTorch Files — Carefully merge both sides

When upstream refactors a file that Intel has also modified (e.g., `aten/src/ATen/native/*.cpp`, `torch/_inductor/`):
1. **Start with the upstream version** as the base
2. **Re-apply Intel's changes** on top of the new upstream code
3. Intel changes typically add XPU device checks like:
   - `case DeviceType::XPU:` in switch statements
   - `#ifdef USE_XPU` / `#if defined(C10_XPU_)` guards
   - XPU-specific kernel dispatch registrations
4. Look for patterns: if Intel's change is just adding a new `case` or `#ifdef` block, graft it into the upstream version

### Rule 3: New Intel-Only Files — Keep unconditionally

Files that exist only in the Intel fork (not in upstream) should never be deleted:
- `cmake/Modules/FindLevelZero.cmake`
- `aten/src/ATen/native/mkldnn/xpu/Attention.h`
- SYCL-TLA kernel files under `src/ATen/native/transformers/xpu/flash_attn/sycltla*`
- Any file in a directory that doesn't exist in upstream

### Rule 4: Upstream-Only Changes — Accept as-is

If a file is changed only on the upstream side and Intel hasn't touched it, the rebase should apply cleanly. No action needed.

## Common Conflict Patterns

### Pattern A: `cmake/BuildFlags.cmake` (torch-xpu-ops)
- **Upstream** may change compiler flags, C++ standard, or AOT targets
- **Intel** has: `macro(set_build_flags)` wrapper, C++20, SYCL-TLA specific targets, `cri` device target
- **Resolution:** Keep Intel's version of this file. It has substantial structural differences.

### Pattern B: `torch/utils/cpp_extension.py` (private-gpu)
- **Upstream** evolves the build extension mechanism
- **Intel** adds SYCL/DPC++ compiler detection and XPU compilation paths
- **Resolution:** Take upstream's version, then verify Intel's XPU additions are present. If Intel added blocks like `if IS_XPU:` or SYCL compiler detection, re-add them.

### Pattern C: Test files with device lists
- Many test files have `device_list = ['cpu', 'cuda']` that Intel extends to include `'xpu'`
- **Resolution:** Take upstream's test changes, ensure `'xpu'` is in device lists where Intel had added it.

### Pattern D: CI workflow files (torch-xpu-ops)
- Internal CI uses different runner labels, docker images, and test configurations
- **Resolution:** Keep Intel's version entirely. These are internal-only.

## After Resolution

- Open a PR targeting the branch specified in the issue
- Title format: `Weekly rebase YYYYMMDD - conflict resolution`
- In the PR body, list each conflicted file and the resolution strategy used
- Ensure no conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) remain in any file
