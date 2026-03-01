"""Tests for summarize worker utility functions."""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from summarize_worker import _estimate_cost, EXTRACTION_SCHEMA


class TestEstimateCost:
    def test_zero_tokens(self):
        assert _estimate_cost(0, 0) == 0.0

    def test_known_values(self):
        # 1000 input tokens, 1000 output tokens
        cost = _estimate_cost(1000, 1000)
        expected = 0.000075 + 0.0003
        assert abs(cost - expected) < 1e-9

    def test_large_values(self):
        cost = _estimate_cost(100_000, 10_000)
        assert cost > 0
        assert isinstance(cost, float)

    def test_proportional(self):
        cost_1k = _estimate_cost(1000, 0)
        cost_2k = _estimate_cost(2000, 0)
        assert abs(cost_2k - 2 * cost_1k) < 1e-9


class TestExtractionSchema:
    def test_schema_is_valid_object(self):
        assert EXTRACTION_SCHEMA["type"] == "object"
        assert "properties" in EXTRACTION_SCHEMA

    def test_schema_has_required_fields(self):
        props = EXTRACTION_SCHEMA["properties"]
        expected_fields = [
            "document_type", "case_number", "case_name", "court",
            "judge", "filing_date", "parties", "charges",
            "dispositions", "key_dates", "monetary_amounts",
            "key_facts", "orders",
        ]
        for field in expected_fields:
            assert field in props, f"Missing field: {field}"

    def test_parties_structure(self):
        parties = EXTRACTION_SCHEMA["properties"]["parties"]
        assert parties["type"] == "object"
        party_props = parties["properties"]
        assert "plaintiffs" in party_props
        assert "defendants" in party_props
        assert "attorneys" in party_props
        assert party_props["plaintiffs"]["type"] == "array"

    def test_key_dates_structure(self):
        key_dates = EXTRACTION_SCHEMA["properties"]["key_dates"]
        assert key_dates["type"] == "array"
        item_props = key_dates["items"]["properties"]
        assert "date" in item_props
        assert "event" in item_props
