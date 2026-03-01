package queue

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/rs/zerolog/log"
)

// SQSClient wraps the AWS SQS client for sending messages.
type SQSClient struct {
	client *sqs.Client
}

// NewSQSClient creates a new SQS client.
func NewSQSClient(ctx context.Context, region, endpoint string) (*SQSClient, error) {
	opts := []func(*awsconfig.LoadOptions) error{
		awsconfig.WithRegion(region),
	}

	cfg, err := awsconfig.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	client := sqs.NewFromConfig(cfg, func(o *sqs.Options) {
		if endpoint != "" {
			o.BaseEndpoint = aws.String(endpoint)
		}
	})

	return &SQSClient{client: client}, nil
}

// SummarizeMessage is the SQS message for document summarization.
type SummarizeMessage struct {
	DocumentID int    `json:"doc_id"`
	S3Key      string `json:"s3_key"`
	S3Bucket   string `json:"s3_bucket"`
}

// QAMessage is the SQS message for document Q&A.
type QAMessage struct {
	DocumentID int    `json:"doc_id"`
	Question   string `json:"question"`
	Username   string `json:"username"`
}

// PACERMessage is the SQS message for PACER document download.
type PACERMessage struct {
	DocumentID int    `json:"doc_id"`
	PACERUrl   string `json:"pacer_url"`
	S3Bucket   string `json:"s3_bucket"`
	S3Key      string `json:"s3_key"`
}

// SendSummarize sends a document to the summarize queue.
func (c *SQSClient) SendSummarize(ctx context.Context, queueURL string, msg SummarizeMessage) error {
	return c.send(ctx, queueURL, msg)
}

// SendQA sends a Q&A request to the queue.
func (c *SQSClient) SendQA(ctx context.Context, queueURL string, msg QAMessage) error {
	return c.send(ctx, queueURL, msg)
}

// SendPACER sends a PACER download request to the queue.
func (c *SQSClient) SendPACER(ctx context.Context, queueURL string, msg PACERMessage) error {
	return c.send(ctx, queueURL, msg)
}

func (c *SQSClient) send(ctx context.Context, queueURL string, msg interface{}) error {
	body, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	_, err = c.client.SendMessage(ctx, &sqs.SendMessageInput{
		QueueUrl:    aws.String(queueURL),
		MessageBody: aws.String(string(body)),
	})
	if err != nil {
		log.Error().Err(err).Str("queue", queueURL).Msg("Failed to send SQS message")
		return fmt.Errorf("failed to send SQS message: %w", err)
	}

	log.Info().Str("queue", queueURL).Msg("SQS message sent")
	return nil
}
