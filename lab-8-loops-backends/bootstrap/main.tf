# ---------------------------------------------------------------------------
# The chicken-and-egg problem: a remote backend needs an S3 bucket, but you
# cannot store this configuration's state IN the bucket it is creating.
# So the bootstrap keeps LOCAL state, deliberately, and stays tiny.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "intermediate-terraform"
      Lab       = "8"
      ManagedBy = "terraform"
      Purpose   = "tf-state-backend"
    }
  }
}

variable "aws_region" {
  description = "Region for the state backend."
  type        = string
  default     = "us-east-1"
}

# S3 bucket names are GLOBALLY unique across every AWS account on earth.
# A fixed name in a lab guarantees a collision with the previous student.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "tflab8-tfstate-${random_id.suffix.hex}"
  table_name  = "tflab8-tfstate-locks"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # A lab convenience ONLY. Never set this on a real state bucket.
  force_destroy = true

  tags = { Name = local.bucket_name }
}

# Versioning is the difference between "someone corrupted state" being an
# inconvenience and being an outage. Turn it on before storing anything.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State files contain every attribute of every resource in plaintext.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The classic lock table. Terraform 1.10+ can lock using S3 alone
# (use_lockfile = true) -- this lab demonstrates both, see the lab document.
resource "aws_dynamodb_table" "locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # no idle cost
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = local.table_name }
}

output "bucket_name" {
  description = "Paste this into the backend block in ../fleet/backend.tf"
  value       = aws_s3_bucket.state.id
}

output "table_name" {
  description = "DynamoDB lock table name."
  value       = aws_dynamodb_table.locks.name
}

output "backend_block" {
  description = "The exact backend configuration to use, ready to copy."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "lab8/fleet/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
