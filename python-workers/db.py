"""
Database utilities for PostgreSQL.

Replaces pyodbc/SQL Server connections from the original scripts
with psycopg2 for PostgreSQL on RDS.
"""

import os
import logging

import psycopg2
import psycopg2.extras

log = logging.getLogger(__name__)

DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://docketwatch:docketwatch@localhost:5432/docketwatch')


def get_connection():
    """Create a new database connection."""
    return psycopg2.connect(DATABASE_URL)


def get_gemini_api_key():
    """Retrieve the Gemini API key from AWS Secrets Manager or database."""
    # Prefer Secrets Manager in production
    api_key = os.environ.get('GEMINI_API_KEY')
    if api_key:
        return api_key

    # Fallback: read from database (mirrors original utilities table lookup)
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT preference_value->>'value' FROM user_preferences WHERE preference_key = 'gemini_api_key' LIMIT 1")
            row = cur.fetchone()
            if row:
                return row[0]
    finally:
        conn.close()

    raise RuntimeError('GEMINI_API_KEY not found in env or database')


def log_gemini_api_call(script_name, model_name, input_tokens, output_tokens,
                        success, error_message, processing_ms, cost_estimate):
    """Log an API call to the gemini_api_log table."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO gemini_api_log
                   (script_name, model_name, input_tokens, output_tokens,
                    success, error_message, processing_time_ms, cost_estimate)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                (script_name, model_name, input_tokens, output_tokens,
                 success, error_message, processing_ms, cost_estimate),
            )
        conn.commit()
    except Exception as e:
        log.error(f'Failed to log API call: {e}')
    finally:
        conn.close()


def update_document_summary(doc_id, summary_text, summary_html, extraction_json,
                            model_name, processing_ms, tokens_in, tokens_out):
    """Update the AI summary fields for a document."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE documents
                   SET summary_ai = %s, summary_ai_html = %s,
                       summary_ai_extraction_json = %s,
                       model_name = %s, processing_ms = %s,
                       tokens_input = %s, tokens_output = %s
                   WHERE id = %s""",
                (summary_text, summary_html, extraction_json,
                 model_name, processing_ms, tokens_in, tokens_out, doc_id),
            )
        conn.commit()
        log.info(f'Updated summary for document {doc_id}')
    finally:
        conn.close()


def update_document_ocr(doc_id, ocr_text):
    """Update the OCR text for a document."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE documents SET ocr_text = %s WHERE id = %s",
                (ocr_text, doc_id),
            )
        conn.commit()
    finally:
        conn.close()


def get_document_extraction(doc_id):
    """Retrieve the extraction JSON for a document."""
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                """SELECT id, doc_uid, pdf_title, summary_ai_extraction_json, s3_key
                   FROM documents WHERE id = %s""",
                (doc_id,),
            )
            return cur.fetchone()
    finally:
        conn.close()


def save_document_prompt(doc_id, session_id, prompt_text, response_text,
                         cited_fields, model_name, tokens_in, tokens_out):
    """Save a Q&A exchange for a document."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO document_prompts
                   (fk_document, session_id, prompt_text, response_text,
                    cited_fields, model_name, tokens_input, tokens_output)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                   RETURNING id""",
                (doc_id, session_id, prompt_text, response_text,
                 cited_fields, model_name, tokens_in, tokens_out),
            )
            prompt_id = cur.fetchone()[0]
        conn.commit()
        return prompt_id
    finally:
        conn.close()
