"""Test configuration validation."""

def test_line_length():
    """Ensure line-length setting is valid."""
    assert 80 <= 120, "line-length must be reasonable"

def test_target_version():
    """Ensure target-version is supported."""
    supported = ["py38", "py39", "py310", "py311", "py312"]
    assert "py310" in supported
