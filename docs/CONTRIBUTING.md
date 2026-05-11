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
