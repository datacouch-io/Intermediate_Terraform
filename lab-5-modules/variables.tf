variable "aws_region" {
  description = "Region for all environments."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project prefix, shared across workspaces."
  type        = string
  default     = "tflab5"
}
