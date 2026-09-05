variable "aws_region" {
  description = "Region."
  type        = string
  default     = "us-east-1"
}

variable "enable_bastion" {
  description = "Whether to create the optional bastion host."
  type        = bool
  default     = false
}
