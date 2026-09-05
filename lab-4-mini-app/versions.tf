terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      # Pinned to a major version. A bare `version = "6.63.0"` would be
      # reproducible but unpatchable; ">= 6.0" would accept a breaking v7.
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Applied to every resource this provider creates, without repeating them.
  default_tags {
    tags = {
      Course    = "intermediate-terraform"
      Lab       = "4"
      ManagedBy = "terraform"
    }
  }
}
