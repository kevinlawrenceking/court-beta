"""Tests for delete_unfiled_pdfs.py"""

import os
import sys
from unittest.mock import patch, MagicMock, call

import pytest

# Mock pyodbc before importing the module under test (not available in CI)
sys.modules.setdefault("pyodbc", MagicMock())

from delete_unfiled_pdfs import delete_file_safely, get_unfiled_documents, delete_database_record


class TestDeleteFileSafely:
    """Tests for delete_file_safely (pure function with filesystem ops)."""

    def test_existing_file_deleted_successfully(self, tmp_path):
        """Existing file is deleted and returns True."""
        file_path = tmp_path / "test.pdf"
        file_path.write_text("content")

        success, msg = delete_file_safely(str(file_path))

        assert success is True
        assert "deleted successfully" in msg
        assert not file_path.exists()

    def test_nonexistent_file_returns_false(self, tmp_path):
        """Non-existent file returns False with 'not found' message."""
        file_path = str(tmp_path / "nonexistent.pdf")

        success, msg = delete_file_safely(file_path)

        assert success is False
        assert "not found" in msg.lower()

    def test_permission_denied_returns_false(self, tmp_path):
        """Permission error returns False with appropriate message."""
        file_path = str(tmp_path / "test.pdf")

        with patch("os.path.exists", return_value=True):
            with patch("os.remove", side_effect=PermissionError("Permission denied")):
                success, msg = delete_file_safely(file_path)

        assert success is False
        assert "Permission denied" in msg

    def test_unexpected_error_returns_false(self, tmp_path):
        """Unexpected exceptions return False with error description."""
        file_path = str(tmp_path / "test.pdf")

        with patch("os.path.exists", return_value=True):
            with patch("os.remove", side_effect=OSError("Disk error")):
                success, msg = delete_file_safely(file_path)

        assert success is False
        assert "Error" in msg


class TestGetUnfiledDocuments:
    """Tests for get_unfiled_documents with mocked cursor."""

    def test_returns_documents_with_limit(self):
        """Query executes with limit parameter and returns results."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            (1, "uid-1", 10, "cases/10/E1.pdf", "Doc 1", 5000, "Case 1", "Unfiled", "Removed"),
            (2, "uid-2", 11, "cases/11/E2.pdf", "Doc 2", 3000, "Case 2", "Unfiled", "Removed"),
        ]

        results = get_unfiled_documents(mock_cursor, limit=10)

        mock_cursor.execute.assert_called_once()
        assert len(results) == 2
        # Verify limit parameter was passed
        call_args = mock_cursor.execute.call_args
        assert call_args[0][1] == 10  # limit parameter

    def test_returns_empty_when_no_documents(self):
        """Returns empty list when no matching documents exist."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []

        results = get_unfiled_documents(mock_cursor, limit=10)

        assert results == []

    def test_default_limit_is_10(self):
        """Default limit parameter is 10."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []

        get_unfiled_documents(mock_cursor)

        call_args = mock_cursor.execute.call_args
        assert call_args[0][1] == 10


class TestDeleteDatabaseRecord:
    """Tests for delete_database_record with mocked cursor."""

    def test_successful_deletion(self):
        """Successful database deletion returns True."""
        mock_cursor = MagicMock()

        success, msg = delete_database_record(mock_cursor, doc_id=42)

        assert success is True
        assert "deleted" in msg.lower()
        mock_cursor.execute.assert_called_once()

    def test_database_error_returns_false(self):
        """Database error returns False with error message."""
        mock_cursor = MagicMock()
        mock_cursor.execute.side_effect = Exception("Foreign key constraint violation")

        success, msg = delete_database_record(mock_cursor, doc_id=42)

        assert success is False
        assert "Database error" in msg
        assert "Foreign key" in msg
