locals {
  # A naming convention computed once and used everywhere. Change the convention
  # here and every resource name in the project follows.
  name_prefix = "${var.project_name}-${var.environment}"

  # Tags every resource should carry, merged with per-resource tags at use site.
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Course      = "intermediate-terraform"
    Lab         = "2"
  }

  # A derived value that is not just string concatenation: locals can hold logic.
  is_production = var.environment == "prod"
}
