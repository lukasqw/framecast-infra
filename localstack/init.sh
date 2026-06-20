#!/bin/bash
# LocalStack init — cria recursos AWS simulados para dev local
set -e

AWS="aws --endpoint-url=http://localhost:4566 --region us-east-1"

echo "==> Criando buckets S3..."
$AWS s3 mb s3://framecast-videos-raw    || true
$AWS s3 mb s3://framecast-videos-output || true

echo "==> Aplicando CORS no bucket raw (upload multipart presigned)..."
$AWS s3api put-bucket-cors \
  --bucket framecast-videos-raw \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }]
  }'

echo "==> Criando DLQ SQS..."
$AWS sqs create-queue \
  --queue-name framecast-processing-dlq \
  --attributes MessageRetentionPeriod=1209600

DLQ_ARN=$($AWS sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/framecast-processing-dlq \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

echo "==> Criando fila SQS de processamento (visibility=900s, DLQ maxReceiveCount=3)..."
$AWS sqs create-queue \
  --queue-name framecast-processing \
  --attributes \
    VisibilityTimeout=900 \
    MessageRetentionPeriod=1209600 \
    RedrivePolicy="{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":\"3\"}"

echo "==> Verificando identidade SES..."
$AWS ses verify-email-identity --email-address noreply@framecast.local || true

echo ""
echo "==> LocalStack pronto:"
echo "    S3  raw:    s3://framecast-videos-raw"
echo "    S3  output: s3://framecast-videos-output"
echo "    SQS:        http://localhost:4566/000000000000/framecast-processing"
echo "    SQS DLQ:    http://localhost:4566/000000000000/framecast-processing-dlq"
echo "    SES:        noreply@framecast.local"
