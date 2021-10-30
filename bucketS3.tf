#Amazon S3 Bucket

locals {
  force_destroy = true
  acl           = "private"
  sse_algorithm = "aws:kms"
  storage_class = "STANDARD_IA"


}
resource "random_string" "suffix"{
    length = 10
    upper = false
    lower = true
    special = false
}


resource "aws_s3_bucket" "csye6225-bucket" {
  bucket        = "${random_string.suffix.result}"var.bucket
  acl           = local.acl
  force_destroy = local.force_destroy
  versioning {
    enabled = true
  }
  tags = {
    Name        = "csye6225 s3 Bucket"
    Environment = "DEV"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = local.sse_algorithm
      }
    }
  }

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = local.storage_class
    }
    expiration {
      days = 90
    }
  }
}