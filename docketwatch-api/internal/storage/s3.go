package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// S3Store provides operations for S3 object storage.
type S3Store struct {
	client *s3.Client
}

// NewS3Store creates a new S3Store using the default AWS config.
func NewS3Store(ctx context.Context, region string) (*S3Store, error) {
	cfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &S3Store{client: s3.NewFromConfig(cfg)}, nil
}

// NewS3StoreWithEndpoint creates an S3Store with a custom endpoint (for LocalStack in dev).
func NewS3StoreWithEndpoint(ctx context.Context, region, endpoint string) (*S3Store, error) {
	cfg, err := awsconfig.LoadDefaultConfig(ctx,
		awsconfig.WithRegion(region),
	)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = true
	})

	return &S3Store{client: client}, nil
}

// PutObject uploads data to an S3 bucket.
func (s *S3Store) PutObject(ctx context.Context, bucket, key string, data []byte, contentType string) error {
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return fmt.Errorf("put s3 object %s/%s: %w", bucket, key, err)
	}
	return nil
}

// GetObject downloads data from an S3 bucket.
func (s *S3Store) GetObject(ctx context.Context, bucket, key string) ([]byte, error) {
	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("get s3 object %s/%s: %w", bucket, key, err)
	}
	defer out.Body.Close()

	data, err := io.ReadAll(out.Body)
	if err != nil {
		return nil, fmt.Errorf("read s3 object: %w", err)
	}
	return data, nil
}

// DeleteObject removes an object from S3.
func (s *S3Store) DeleteObject(ctx context.Context, bucket, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("delete s3 object %s/%s: %w", bucket, key, err)
	}
	return nil
}

// GeneratePresignedURL creates a presigned URL for downloading an object.
func (s *S3Store) GeneratePresignedURL(ctx context.Context, bucket, key string) (string, error) {
	presignClient := s3.NewPresignClient(s.client)
	out, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return "", fmt.Errorf("presign s3 object: %w", err)
	}
	return out.URL, nil
}
