terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "lab" {
  ami           = "ami-081b0a6eac00b4f53" # Amazon Linux 2023, us-east-1
  instance_type = "t3.micro"

  tags = {
    Name    = "tf-lab1-first-instance"
    Lab     = "1"
    Course  = "intermediate-terraform"
  }
}

output "instance_id" {
  description = "The EC2 instance ID Terraform created."
  value       = aws_instance.lab.id
}

output "instance_public_ip" {
  description = "Public IPv4 address assigned to the instance."
  value       = aws_instance.lab.public_ip
}
