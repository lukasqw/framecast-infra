# S3 Buckets — raw (upload multipart presigned) + output (ZIP de frames)

resource "aws_s3_bucket" "raw" {
  bucket        = var.bucket_raw
  force_destroy = true

  tags = merge(var.tags, {
    Name         = var.bucket_raw
    ResourceType = "s3-bucket"
    Service      = "s3"
    Purpose      = "video-uploads-raw"
  })
}

resource "aws_s3_bucket" "output" {
  bucket        = var.bucket_output
  force_destroy = true

  tags = merge(var.tags, {
    Name         = var.bucket_output
    ResourceType = "s3-bucket"
    Service      = "s3"
    Purpose      = "video-frames-output"
  })
}

# Block public access em ambos os buckets
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket = aws_s3_bucket.output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encriptação SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: abortar uploads multipart incompletos (evita storage leak — ver PLAN §6.3)
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }
}

# Lifecycle do bucket output: ZIPs de frames são efêmeros — expira após N dias.
resource "aws_s3_bucket_lifecycle_configuration" "output" {
  bucket = aws_s3_bucket.output.id

  rule {
    id     = "expire-frame-zips"
    status = "Enabled"

    filter {}

    expiration {
      days = var.output_retention_days
    }
  }
}

# CORS no bucket raw: permite PUT presigned direto do browser (upload multipart)
resource "aws_s3_bucket_cors_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
