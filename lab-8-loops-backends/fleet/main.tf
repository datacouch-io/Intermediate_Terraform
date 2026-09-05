terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  # NO backend block yet. State starts local, on purpose -- the migration
  # is the point of this lab. backend.tf is added in Step 4.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "intermediate-terraform"
      Lab       = "8"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  description = "Region for the fleet."
  type        = string
  default     = "us-east-1"
}

variable "fleet_size" {
  description = "How many identical web servers to run. This is the loop."
  type        = number
  default     = 3

  validation {
    condition     = var.fleet_size >= 0 && var.fleet_size <= 6
    error_message = "fleet_size must be between 0 and 6 (a lab cost guardrail)."
  }
}

variable "instance_type" {
  description = "Instance type for every member of the fleet."
  type        = string
  default     = "t3.micro"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

# ---------------------------------------------------------------------------
# THE LOOP. One block, N identical instances. count is the right tool here --
# unlike Lab 7, these servers are genuinely interchangeable and have no
# individual identity, so positional addressing costs nothing.
# ---------------------------------------------------------------------------
resource "aws_instance" "fleet" {
  count = var.fleet_size

  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type

  # count.index is 0-based; humans count from 1.
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    node_number = count.index + 1
    fleet_size  = var.fleet_size
  })

  user_data_replace_on_change = true

  tags = {
    Name       = format("tflab8-node-%02d", count.index + 1)
    NodeNumber = tostring(count.index + 1)
    FleetSize  = tostring(var.fleet_size)
  }
}

output "fleet_size" {
  description = "How many instances the loop actually produced."
  value       = length(aws_instance.fleet)
}

output "node_names" {
  description = "Generated node names, zero-padded by format()."
  value       = aws_instance.fleet[*].tags["Name"]
}

output "instance_ids" {
  description = "Every instance ID in the fleet."
  value       = aws_instance.fleet[*].id
}

output "urls" {
  description = "One URL per fleet member."
  value       = [for ip in aws_instance.fleet[*].public_ip : "http://${ip}"]
}
