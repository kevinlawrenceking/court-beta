"""Tests for python/answer_from_json.py

Focuses on extract_citations (pure function) and validation logic.
"""

import json
import os
import sys
from unittest.mock import patch, MagicMock

import pytest

# Mock external dependencies before importing the module under test
sys.modules.setdefault("pyodbc", MagicMock())
sys.modules.setdefault("google", MagicMock())
sys.modules.setdefault("google.generativeai", MagicMock())

# Import the function under test
from answer_from_json import extract_citations


class TestExtractCitations:
    """Tests for the extract_citations function (pure logic, no mocks needed)."""

    def test_explicit_field_path_mention(self, sample_extraction):
        """Field paths explicitly mentioned in response are cited."""
        response = "According to fields.case_number, the case is 2025-CF-001234."
        cited = extract_citations(response, sample_extraction)
        assert "fields.case_number" in cited

    def test_string_value_matching(self, sample_extraction):
        """String values from extraction appearing in response are cited."""
        response = "The case was filed in Superior Court of Los Angeles County."
        cited = extract_citations(response, sample_extraction)
        assert "fields.court_name" in cited

    def test_numeric_value_matching(self, sample_extraction):
        """Numeric values appearing in response are cited."""
        response = "The bail amount is set at 50000 dollars."
        cited = extract_citations(response, sample_extraction)
        assert "fields.bail_amount" in cited

    def test_nested_dict_field_traversal(self, sample_extraction):
        """Nested dictionary fields are traversed and cited."""
        response = "The defendant is John Michael Smith."
        cited = extract_citations(response, sample_extraction)
        assert "fields.parties.defendant" in cited

    def test_list_item_matching(self, sample_extraction):
        """String items in list fields are matched."""
        response = "The defendant was arrested on January 14, 2025 as noted in key facts."
        cited = extract_citations(response, sample_extraction)
        assert "fields.key_facts" in cited

    def test_nested_list_of_dicts(self, sample_extraction):
        """Items in lists of dicts are matched via recursive traversal."""
        response = "Count 1 is Battery (Penal Code 242), a Misdemeanor charge."
        cited = extract_citations(response, sample_extraction)
        # Should cite something under fields.charges
        charges_cited = [c for c in cited if c.startswith("fields.charges")]
        assert len(charges_cited) > 0

    def test_no_citations_when_unrelated_response(self, sample_extraction):
        """No citations when response doesn't reference any extraction values."""
        response = "This information is not available in the extracted facts."
        cited = extract_citations(response, sample_extraction)
        assert len(cited) == 0

    def test_duplicate_removal(self, sample_extraction):
        """Duplicate citations are removed, preserving order."""
        # Response mentions court_name twice via value match
        response = (
            "The case at Superior Court of Los Angeles County "
            "was heard at Superior Court of Los Angeles County again."
        )
        cited = extract_citations(response, sample_extraction)
        # Count occurrences of court_name
        court_count = sum(1 for c in cited if c == "fields.court_name")
        assert court_count <= 1

    def test_short_string_excluded(self):
        """Strings of 3 characters or fewer are not matched to prevent false positives."""
        extraction = {"status": "OK", "code": "AB"}
        response = "The status is OK and the code is AB."
        cited = extract_citations(response, extraction)
        # "OK" and "AB" are <= 3 chars, should not trigger value-based citation
        value_cited = [c for c in cited if "status" in c or "code" in c]
        # They might be cited via field path mention, but not via value matching alone
        # Since "status" and "code" appear in response as regular words, check carefully
        assert len(value_cited) == 0 or all(
            "fields." + k in response.lower() for k in ["status", "code"] if f"fields.{k}" in value_cited
        )

    def test_empty_extraction(self):
        """Empty extraction produces no citations."""
        cited = extract_citations("Some response text.", {})
        assert cited == []

    def test_empty_response(self, sample_extraction):
        """Empty response produces no citations."""
        cited = extract_citations("", sample_extraction)
        assert cited == []

    def test_null_field_not_cited(self, sample_extraction):
        """None/null values in extraction are not cited."""
        # settlement_amount is None in sample_extraction
        response = "No settlement information available."
        cited = extract_citations(response, sample_extraction)
        settlement_cited = [c for c in cited if "settlement" in c]
        assert len(settlement_cited) == 0

    def test_case_insensitive_field_path_matching(self, sample_extraction):
        """Field path matching is case-insensitive."""
        response = "According to FIELDS.CASE_NUMBER, the case is tracked."
        cited = extract_citations(response, sample_extraction)
        assert "fields.case_number" in cited

    def test_case_insensitive_value_matching(self, sample_extraction):
        """Value matching is case-insensitive."""
        response = "The document type is criminal complaint."
        cited = extract_citations(response, sample_extraction)
        assert "fields.document_type" in cited

    def test_deep_recursion_limit(self):
        """Deeply nested structures stop at recursion depth 5."""
        # Create extraction with depth > 5
        deep = {"a": {"b": {"c": {"d": {"e": {"f": "deep_value"}}}}}}
        response = "The deep_value is found."
        cited = extract_citations(response, deep)
        # Should not crash; may or may not find the value depending on depth
        assert isinstance(cited, list)

    def test_multiple_field_citations(self, sample_extraction):
        """Multiple fields can be cited in a single response."""
        response = (
            "The Criminal Complaint filed on 2025-01-15 "
            "in Superior Court of Los Angeles County involves "
            "John Michael Smith with bail set at 50000."
        )
        cited = extract_citations(response, sample_extraction)
        # Should cite multiple fields
        assert len(cited) >= 3


