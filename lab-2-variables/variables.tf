variable "aws_region" {
  description = "AWS region to deploy into. AMI lookup is region-aware, so this is now safe to change."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used to build every resource name."
  type        = string
  default     = "tflab"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,16}$", var.project_name))
    error_message = "project_name must be 2-16 characters of lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. Drives naming and the instance size map."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Set explicitly to override the per-environment default."
  type        = string
  default     = "t3.micro"
}

variable "owner" {
  description = "Team or person accountable for these resources. Applied as a tag."
  type        = string
  default     = "platform-team"
}
