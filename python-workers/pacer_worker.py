"""
PACER Worker - Download PDFs from PACER and store in S3.

Adapted from: python/combined_pacer_pdf_processor.py

SQS Message Format:
{
    "doc_id": 123,
    "event_url": "https://ecf.court.gov/doc/...",
    "case_id": 456,
    "s3_destination_key": "cases/456/E123.pdf"
}

Downloads the PDF from PACER, validates it, uploads to S3,
and updates the document record in PostgreSQL.
"""

import hashlib
import logging
import os
import tempfile
import time

import requests

from db import get_connection
from s3_utils import upload_file, DOCS_BUCKET

log = logging.getLogger(__name__)

PACER_TIMEOUT = int(os.environ.get('PACER_TIMEOUT', '60'))


def handle_pacer(message):
    """Process a PACER download SQS message."""
    doc_id = message['doc_id']
    event_url = message['event_url']
    case_id = message.get('case_id')
    s3_key = message.get('s3_destination_key', f'cases/{case_id}/E{doc_id}.pdf')

    start_time = time.time()

    log.info(f'Downloading PACER document {doc_id} from {event_url}')

    # Download PDF
    local_path = _download_pdf(event_url)
    if not local_path:
        _mark_error(doc_id, 'Failed to download PDF from PACER')
        return

    try:
        # Validate PDF
        with open(local_path, 'rb') as f:
            magic = f.read(5)
            if magic != b'%PDF-':
                log.error(f'Downloaded file is not a PDF for doc {doc_id}')
                _mark_error(doc_id, 'Downloaded file is not a valid PDF')
                return

            # Read full file for hash
            f.seek(0)
            data = f.read()

        file_size = len(data)
        sha256 = hashlib.sha256(data).hexdigest()

        # Upload to S3
        upload_file(local_path, DOCS_BUCKET, s3_key)

        # Update document record
        processing_ms = int((time.time() - start_time) * 1000)
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE documents
                       SET s3_key = %s, file_size = %s, sha256_hash = %s
                       WHERE id = %s""",
                    (s3_key, file_size, sha256, doc_id),
                )
            conn.commit()
        finally:
            conn.close()

        log.info(f'PACER download complete for doc {doc_id}: {file_size} bytes, {processing_ms}ms')

    finally:
        os.unlink(local_path)


def _download_pdf(url):
    """Download a PDF from a URL to a temporary file."""
    try:
        response = requests.get(
            url,
            timeout=PACER_TIMEOUT,
            stream=True,
            headers={
                'User-Agent': 'DocketWatch/1.0',
                'Accept': 'application/pdf',
            },
        )
        response.raise_for_status()

        # Validate content type
        content_type = response.headers.get('Content-Type', '')
        if 'pdf' not in content_type.lower() and 'octet-stream' not in content_type.lower():
            log.warning(f'Unexpected content type: {content_type}')

        # Write to temp file
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.pdf')
        for chunk in response.iter_content(chunk_size=8192):
            tmp.write(chunk)
        tmp.close()

        log.info(f'Downloaded {os.path.getsize(tmp.name)} bytes from {url}')
        return tmp.name

    except requests.RequestException as e:
        log.error(f'PACER download failed: {e}')
        return None


def _mark_error(doc_id, error_message):
    """Record a processing error for a document."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO error_logs (script_name, error_type, message, severity) VALUES (%s, %s, %s, %s)",
                ('pacer_worker', 'DOWNLOAD_FAILED', f'Doc {doc_id}: {error_message}', 'error'),
            )
        conn.commit()
    except Exception as e:
        log.error(f'Failed to log error: {e}')
    finally:
        conn.close()
