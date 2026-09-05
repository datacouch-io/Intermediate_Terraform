variable "aws_region" {
  description = "Region for all resources in this lab."
  type        = string
  default     = "us-east-1"
}

variable "monitoring_enabled" {
  description = "Whether detailed CloudWatch monitoring is on. Used to demonstrate drift on a non-tag attribute."
  type        = bool
  default     = false
}
