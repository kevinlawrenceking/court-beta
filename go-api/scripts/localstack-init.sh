#!/bin/bash
# Initialize LocalStack resources for local development

echo "Creating S3 buckets..."
awslocal s3 mb s3://dw-documents
awslocal s3 mb s3://dw-uploads
awslocal s3 mb s3://dw-frontend

echo "Creating SQS queues..."
awslocal sqs create-queue --queue-name dw-summarize-queue
awslocal sqs create-queue --queue-name dw-ocr-queue
awslocal sqs create-queue --queue-name dw-match-queue
awslocal sqs create-queue --queue-name dw-summarize-dlq
awslocal sqs create-queue --queue-name dw-ocr-dlq
awslocal sqs create-queue --queue-name dw-match-dlq

echo "LocalStack initialization complete."