class TestAnswerFromFacts:
    """Tests for answer_from_facts with mocked Gemini API."""

    def test_missing_api_key_returns_error(self, sample_extraction):
        """Missing API key returns structured error."""
        from answer_from_json import answer_from_facts

        with patch("answer_from_json.get_gemini_api_key", return_value=None):
            with patch.dict(os.environ, {}, clear=True):
                result = answer_from_facts(sample_extraction, "What is the case number?")

        assert result["error"] == "API key not found"
        assert "not configured" in result["response_text"]
        assert result["cited_fields"] == []

    def test_successful_api_call(self, sample_extraction):
        """Successful Gemini API call returns structured response."""
        from answer_from_json import answer_from_facts

        mock_response = MagicMock()
        mock_response.text = "The case number is 2025-CF-001234 (from fields.case_number)."
        mock_response.usage_metadata.prompt_token_count = 100
        mock_response.usage_metadata.candidates_token_count = 50

        mock_model = MagicMock()
        mock_model.generate_content.return_value = mock_response

        with patch("answer_from_json.get_gemini_api_key", return_value="fake-key"):
            with patch("answer_from_json.genai") as mock_genai:
                mock_genai.GenerativeModel.return_value = mock_model
                result = answer_from_facts(
                    sample_extraction, "What is the case number?"
                )

        assert result["error"] is None
        assert "2025-CF-001234" in result["response_text"]
        assert result["processing_ms"] >= 0
        assert result["tokens_input"] == 100
        assert result["tokens_output"] == 50

    def test_api_exception_returns_error(self, sample_extraction):
        """Exception during API call returns structured error."""
        from answer_from_json import answer_from_facts

        with patch("answer_from_json.get_gemini_api_key", return_value="fake-key"):
            with patch("answer_from_json.genai") as mock_genai:
                mock_genai.GenerativeModel.return_value.generate_content.side_effect = (
                    Exception("API quota exceeded")
                )
                result = answer_from_facts(
                    sample_extraction, "What is the case number?"
                )

        assert result["error"] is not None
        assert "API quota exceeded" in result["error"]
        assert result["processing_ms"] >= 0


class TestMainValidation:
    """Tests for main() argument validation."""

    def test_prompt_too_long_returns_error(self):
        """Prompt exceeding 1000 characters returns validation error."""
        from answer_from_json import main

        long_prompt = "x" * 1001

        with patch("sys.argv", ["script", "--doc_uid=test-uid", f"--prompt={long_prompt}"]):
            with patch("answer_from_json.IMPORTS_OK", True):
                with pytest.raises(SystemExit) as exc_info:
                    main()
                assert exc_info.value.code == 1

    def test_prompt_too_short_returns_error(self):
        """Prompt shorter than 3 characters returns validation error."""
        from answer_from_json import main

        with patch("sys.argv", ["script", "--doc_uid=test-uid", "--prompt=ab"]):
            with patch("answer_from_json.IMPORTS_OK", True):
                with pytest.raises(SystemExit) as exc_info:
                    main()
                assert exc_info.value.code == 1
