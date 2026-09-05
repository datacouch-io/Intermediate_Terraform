terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

locals {
  module_tags = merge(var.tags, {
    Module      = "web-server"
    Environment = var.environment
  })
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "HTTP in, all out - managed by the web-server module"
  vpc_id      = var.vpc_id

  tags = merge(local.module_tags, { Name = "${var.name}-web-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  cidr_ipv4         = var.allowed_http_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    name        = var.name
    environment = var.environment
    index       = count.index + 1
    total       = var.instance_count
  })

  user_data_replace_on_change = true

  tags = merge(local.module_tags, { Name = "${var.name}-web-${count.index + 1}" })
}
