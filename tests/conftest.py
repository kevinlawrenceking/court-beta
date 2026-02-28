"""Shared fixtures for DocketWatch test suite."""

import pytest
import os
import sys

# Add project root and python directory to path for imports
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, os.path.join(PROJECT_ROOT, "python"))


@pytest.fixture
def tmp_pdf(tmp_path):
    """Create a minimal valid PDF file for testing."""
    pdf_path = tmp_path / "test.pdf"
    # Minimal PDF content (valid PDF magic bytes + minimal structure)
    pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF"
    pdf_path.write_bytes(pdf_content)
    return str(pdf_path)


@pytest.fixture
def sample_extraction():
    """Sample extraction JSON for testing citation extraction."""
    return {
        "document_type": "Criminal Complaint",
        "filing_date_iso": "2025-01-15",
        "case_number": "2025-CF-001234",
        "court_name": "Superior Court of Los Angeles County",
        "parties": {
            "plaintiff": "People of the State of California",
            "defendant": "John Michael Smith"
        },
        "charges": [
            {
                "count": 1,
                "description": "Battery (Penal Code 242)",
                "severity": "Misdemeanor"
            },
            {
                "count": 2,
                "description": "Vandalism (Penal Code 594)",
                "severity": "Misdemeanor"
            }
        ],
        "bail_amount": 50000,
        "next_hearing_date": "2025-02-20",
        "judge": "Hon. Maria Garcia",
        "settlement_amount": None,
        "key_facts": [
            "Defendant was arrested on January 14, 2025",
            "Incident occurred at 123 Main Street, Los Angeles"
        ]
    }
