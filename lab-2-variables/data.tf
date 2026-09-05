# Ask AWS for the current Amazon Linux 2023 image instead of hardcoding an ID
# that is wrong in every other region and goes stale within weeks.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Who am I, and where am I? Useful in outputs and for building ARNs.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
