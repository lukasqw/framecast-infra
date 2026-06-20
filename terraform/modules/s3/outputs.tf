output "bucket_raw" {
  description = "Nome do bucket S3 de vídeos originais"
  value       = aws_s3_bucket.raw.id
}

output "bucket_raw_arn" {
  description = "ARN do bucket S3 de vídeos originais"
  value       = aws_s3_bucket.raw.arn
}

output "bucket_output" {
  description = "Nome do bucket S3 de ZIPs de frames"
  value       = aws_s3_bucket.output.id
}

output "bucket_output_arn" {
  description = "ARN do bucket S3 de ZIPs de frames"
  value       = aws_s3_bucket.output.arn
}
