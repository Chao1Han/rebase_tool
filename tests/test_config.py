"""Tests for the repository Ruff configuration."""

from pathlib import Path
import tomllib


CONFIG_PATH = Path(__file__).resolve().parents[1] / "config.toml"


def load_config():
    """Load the checked-in Ruff configuration."""
    return tomllib.loads(CONFIG_PATH.read_text())


def test_line_length():
    """Ensure the configured line length stays within the expected range."""
    line_length = load_config()["tool"]["ruff"]["line-length"]
    assert isinstance(line_length, int), "line-length must be an integer"
    assert 80 <= line_length <= 120, "line-length must be reasonable"


def test_target_version():
    """Ensure the configured target-version is supported."""
    supported = ["py38", "py39", "py310", "py311", "py312"]
    target_version = load_config()["tool"]["ruff"]["target-version"]
    assert target_version in supported


def test_optional_ruff_format_settings_are_compatible():
    """Either keep the private config or use the reviewed compatible format block."""
    format_config = load_config()["tool"]["ruff"].get("format")
    assert format_config is None or isinstance(format_config, dict)
    if format_config is None:
        return

    assert format_config["quote-style"] == "double"
    assert format_config["indent-style"] == "space"
