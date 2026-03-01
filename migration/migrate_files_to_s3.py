"""
DocketWatch File Migration: Windows File Share → S3

Migrates all document files from the Windows file share
(U:\docketwatch\) to S3 buckets, updating database records.

Usage:
    python migrate_files_to_s3.py --source \\server\docketwatch --dry-run
    python migrate_files_to_s3.py --source \\server\docketwatch

Environment Variables:
    AWS_REGION          - AWS region (default: us-east-1)
    S3_DOCS_BUCKET      - S3 bucket for case documents (default: dw-documents)
    S3_UPLOADS_BUCKET   - S3 bucket for ad-hoc uploads (default: dw-uploads)
    DATABASE_URL        - PostgreSQL connection string
"""

import argparse
import hashlib
import logging
import os
import sys

import boto3
import psycopg2

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger(__name__)

AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
DOCS_BUCKET = os.environ.get('S3_DOCS_BUCKET', 'dw-documents')
UPLOADS_BUCKET = os.environ.get('S3_UPLOADS_BUCKET', 'dw-uploads')
DATABASE_URL = os.environ.get('DATABASE_URL', '')


def migrate_case_documents(source_root, s3_client, conn, dry_run=False):
    """Migrate case documents from docs/cases/ to S3."""
    docs_dir = os.path.join(source_root, 'docs', 'cases')

    if not os.path.exists(docs_dir):
        log.warning(f'Case docs directory not found: {docs_dir}')
        return 0

    migrated = 0
    errors = 0

    for case_dir in os.listdir(docs_dir):
        case_path = os.path.join(docs_dir, case_dir)
        if not os.path.isdir(case_path):
            continue

        for filename in os.listdir(case_path):
            filepath = os.path.join(case_path, filename)
            if not os.path.isfile(filepath):
                continue

            s3_key = f'cases/{case_dir}/{filename}'
            rel_path = f'docs/cases/{case_dir}/{filename}'

            if dry_run:
                log.info(f'[DRY RUN] Would upload {filepath} -> s3://{DOCS_BUCKET}/{s3_key}')
                migrated += 1
                continue

            try:
                # Upload to S3
                file_size = os.path.getsize(filepath)
                s3_client.upload_file(
                    filepath, DOCS_BUCKET, s3_key,
                    ExtraArgs={'ContentType': 'application/pdf'},
                )

                # Compute SHA-256
                sha256 = _file_hash(filepath)

                # Update database record
                with conn.cursor() as cur:
                    cur.execute(
                        """UPDATE documents
                           SET s3_key = %s, file_size = %s, sha256_hash = %s
                           WHERE rel_path LIKE %s AND s3_key IS NULL""",
                        (s3_key, file_size, sha256, f'%{rel_path}%'),
                    )
                    if cur.rowcount > 0:
                        log.info(f'Updated {cur.rowcount} doc record(s) for {s3_key}')

                conn.commit()
                migrated += 1

                if migrated % 100 == 0:
                    log.info(f'Migrated {migrated} files...')

            except Exception as e:
                log.error(f'Failed to migrate {filepath}: {e}')
                errors += 1
                conn.rollback()

    log.info(f'Case documents: {migrated} migrated, {errors} errors')
    return migrated


def migrate_uploads(source_root, s3_client, conn, dry_run=False):
    """Migrate ad-hoc uploads from uploads/ to S3."""
    uploads_dir = os.path.join(source_root, 'uploads')

    if not os.path.exists(uploads_dir):
        log.warning(f'Uploads directory not found: {uploads_dir}')
        return 0

    migrated = 0

    for filename in os.listdir(uploads_dir):
        filepath = os.path.join(uploads_dir, filename)
        if not os.path.isfile(filepath):
            continue

        s3_key = f'uploads/{filename}'

        if dry_run:
            log.info(f'[DRY RUN] Would upload {filepath} -> s3://{UPLOADS_BUCKET}/{s3_key}')
            migrated += 1
            continue

        try:
            s3_client.upload_file(
                filepath, UPLOADS_BUCKET, s3_key,
                ExtraArgs={'ContentType': 'application/pdf'},
            )
            migrated += 1
        except Exception as e:
            log.error(f'Failed to migrate upload {filepath}: {e}')

    log.info(f'Uploads: {migrated} migrated')
    return migrated


def verify_migration(s3_client, conn):
    """Verify that all document records have valid S3 keys."""
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM documents WHERE s3_key IS NOT NULL")
        with_s3 = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM documents WHERE s3_key IS NULL AND rel_path IS NOT NULL")
        missing = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM documents")
        total = cur.fetchone()[0]

    log.info(f'Verification: {with_s3}/{total} documents have S3 keys, {missing} still need migration')

    if missing > 0:
        log.warning(f'{missing} documents still need file migration')
    else:
        log.info('All documents migrated successfully!')


def _file_hash(filepath):
    """Compute SHA-256 hash of a file."""
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description='Migrate DocketWatch files to S3')
    parser.add_argument('--source', required=True, help='Source directory (e.g., U:\\docketwatch or //server/docketwatch)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    parser.add_argument('--verify-only', action='store_true', help='Only run verification checks')
    args = parser.parse_args()

    if not DATABASE_URL:
        log.error('DATABASE_URL environment variable is required')
        sys.exit(1)

    conn = psycopg2.connect(DATABASE_URL)
    s3_client = boto3.client('s3', region_name=AWS_REGION)

    if args.verify_only:
        verify_migration(s3_client, conn)
        conn.close()
        return

    log.info(f'Starting file migration from {args.source}')
    if args.dry_run:
        log.info('DRY RUN MODE - no changes will be made')

    total = 0
    total += migrate_case_documents(args.source, s3_client, conn, args.dry_run)
    total += migrate_uploads(args.source, s3_client, conn, args.dry_run)

    log.info(f'Migration complete: {total} files processed')

    if not args.dry_run:
        verify_migration(s3_client, conn)

    conn.close()


if __name__ == '__main__':
    main()
