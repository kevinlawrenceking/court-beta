"""
Summarize Worker - FACT_GUARD AI Summarization Pipeline

Adapted from: python/summarize_upload_cli.py

SQS Message Format:
{
    "doc_id": 123,
    "s3_key": "uploads/uuid/document.pdf",
    "s3_bucket": "dw-uploads",
    "extra_instructions": "optional"
}

Pipeline:
1. Download PDF from S3
2. Extract OCR text (Tesseract + preprocessing)
3. Extract structured fields via Gemini (JSON schema)
4. Generate human-readable summary from extracted facts
5. FACT_GUARD verification
6. Write results to PostgreSQL
7. Log API usage
"""

import json
import logging
import os
import time

import google.generativeai as genai

from db import (
    get_gemini_api_key,
    log_gemini_api_call,
    update_document_summary,
    update_document_ocr,
)
from s3_utils import download_to_temp, UPLOADS_BUCKET
from ocr import extract_text_from_pdf

log = logging.getLogger(__name__)

EXTRACT_MODEL = os.environ.get('EXTRACT_MODEL', 'gemini-2.5-flash')
SUMMARY_MODEL = os.environ.get('SUMMARY_MODEL', 'gemini-2.5-flash')
VERIFY_MODEL = os.environ.get('VERIFY_MODEL', 'gemini-2.5-flash')

# Extraction JSON schema for structured field extraction
EXTRACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "document_type": {"type": "string"},
        "case_number": {"type": "string"},
        "case_name": {"type": "string"},
        "court": {"type": "string"},
        "judge": {"type": "string"},
        "filing_date": {"type": "string"},
        "parties": {
            "type": "object",
            "properties": {
                "plaintiffs": {"type": "array", "items": {"type": "string"}},
                "defendants": {"type": "array", "items": {"type": "string"}},
                "attorneys": {"type": "array", "items": {"type": "string"}},
            },
        },
        "charges": {"type": "array", "items": {"type": "string"}},
        "dispositions": {"type": "array", "items": {"type": "string"}},
        "key_dates": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "date": {"type": "string"},
                    "event": {"type": "string"},
                },
            },
        },
        "monetary_amounts": {"type": "array", "items": {"type": "string"}},
        "key_facts": {"type": "array", "items": {"type": "string"}},
        "orders": {"type": "array", "items": {"type": "string"}},
    },
}


def handle_summarize(message):
    """Process a summarize SQS message."""
    doc_id = message['doc_id']
    s3_key = message['s3_key']
    s3_bucket = message.get('s3_bucket', UPLOADS_BUCKET)
    extra = message.get('extra_instructions', '')

    start_time = time.time()

    # Configure Gemini
    api_key = get_gemini_api_key()
    genai.configure(api_key=api_key)

    # Step 1: Download PDF from S3
    log.info(f'Downloading PDF for doc {doc_id}: s3://{s3_bucket}/{s3_key}')
    local_path = download_to_temp(s3_bucket, s3_key)

    try:
        # Step 2: OCR extraction
        log.info(f'Extracting OCR text from {local_path}')
        ocr_text = extract_text_from_pdf(local_path)
        update_document_ocr(doc_id, ocr_text)

        if not ocr_text or len(ocr_text.strip()) < 50:
            log.warning(f'OCR text too short for doc {doc_id}: {len(ocr_text)} chars')
            update_document_summary(
                doc_id, 'Insufficient text extracted from document.',
                '<p>Insufficient text extracted from document.</p>',
                json.dumps({}), EXTRACT_MODEL, 0, 0, 0,
            )
            return

        # Step 3: Extract structured fields
        log.info(f'Extracting structured fields for doc {doc_id}')
        extraction, extract_tokens = _extract_facts(ocr_text, extra)

        # Step 4: Generate summary from facts
        log.info(f'Generating summary for doc {doc_id}')
        summary_text, summary_html, summary_tokens = _render_summary(extraction)

        # Step 5: FACT_GUARD verification
        log.info(f'Verifying summary for doc {doc_id}')
        verified, verify_tokens = _verify_summary(extraction, summary_text)

        if not verified:
            log.warning(f'FACT_GUARD verification failed for doc {doc_id}')
            summary_html = f'<div class="alert alert-warning">FACT_GUARD: Verification flagged potential issues.</div>{summary_html}'

        # Step 6: Write results
        total_tokens_in = extract_tokens[0] + summary_tokens[0] + verify_tokens[0]
        total_tokens_out = extract_tokens[1] + summary_tokens[1] + verify_tokens[1]
        processing_ms = int((time.time() - start_time) * 1000)

        update_document_summary(
            doc_id, summary_text, summary_html,
            json.dumps(extraction),
            SUMMARY_MODEL, processing_ms,
            total_tokens_in, total_tokens_out,
        )

        # Step 7: Log API usage
        cost = _estimate_cost(total_tokens_in, total_tokens_out)
        log_gemini_api_call(
            'summarize_worker', SUMMARY_MODEL,
            total_tokens_in, total_tokens_out,
            True, None, processing_ms, cost,
        )

        log.info(f'Summarization complete for doc {doc_id} in {processing_ms}ms')

    finally:
        # Clean up temp file
        os.unlink(local_path)


