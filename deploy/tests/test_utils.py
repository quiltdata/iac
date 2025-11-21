"""Tests for utility functions."""

from lib.utils import format_dict, render_template, safe_get


def test_render_template():
    """Test template rendering."""
    template_str = "Hello {{ name }}!"
    context = {"name": "World"}

    result = render_template(template_str, context)
    assert result == "Hello World!"


def test_render_template_with_logic():
    """Test template rendering with logic."""
    template_str = """
    {% if enabled %}
    Feature is enabled
    {% else %}
    Feature is disabled
    {% endif %}
    """
    context = {"enabled": True}

    result = render_template(template_str, context)
    assert "Feature is enabled" in result


def test_format_dict():
    """Test dictionary formatting."""
    data = {"key1": "value1", "key2": 123}

    result = format_dict(data)
    assert '"key1"' in result
    assert '"value1"' in result
    assert "123" in result


def test_safe_get_simple():
    """Test safe_get with simple key."""
    data = {"key1": "value1"}

    assert safe_get(data, "key1") == "value1"
    assert safe_get(data, "key2") is None
    assert safe_get(data, "key2", default="default") == "default"


def test_safe_get_nested():
    """Test safe_get with nested keys."""
    data = {"level1": {"level2": {"level3": "value"}}}

    assert safe_get(data, "level1", "level2", "level3") == "value"
    assert safe_get(data, "level1", "level2", "missing") is None
    assert safe_get(data, "level1", "missing", "level3") is None


def test_safe_get_non_dict():
    """Test safe_get with non-dict value."""
    data = {"key1": "value1"}

    assert safe_get(data, "key1", "nested") is None
