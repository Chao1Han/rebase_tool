# Rebase Tool Test Repo (upstream v3.0)

This repo is used to test the weekly rebase automation workflow.

## Configuration
- line-length = 120
- target-version = py310
- upstream-added = true
- intel-private = true

## Upstream v2.0 Release Notes
- Refactored hello interface
- CUDA improvements

## Upstream Build Notes
- Build system migrated to CMake
- CI matrix expanded

## Contributing
- See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines
- PRs welcome!

## Intel Private Notes
- XPU SYCL backend optimized
- Private CUDA path added

## Intel Build Notes
- Custom SYCL compiler integration
- XPU device support matrix

## Intel Developer Guide
- See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for Intel-specific guidelines
- XPU-specific tests required for all kernel changes
