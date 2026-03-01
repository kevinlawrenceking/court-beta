"""
DocketWatch Python Worker - SQS Message Consumer

Polls SQS queues and routes messages to the appropriate worker function.
Replaces the ColdFusion subprocess calls to Python scripts.

Workers:
  - summarize: OCR + AI summarization via FACT_GUARD pipeline
  - qa: Document Q&A from extracted JSON facts
  - pacer: PACER PDF download and storage to S3
"""

import json
import logging
import os
import signal
import sys
import time

import boto3

from summarize_worker import handle_summarize
from qa_worker import handle_qa
from pacer_worker import handle_pacer

logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

# Configuration from environment
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
SUMMARIZE_QUEUE_URL = os.environ.get('SQS_SUMMARIZE_URL', '')
QA_QUEUE_URL = os.environ.get('SQS_QA_URL', '')
PACER_QUEUE_URL = os.environ.get('SQS_PACER_URL', '')
DATABASE_URL = os.environ.get('DATABASE_URL', '')

# Graceful shutdown
_running = True


def _shutdown(signum, frame):
    global _running
    log.info(f'Received signal {signum}, shutting down...')
    _running = False


signal.signal(signal.SIGINT, _shutdown)
signal.signal(signal.SIGTERM, _shutdown)


def poll_queue(sqs_client, queue_url, handler_fn, queue_name):
    """Long-poll a single SQS queue and process messages."""
    try:
        response = sqs_client.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20,  # Long polling
            MessageAttributeNames=['All'],
        )
    except Exception as e:
        log.error(f'Failed to receive from {queue_name}: {e}')
        time.sleep(5)
        return

    messages = response.get('Messages', [])
    for msg in messages:
        receipt_handle = msg['ReceiptHandle']
        try:
            body = json.loads(msg['Body'])
            log.info(f'Processing {queue_name} message: {json.dumps(body)[:200]}')

            handler_fn(body)

            # Delete message on success
            sqs_client.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=receipt_handle,
            )
            log.info(f'{queue_name} message processed successfully')

        except Exception as e:
            log.error(f'{queue_name} handler failed: {e}', exc_info=True)
            # Message will return to queue after visibility timeout
            # and eventually move to DLQ after max receive count


def main():
    log.info('Starting DocketWatch Python worker')

    sqs = boto3.client('sqs', region_name=AWS_REGION)

    queues = []
    if SUMMARIZE_QUEUE_URL:
        queues.append((SUMMARIZE_QUEUE_URL, handle_summarize, 'summarize'))
    if QA_QUEUE_URL:
        queues.append((QA_QUEUE_URL, handle_qa, 'qa'))
    if PACER_QUEUE_URL:
        queues.append((PACER_QUEUE_URL, handle_pacer, 'pacer'))

    if not queues:
        log.error('No queue URLs configured. Set SQS_SUMMARIZE_URL, SQS_QA_URL, or SQS_PACER_URL.')
        sys.exit(1)

    log.info(f'Polling {len(queues)} queue(s): {[q[2] for q in queues]}')

    while _running:
        for queue_url, handler, name in queues:
            if not _running:
                break
            poll_queue(sqs, queue_url, handler, name)

    log.info('Worker stopped')


if __name__ == '__main__':
    main()
