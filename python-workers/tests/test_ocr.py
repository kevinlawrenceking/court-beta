"""Tests for OCR text cleaning and extraction logic."""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ocr import _clean_text


class TestCleanText:
    def test_removes_null_bytes(self):
        text = "Hello\x00World"
        assert _clean_text(text) == "Hello World" or "HelloWorld" in _clean_text(text).replace(" ", "")

    def test_collapses_excessive_whitespace(self):
        text = "Hello     World"
        result = _clean_text(text)
        assert "     " not in result
        assert "Hello" in result
        assert "World" in result

    def test_normalizes_newlines(self):
        text = "Line1\n\n\n\n\n\nLine2"
        result = _clean_text(text)
        assert "\n\n\n\n" not in result

    def test_replaces_form_feed(self):
        text = "Page1\fPage2"
        result = _clean_text(text)
        assert "\f" not in result

    def test_strips_leading_trailing_whitespace(self):
        text = "  Hello World  "
        result = _clean_text(text)
        assert result == "Hello World"

    def test_empty_string(self):
        assert _clean_text("") == ""

    def test_preserves_normal_text(self):
        text = "This is a normal court document filing."
        assert _clean_text(text) == text

    def test_complex_ocr_artifacts(self):
        text = "\x00  COURT   DOCUMENT  \n\n\n\n\n\n  Filed on 2025-01-15  \x00"
        result = _clean_text(text)
        assert "\x00" not in result
        assert "COURT" in result
        assert "Filed on 2025-01-15" in result
