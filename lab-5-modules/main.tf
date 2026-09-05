# ---------------------------------------------------------------------------
# Per-workspace settings. ONE definition, selected by terraform.workspace.
# This is what makes dev and prod the same code with different inputs.
# ---------------------------------------------------------------------------
locals {
  env_settings = {
    dev = {
      instance_type  = "t3.micro"
      instance_count = 1
      vpc_cidr       = "10.51.0.0/16"
    }
    prod = {
      instance_type  = "t3.small"
      instance_count = 2
      vpc_cidr       = "10.52.0.0/16"
    }
  }

  # Direct index, NOT lookup(..., null): an unknown workspace must fail here,
  # with a message naming the key, rather than yielding null and failing later
  # somewhere unrelated. See this lab's Step 3 for why the obvious alternative
  # (a lifecycle precondition) does not work.
  env = local.env_settings[terraform.workspace]

  name = "${var.project_name}-${terraform.workspace}"
}

# ---------------------------------------------------------------------------
# EXTERNAL module, from the public Terraform Registry (backed by GitHub).
# We did not write this and do not maintain it.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.env.vpc_cidr

  azs            = ["${var.aws_region}a"]
  public_subnets = [cidrsubnet(local.env.vpc_cidr, 8, 1)]

  # A NAT gateway costs ~$32/month and this lab does not need one.
  enable_nat_gateway = false
  map_public_ip_on_launch = true

  tags = { Environment = terraform.workspace }
}

# ---------------------------------------------------------------------------
# LOCAL module, the one we wrote, called with per-workspace values.
# ---------------------------------------------------------------------------
module "web" {
  source = "./modules/web-server"

  name           = local.name
  environment    = terraform.workspace
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.public_subnets[0]
  instance_type  = local.env.instance_type
  instance_count = local.env.instance_count

  tags = { Project = var.project_name }
}