def _extract_facts(ocr_text, extra_instructions=''):
    """Step 1: Extract structured fields from OCR text using Gemini."""
    model = genai.GenerativeModel(EXTRACT_MODEL)

    prompt = f"""You are a legal document analyst. Extract all factual information
from the following court document text into the specified JSON schema.
Be thorough and precise. Only include information explicitly stated in the text.
{f'Additional instructions: {extra_instructions}' if extra_instructions else ''}

DOCUMENT TEXT:
{ocr_text[:30000]}"""  # Truncate to stay within context window

    response = model.generate_content(
        prompt,
        generation_config=genai.GenerationConfig(
            response_mime_type='application/json',
            response_schema=EXTRACTION_SCHEMA,
        ),
    )

    extraction = json.loads(response.text)
    tokens = (
        response.usage_metadata.prompt_token_count,
        response.usage_metadata.candidates_token_count,
    )
    return extraction, tokens


def _render_summary(extraction):
    """Step 2: Generate human-readable summary from extracted facts only."""
    model = genai.GenerativeModel(SUMMARY_MODEL)

    facts_json = json.dumps(extraction, indent=2)
    prompt = f"""You are a newsroom legal analyst writing for TMZ. Generate a concise,
accurate summary of this court document based ONLY on the extracted facts below.
Do NOT add any information not present in the facts.
Use clear, engaging language suitable for news reporting.
Format the output as HTML with <p> tags.

EXTRACTED FACTS:
{facts_json}"""

    response = model.generate_content(prompt)
    summary_text = response.text
    summary_html = summary_text

    # If response isn't already HTML, wrap it
    if not summary_html.strip().startswith('<'):
        paragraphs = summary_html.split('\n\n')
        summary_html = ''.join(f'<p>{p.strip()}</p>' for p in paragraphs if p.strip())

    tokens = (
        response.usage_metadata.prompt_token_count,
        response.usage_metadata.candidates_token_count,
    )
    return summary_text, summary_html, tokens


def _verify_summary(extraction, summary_text):
    """Step 3: FACT_GUARD - verify summary against extracted facts."""
    model = genai.GenerativeModel(VERIFY_MODEL)

    facts_json = json.dumps(extraction, indent=2)
    prompt = f"""You are a fact-checking editor. Compare the following summary against
the extracted facts. Identify any claims in the summary that are NOT supported
by the extracted facts.

Respond with a JSON object:
{{"verified": true/false, "issues": ["list of unsupported claims if any"]}}

EXTRACTED FACTS:
{facts_json}

SUMMARY TO VERIFY:
{summary_text}"""

    response = model.generate_content(
        prompt,
        generation_config=genai.GenerationConfig(
            response_mime_type='application/json',
        ),
    )

    result = json.loads(response.text)
    verified = result.get('verified', False)
    tokens = (
        response.usage_metadata.prompt_token_count,
        response.usage_metadata.candidates_token_count,
    )

    if not verified:
        issues = result.get('issues', [])
        log.warning(f'FACT_GUARD issues: {issues}')

    return verified, tokens


def _estimate_cost(tokens_in, tokens_out):
    """Estimate cost for Gemini Flash API calls."""
    # Gemini 2.5 Flash pricing (approximate)
    cost_per_1k_input = 0.000075
    cost_per_1k_output = 0.0003
    return (tokens_in / 1000 * cost_per_1k_input) + (tokens_out / 1000 * cost_per_1k_output)
