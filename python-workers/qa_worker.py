"""
Q&A Worker - Answer questions about documents using extracted facts.

Adapted from: python/answer_from_json.py

SQS Message Format:
{
    "doc_id": 123,
    "question": "What are the charges?",
    "session_id": "uuid-string"
}

Uses FACT_GUARD principle: answers are generated ONLY from the
extracted JSON facts, never from raw OCR text directly.
"""

import json
import logging
import os
import time

import google.generativeai as genai

from db import (
    get_gemini_api_key,
    get_document_extraction,
    save_document_prompt,
    log_gemini_api_call,
)

log = logging.getLogger(__name__)

QA_MODEL = os.environ.get('QA_MODEL', 'gemini-2.5-flash')


def handle_qa(message):
    """Process a Q&A SQS message."""
    doc_id = message['doc_id']
    question = message['question']
    session_id = message.get('session_id')

    start_time = time.time()

    # Configure Gemini
    api_key = get_gemini_api_key()
    genai.configure(api_key=api_key)

    # Load document extraction
    doc = get_document_extraction(doc_id)
    if not doc:
        log.error(f'Document {doc_id} not found')
        return

    extraction = doc.get('summary_ai_extraction_json')
    if not extraction:
        log.error(f'No extraction JSON for document {doc_id}')
        save_document_prompt(
            doc_id, session_id, question,
            'This document has not been processed for AI analysis yet.',
            json.dumps([]), QA_MODEL, 0, 0,
        )
        return

    # If extraction is a string, parse it
    if isinstance(extraction, str):
        extraction = json.loads(extraction)

    doc_title = doc.get('pdf_title', f'Document {doc_id}')

    # Generate answer
    response_text, cited_fields, tokens_in, tokens_out = _answer_from_facts(
        extraction, question, doc_title,
    )

    processing_ms = int((time.time() - start_time) * 1000)

    # Save to database
    save_document_prompt(
        doc_id, session_id, question, response_text,
        json.dumps(cited_fields), QA_MODEL, tokens_in, tokens_out,
    )

    # Log API call
    cost = (tokens_in / 1000 * 0.000075) + (tokens_out / 1000 * 0.0003)
    log_gemini_api_call(
        'qa_worker', QA_MODEL, tokens_in, tokens_out,
        True, None, processing_ms, cost,
    )

    log.info(f'Q&A complete for doc {doc_id} in {processing_ms}ms')


def _answer_from_facts(extraction, question, doc_title):
    """Answer a question using only the extracted facts (FACT_GUARD)."""
    model = genai.GenerativeModel(QA_MODEL)

    facts_json = json.dumps(extraction, indent=2)
    prompt = f"""You are a legal document analyst. Answer the user's question about
"{doc_title}" using ONLY the extracted facts below.

CRITICAL RULES:
- ONLY use information from the EXTRACTED FACTS section
- If the answer is not in the facts, say "This information is not available in the extracted data."
- Cite which fields your answer comes from
- Be precise and factual

EXTRACTED FACTS:
{facts_json}

USER QUESTION:
{question}

Respond in this JSON format:
{{"answer": "your answer text", "cited_fields": ["field1", "field2"]}}"""

    response = model.generate_content(
        prompt,
        generation_config=genai.GenerationConfig(
            response_mime_type='application/json',
        ),
    )

    result = json.loads(response.text)
    answer = result.get('answer', 'Unable to generate answer.')
    cited = result.get('cited_fields', [])

    tokens_in = response.usage_metadata.prompt_token_count
    tokens_out = response.usage_metadata.candidates_token_count

    return answer, cited, tokens_in, tokens_out
