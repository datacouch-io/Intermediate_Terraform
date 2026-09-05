data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

locals {
  common_tags = {
    Course    = "intermediate-terraform"
    Lab       = "3"
    ManagedBy = "terraform"
  }
}

# The resource we will deliberately drift.
resource "aws_instance" "managed" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  monitoring    = var.monitoring_enabled

  tags = merge(local.common_tags, {
    Name = "tf-lab3-managed"
  })
}

output "managed_instance_id" {
  value       = aws_instance.managed.id
  description = "ID of the Terraform-managed instance."
}
