"""Tests for python/summarize_upload_cli.py

Tests focus on process_upload behavior with mocked external dependencies.
"""

import json
import os
import sys
import time
from unittest.mock import patch, MagicMock

import pytest

# Mock external dependencies before any imports that might need them
sys.modules.setdefault("pyodbc", MagicMock())
sys.modules.setdefault("google", MagicMock())
sys.modules.setdefault("google.generativeai", MagicMock())
sys.modules.setdefault("summarize_document_event", MagicMock())

import summarize_upload_cli


class TestProcessUpload:
    """Tests for the process_upload function."""

    def test_import_failure_returns_error(self):
        """When imports fail, returns structured error with import message."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = False
            summarize_upload_cli.IMPORT_ERROR = "No module named 'summarize_document_event'"

            result = summarize_upload_cli.process_upload("/fake/path.pdf")

            assert "Import error" in result["summary_text"]
            assert result["doc_uid"] is None
            assert len(result["errors"]) > 0
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_file_not_found_returns_error(self):
        """Non-existent file path returns error."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = True

            with patch.object(summarize_upload_cli, "get_cursor", return_value=(MagicMock(), MagicMock())):
                result = summarize_upload_cli.process_upload("/nonexistent/file.pdf")

            assert len(result["errors"]) > 0
            error_text = " ".join(result["errors"]).lower()
            assert "not found" in error_text or "error" in result["summary_text"].lower()
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_short_ocr_text_returns_early(self, tmp_pdf):
        """OCR text shorter than 100 chars returns insufficient text message."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = True
            mock_conn = MagicMock()

            with patch.object(summarize_upload_cli, "get_cursor", return_value=(mock_conn, MagicMock())):
                with patch.object(summarize_upload_cli, "pdf_to_text", return_value="Short text."):
                    with patch.object(summarize_upload_cli, "clean_ocr_text", return_value="Short text."):
                        result = summarize_upload_cli.process_upload(tmp_pdf)

            assert "insufficient text" in result["summary_text"].lower() or "unreadable" in result["summary_text"].lower()
            assert result["processing_ms"] >= 0
            mock_conn.close.assert_called_once()
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_result_structure_on_error(self):
        """process_upload always returns required keys even on error."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = True

            with patch.object(summarize_upload_cli, "get_cursor", side_effect=Exception("DB fail")):
                result = summarize_upload_cli.process_upload("/fake/file.pdf")

            required_keys = [
                "doc_uid", "model_name", "summary_text", "summary_html",
                "ocr_text", "fields", "errors", "processing_ms"
            ]
            for key in required_keys:
                assert key in result, f"Missing required key: {key}"
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_extra_instructions_appended(self, tmp_pdf):
        """Extra instructions are appended to case overview."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = True
            mock_conn = MagicMock()
            ocr_text = "A" * 200  # Long enough to pass the 100-char threshold

            mock_extraction = {"document_type": "Test", "filing_date": "2025-01-01"}

            with patch.object(summarize_upload_cli, "get_cursor", return_value=(mock_conn, MagicMock())):
                with patch.object(summarize_upload_cli, "pdf_to_text", return_value=ocr_text):
                    with patch.object(summarize_upload_cli, "clean_ocr_text", return_value=ocr_text):
                        with patch.object(summarize_upload_cli, "FACT_GUARD", True):
                            with patch.object(summarize_upload_cli, "extract_facts", return_value=("raw", mock_extraction)) as mock_extract:
                                with patch.object(summarize_upload_cli, "extraction_has_substance", return_value=True):
                                    with patch.object(summarize_upload_cli, "render_summary", return_value="<p>Summary</p>"):
                                        with patch.object(summarize_upload_cli, "fix_encoding_garbage", side_effect=lambda x: x):
                                            with patch.object(summarize_upload_cli, "normalize_quotes", side_effect=lambda x: x):
                                                with patch.object(summarize_upload_cli, "verify_summary", return_value=(True, "OK")):
                                                    with patch.object(summarize_upload_cli, "BeautifulSoup") as mock_bs:
                                                        mock_bs.return_value.prettify.return_value = "<p>Summary</p>"
                                                        result = summarize_upload_cli.process_upload(tmp_pdf, "Focus on settlement details")

            # Verify extract_facts was called with case_overview containing extra instructions
            call_args = mock_extract.call_args[0]
            assert "Focus on settlement details" in call_args[1]
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_exception_produces_valid_result(self, tmp_pdf):
        """Unexpected exceptions still produce valid result structure with error details."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = True

            with patch.object(summarize_upload_cli, "get_cursor", side_effect=Exception("DB connection failed")):
                result = summarize_upload_cli.process_upload(tmp_pdf)

            assert len(result["errors"]) > 0
            assert "DB connection failed" in result["errors"][0]
            assert result["processing_ms"] >= 0
            assert "Error" in result["summary_text"]
        finally:
            summarize_upload_cli.IMPORTS_OK = orig

    def test_import_failure_result_has_zero_processing_time(self):
        """Import failure returns 0 processing_ms."""
        orig = summarize_upload_cli.IMPORTS_OK
        try:
            summarize_upload_cli.IMPORTS_OK = False
            summarize_upload_cli.IMPORT_ERROR = "test error"

            result = summarize_upload_cli.process_upload("/any/path.pdf")

            assert result["processing_ms"] == 0
        finally:
            summarize_upload_cli.IMPORTS_OK = orig
