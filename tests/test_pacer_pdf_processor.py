"""Tests for python/combined_pacer_pdf_processor.py"""

import json
import os
import sys
from unittest.mock import patch, MagicMock, mock_open

import pytest

# Import the module under test
from combined_pacer_pdf_processor import download_pdf, main


class TestDownloadPdf:
    """Tests for the download_pdf function."""

    def test_successful_pdf_download(self, tmp_path):
        """Successful download with valid PDF content-type creates file."""
        output_path = str(tmp_path / "output" / "test.pdf")
        pdf_content = b"%PDF-1.4 fake pdf content"

        mock_response = MagicMock()
        mock_response.headers = {"content-type": "application/pdf"}
        mock_response.iter_content.return_value = [pdf_content]
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "success"
        assert os.path.exists(output_path)
        assert result["file_size"] == len(pdf_content)

    def test_octet_stream_content_type_accepted(self, tmp_path):
        """Download succeeds with application/octet-stream content-type."""
        output_path = str(tmp_path / "test.pdf")
        pdf_content = b"%PDF-1.4 content"

        mock_response = MagicMock()
        mock_response.headers = {"content-type": "application/octet-stream"}
        mock_response.iter_content.return_value = [pdf_content]
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "success"

    def test_non_pdf_content_type_rejected(self, tmp_path):
        """Non-PDF content-type returns error."""
        output_path = str(tmp_path / "test.pdf")

        mock_response = MagicMock()
        mock_response.headers = {"content-type": "text/html; charset=utf-8"}
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "Content-Type" in result["message"]
        assert not os.path.exists(output_path)

    def test_network_error_returns_error(self, tmp_path):
        """Network errors are caught and returned as error status."""
        import requests

        output_path = str(tmp_path / "test.pdf")

        with patch(
            "combined_pacer_pdf_processor.requests.get",
            side_effect=requests.exceptions.ConnectionError("Connection refused"),
        ):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "Network error" in result["message"]

    def test_timeout_error_returns_error(self, tmp_path):
        """Timeout errors are caught and returned as error status."""
        import requests

        output_path = str(tmp_path / "test.pdf")

        with patch(
            "combined_pacer_pdf_processor.requests.get",
            side_effect=requests.exceptions.Timeout("Request timed out"),
        ):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "Network error" in result["message"]

    def test_http_error_returns_error(self, tmp_path):
        """HTTP errors (404, 500, etc.) are caught and returned."""
        import requests

        output_path = str(tmp_path / "test.pdf")

        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = requests.exceptions.HTTPError(
            "404 Not Found"
        )

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "Network error" in result["message"]

    def test_creates_output_directory(self, tmp_path):
        """Output directory is created if it doesn't exist."""
        output_path = str(tmp_path / "deep" / "nested" / "dir" / "test.pdf")
        pdf_content = b"%PDF-1.4 content"

        mock_response = MagicMock()
        mock_response.headers = {"content-type": "application/pdf"}
        mock_response.iter_content.return_value = [pdf_content]
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "success"
        assert os.path.exists(os.path.dirname(output_path))

    def test_empty_response_returns_error(self, tmp_path):
        """Empty response (zero-byte file) returns error."""
        output_path = str(tmp_path / "test.pdf")

        mock_response = MagicMock()
        mock_response.headers = {"content-type": "application/pdf"}
        mock_response.iter_content.return_value = []  # No content chunks
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "empty" in result["message"].lower() or "not created" in result["message"].lower()

    def test_missing_content_type_header(self, tmp_path):
        """Missing content-type header is handled (defaults to empty string)."""
        output_path = str(tmp_path / "test.pdf")

        mock_response = MagicMock()
        mock_response.headers = {}  # No content-type
        mock_response.raise_for_status.return_value = None

        with patch("combined_pacer_pdf_processor.requests.get", return_value=mock_response):
            result = download_pdf("https://example.com/doc.pdf", output_path)

        assert result["status"] == "error"
        assert "Content-Type" in result["message"]


class TestMain:
    """Tests for the main CLI entry point."""

    def test_missing_arguments_exits_with_error(self):
        """Missing CLI arguments cause sys.exit(1) with error JSON."""
        with patch("sys.argv", ["script"]):
            with pytest.raises(SystemExit) as exc_info:
                main()
            assert exc_info.value.code == 1

    def test_invalid_url_exits_with_error(self, capsys):
        """Invalid URL format causes sys.exit(1)."""
        with patch("sys.argv", ["script", "not-a-url", "/tmp/out.pdf"]):
            with pytest.raises(SystemExit) as exc_info:
                main()
            assert exc_info.value.code == 1

    def test_valid_arguments_calls_download(self, tmp_path):
        """Valid arguments trigger download_pdf call."""
        output_path = str(tmp_path / "test.pdf")

        mock_result = {"status": "success", "message": "OK", "file_size": 100}

        with patch("sys.argv", ["script", "https://example.com/doc.pdf", output_path]):
            with patch(
                "combined_pacer_pdf_processor.download_pdf", return_value=mock_result
            ) as mock_dl:
                with pytest.raises(SystemExit) as exc_info:
                    main()
                assert exc_info.value.code == 0
                mock_dl.assert_called_once_with("https://example.com/doc.pdf", output_path)
