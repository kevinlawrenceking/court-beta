"""
S3 utilities for document storage.

Replaces filesystem operations (U:\docketwatch\docs\, U:\docketwatch\uploads\)
with S3 bucket operations.
"""

import os
import logging
import tempfile

import boto3

log = logging.getLogger(__name__)

AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
DOCS_BUCKET = os.environ.get('S3_DOCS_BUCKET', 'dw-documents')
UPLOADS_BUCKET = os.environ.get('S3_UPLOADS_BUCKET', 'dw-uploads')

_s3_client = None


def get_s3_client():
    """Get or create the S3 client (singleton)."""
    global _s3_client
    if _s3_client is None:
        endpoint_url = os.environ.get('S3_ENDPOINT_URL')  # For LocalStack
        _s3_client = boto3.client(
            's3',
            region_name=AWS_REGION,
            endpoint_url=endpoint_url,
        )
    return _s3_client


def download_to_temp(bucket, key):
    """Download an S3 object to a temporary file and return the path."""
    s3 = get_s3_client()
    suffix = os.path.splitext(key)[1] or '.pdf'
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    try:
        s3.download_fileobj(bucket, key, tmp)
        tmp.close()
        log.info(f'Downloaded s3://{bucket}/{key} to {tmp.name}')
        return tmp.name
    except Exception:
        tmp.close()
        os.unlink(tmp.name)
        raise


def upload_file(local_path, bucket, key, content_type='application/pdf'):
    """Upload a local file to S3."""
    s3 = get_s3_client()
    s3.upload_file(
        local_path, bucket, key,
        ExtraArgs={'ContentType': content_type},
    )
    log.info(f'Uploaded {local_path} to s3://{bucket}/{key}')


def upload_bytes(data, bucket, key, content_type='application/pdf'):
    """Upload bytes to S3."""
    s3 = get_s3_client()
    s3.put_object(Bucket=bucket, Key=key, Body=data, ContentType=content_type)
    log.info(f'Uploaded {len(data)} bytes to s3://{bucket}/{key}')


def delete_object(bucket, key):
    """Delete an object from S3."""
    s3 = get_s3_client()
    s3.delete_object(Bucket=bucket, Key=key)
    log.info(f'Deleted s3://{bucket}/{key}')
