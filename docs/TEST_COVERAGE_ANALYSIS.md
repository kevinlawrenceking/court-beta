# Test Coverage Analysis Report

**Date:** 2026-02-28
**Project:** DocketWatch (court-beta)
**Analyzed by:** Claude Code

---

## Executive Summary

DocketWatch currently has **zero automated test coverage**. All testing is manual, documented in `/docs/QUICK_START_TESTING.md` and related guides. The project has **~1,041 lines of Python** across 4 scripts and **~22,883 lines of ColdFusion** across 139 files, none of which have automated tests.

This report identifies testable units, prioritizes them by risk, and provides a roadmap for introducing automated testing.

---

## Current State

| Metric | Value |
|--------|-------|
| Python files | 4 |
| Python LOC | 1,041 |
| ColdFusion files (.cfm/.cfc) | 139 |
| ColdFusion LOC | ~22,883 |
| Automated test files | 0 |
| Test frameworks configured | None |
| CI/CD pipeline | None |
| Code coverage tracking | None |
| Test coverage | **0%** |

### Existing Test Documentation (Manual Only)

| File | Purpose |
|------|---------|
| `docs/QUICK_START_TESTING.md` | Step-by-step manual testing guide (curl, browser console) |
| `docs/IMPLEMENTATION_CHECKLIST.md` | Phase-based implementation checklist with test subsections |
| `docs/PHASE2_COMPLETION_REPORT.md` | Phase 2 completion with recommended test procedures |
| `docs/SUMMARIZE_TOOL_ENHANCEMENT_PLAN.md` | Design doc with Section 10 testing strategy |

---

## Python Code Analysis

### 1. `python/combined_pacer_pdf_processor.py` (115 lines)

**Purpose:** Downloads PDFs from PACER URLs, returns JSON for ColdFusion integration.

| Function | Lines | Testability | Priority | Notes |
|----------|-------|-------------|----------|-------|
| `download_pdf(url, output_path)` | 15-74 | **High** (mock `requests.get`) | **P1** | Core I/O function; network + filesystem |
| `main()` | 76-115 | Medium (CLI entry) | P2 | Validates args, calls `download_pdf` |

**Key test scenarios:**
- Successful PDF download (mock HTTP 200 with PDF content-type)
- Non-PDF content-type rejection
- Network timeout / connection error
- Invalid URL validation
- Empty file / zero-byte response
- Directory creation for output path
- Missing CLI arguments

---

### 2. `python/summarize_upload_cli.py` (260 lines)

**Purpose:** CLI wrapper for FACT_GUARD document summarization pipeline.

| Function | Lines | Testability | Priority | Notes |
|----------|-------|-------------|----------|-------|
| `process_upload(file_path, extra)` | 49-204 | Medium (heavy external deps) | **P1** | Core business logic; imports from `summarize_document_event` |
| `main()` | 207-259 | Low (CLI + external deps) | P3 | Entry point |

**Key test scenarios:**
- Import failure graceful handling (IMPORTS_OK=False)
- File not found error
- OCR text too short for summarization
- FACT_GUARD pipeline: extraction → render → verify flow
- Extra instructions appended to context
- JSON output structure validation
- Fatal error produces valid JSON

**Dependencies requiring mocks:** `summarize_document_event` module (pdf_to_text, clean_ocr_text, extract_facts, render_summary, verify_summary, get_cursor, etc.)

---

### 3. `python/answer_from_json.py` (494 lines) — HIGHEST PRIORITY

**Purpose:** Q&A system using extracted JSON facts with FACT_GUARD principle.

| Function | Lines | Testability | Priority | Notes |
|----------|-------|-------------|----------|-------|
| `extract_citations(response, extraction)` | 307-375 | **Very High** (pure logic) | **P0** | No external deps; pure string/dict matching |
| `answer_from_facts(extraction, question, title)` | 180-304 | Medium (Gemini API) | P1 | Needs mock Gemini |
| `load_document_json(doc_uid)` | 83-145 | Medium (DB) | P2 | Needs mock pyodbc |
| `get_gemini_api_key()` | 148-177 | Medium (DB) | P2 | Needs mock pyodbc |
| `get_database_connection()` | 58-80 | Low (infra) | P3 | Connection string |
| `main()` | 378-493 | Low (CLI) | P3 | Entry point |

**Key test scenarios for `extract_citations` (pure function, no mocks needed):**
- Explicit field path mention in response text
- Value-based matching (string values appearing in response)
- Numeric value matching
- Nested dict field traversal
- List item matching
- Duplicate removal
- Recursion depth limit (deeply nested structures)
- Short string exclusion (< 4 chars)
- Empty extraction / empty response

**Key test scenarios for `answer_from_facts`:**
- Successful API call and response parsing
- Missing API key handling
- Token count extraction
- Error during Gemini call

---

### 4. `delete_unfiled_pdfs.py` (176 lines)

**Purpose:** Batch deletion of unfiled case documents from filesystem and database.

| Function | Lines | Testability | Priority | Notes |
|----------|-------|-------------|----------|-------|
| `delete_file_safely(file_path)` | 54-65 | **Very High** (pure logic) | **P0** | Simple file ops; easy to mock |
| `get_unfiled_documents(cursor, limit)` | 32-52 | High (mock cursor) | P1 | SQL query execution |
| `delete_database_record(cursor, doc_id)` | 67-74 | High (mock cursor) | P1 | SQL delete |
| `get_db_connection()` | 21-30 | Low (infra) | P3 | DSN connection |
| `main()` | 76-175 | Medium (integration) | P2 | Batch orchestration |

