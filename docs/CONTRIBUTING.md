<<<<<<< HEAD
# Contributing (upstream)

## Code Style
- Use black formatter
- Line length: 120
- Python 3.10+

## Testing
- Run `pytest tests/` before submitting
- All CI checks must pass
=======
# Contributing (Intel Internal)

## Code Style
- Use ruff formatter
- Line length: 120
- Python 3.12+

## Testing
- Run `pytest tests/ -x --xpu` for XPU tests
- Internal CI must pass

## Intel-Specific
- XPU kernel changes need SYCL review
- Update auto-resolve list if adding new private files
>>>>>>> 271d5d5 (private: Add Intel-specific CONTRIBUTING guide)
