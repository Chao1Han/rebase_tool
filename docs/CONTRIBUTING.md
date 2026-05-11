# Contributing (Upstream + Intel)

## Code Style
- Use black formatter
- Line length: 120
- Python 3.10+

## Testing
- Run `pytest tests/` before submitting
- All CI checks must pass

## Intel-Specific
- XPU kernel changes need SYCL review
- Run `pytest tests/ -x --xpu` for XPU tests when applicable
- Internal CI must pass
- Update auto-resolve list if adding new private files