**Key test scenarios:**
- File exists → successful deletion
- File not found → returns False
- Permission denied → returns False
- Database record deletion success/failure
- Batch processing with mixed results
- Empty batch (no documents found)
- KeyboardInterrupt handling

---

## ColdFusion Code Analysis

### Testable Functions (in `includes/functions.cfm`)

| Function | Testability | Priority | Notes |
|----------|-------------|----------|-------|
| `fncNormalizeCaseName(caseName)` | **Very High** (pure string logic) | **P0** | Regex-based name normalization |
| `fncIsMatch(caseName, celebName)` | **Very High** (pure logic) | **P0** | Word-matching algorithm |

**Note:** ColdFusion testing requires TestBox or MXUnit framework. These are the only pure functions identified that could be unit-tested without database/session dependencies.

### AJAX Endpoints (Integration Test Candidates)

| Endpoint | Risk Level | Notes |
|----------|------------|-------|
| `ajax/upload_and_summarize.cfm` | **High** | File upload + Python execution |
| `ajax/ask_document_question.cfm` | **High** | Python execution + DB |
| `ajax/save_qc_feedback.cfm` | Medium | DB write |
| `ajax/save_prompt_feedback.cfm` | Medium | DB write |
| `ajax_acknowledgeEvent.cfm` | Medium | DB write |
| `ajax_generateSummary.cfm` | High | Python execution |
| `ajax_getPacerDoc.cfm` | High | External PACER call |

---

## Prioritized Test Implementation Roadmap

### Phase 1: Pure Functions (No External Dependencies)

**Effort:** Low | **Impact:** High | **Risk Reduction:** Medium

Target functions that are pure logic with no external dependencies:

1. `extract_citations()` in `answer_from_json.py` — Citation extraction from response text
2. `delete_file_safely()` in `delete_unfiled_pdfs.py` — File deletion with error handling

**Infrastructure needed:** pytest, basic project structure

---

### Phase 2: Mocked Unit Tests

**Effort:** Medium | **Impact:** High | **Risk Reduction:** High

Test core business logic with mocked external dependencies:

1. `download_pdf()` — Mock `requests.get`, validate content-type checking, file writing
2. `process_upload()` — Mock `summarize_document_event` imports, test FACT_GUARD flow
3. `answer_from_facts()` — Mock Gemini API, test prompt construction and response parsing
4. `load_document_json()` — Mock pyodbc, test SQL result handling
5. CLI `main()` functions — Test argument parsing and JSON output format

**Infrastructure needed:** pytest-mock, unittest.mock

---

### Phase 3: Integration Tests

**Effort:** High | **Impact:** Very High | **Risk Reduction:** Very High

End-to-end testing with test database and real (or mocked) services:

1. PDF download → OCR → summarization pipeline
2. Document Q&A flow (upload → question → answer)
3. Batch deletion with test data
4. AJAX endpoint response format validation

**Infrastructure needed:** Test database, fixture data, possibly Docker for SQL Server

---

### Phase 4: ColdFusion Testing

**Effort:** High | **Impact:** Medium | **Risk Reduction:** Medium

1. Install TestBox framework
2. Unit test `fncNormalizeCaseName` and `fncIsMatch`
3. Integration test AJAX endpoints
4. Test `Application.cfc` session/auth flow

**Infrastructure needed:** TestBox, ColdFusion test runner

---

## Recommended Test Infrastructure

### Python Test Setup

```
court-beta/
├── pytest.ini              # pytest configuration
├── tests/
│   ├── __init__.py
│   ├── conftest.py         # Shared fixtures
│   ├── test_pacer_pdf_processor.py
│   ├── test_summarize_upload_cli.py
│   ├── test_answer_from_json.py
│   └── test_delete_unfiled_pdfs.py
```

### Recommended Dependencies

```
pytest>=7.0
pytest-mock>=3.0
pytest-cov>=4.0
responses>=0.23       # HTTP mocking for requests library
```

### Coverage Target

| Phase | Target Coverage | Timeline |
|-------|----------------|----------|
| Phase 1 | 15-20% of Python code | Immediate |
| Phase 2 | 50-60% of Python code | Short-term |
| Phase 3 | 70-80% of Python code | Medium-term |
| Phase 4 | ColdFusion TBD | Long-term |

---

## Risk Assessment

### Highest Risk (Untested) Code Paths

1. **FACT_GUARD pipeline** (`summarize_upload_cli.py`) — AI summarization with verification; incorrect summaries could have legal/reputational consequences
2. **PDF download** (`combined_pacer_pdf_processor.py`) — Network failures, invalid files could break case processing
3. **Batch deletion** (`delete_unfiled_pdfs.py`) — Deletes files and DB records; bugs could cause data loss
4. **Citation extraction** (`answer_from_json.py`) — Heuristic matching; edge cases could miss or falsely cite fields

### Dependencies Without Version Pinning

No `requirements.txt` exists. Python dependencies are:
- `requests` — HTTP library
- `pyodbc` — SQL Server connectivity
- `google-generativeai` — Gemini API
- `beautifulsoup4` — HTML parsing
- `markdown2` — Markdown rendering
- Various OCR/PDF libraries (imported via `summarize_document_event`)

**Recommendation:** Create `requirements.txt` and `requirements-dev.txt` to pin versions.

---

## Conclusion

The DocketWatch project has well-documented manual testing procedures but zero automated coverage. The Python codebase is compact (1,041 lines) and highly testable — particularly `extract_citations()` and `delete_file_safely()` which are pure functions requiring no mocking.

The recommended approach is to start with Phase 1 (pure function tests) immediately, as this provides the highest return on investment with minimal setup. The initial test suite created alongside this analysis covers the most critical pure-logic functions and key mocked scenarios.
