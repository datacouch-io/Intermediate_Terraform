# =============================================================================
# REFERENCE SOLUTION — Lab 9 capstone (S3 static website)
#
# INSTRUCTORS: do not distribute this before participants have attempted the
# challenge. The entire point of Lab 9 is arriving at something like this from
# the Terraform Registry documentation alone.
#
# There is no single correct answer. This is one working solution, tested.
# =============================================================================

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
      Lab       = "9"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  description = "Region for the website bucket."
  type        = string
  default     = "us-east-1"
}

variable "site_title" {
  description = "Title rendered on the generated index page."
  type        = string
  default     = "Deployed from documentation alone"
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "tflab9-site-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true # lab convenience: allows destroy with objects present

  tags = { Name = local.bucket_name }
}

# ---------------------------------------------------------------------------
# The part that is NOT obvious from a casual read of the docs.
#
# A static website bucket must be publicly readable, which means BOTH:
#   1. relaxing the public access block (it defaults to blocking everything),
#   2. attaching a bucket policy granting s3:GetObject to everyone.
#
# Modern S3 buckets have ACLs disabled by default (ObjectOwnership =
# BucketOwnerEnforced), so `acl = "public-read"` -- which most older tutorials
# use -- fails outright. The policy is the supported route.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
    }]
  })

  # The policy is rejected if the public access block still forbids it.
  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  # "text/html" alone is NOT enough: without an explicit charset the browser
  # falls back to latin-1 and every non-ASCII character is mojibake. The em
  # dash in the page rendered as "a EUR" until this was fixed.
  content_type = "text/html; charset=utf-8"

  content = templatefile("${path.module}/index.html.tftpl", {
    title       = var.site_title
    bucket_name = local.bucket_name
    region      = var.aws_region
  })
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.site.id
  key          = "error.html"
  content_type = "text/html; charset=utf-8"
  content      = "<!doctype html><title>404</title><h1>404 — not found</h1><p>Served by the S3 website endpoint.</p>"
}

output "website_endpoint" {
  description = "The lab's visible result. Open this in a browser."
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}

output "bucket_name" {
  value = aws_s3_bucket.site.id
}

# The REST endpoint, for contrast. It is NOT the website endpoint and does not
# serve index documents or the error page.
output "rest_endpoint" {
  description = "Deliberately included to contrast with the website endpoint."
  value       = "https://${aws_s3_bucket.site.bucket_regional_domain_name}"
}
