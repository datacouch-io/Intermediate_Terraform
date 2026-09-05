variable "aws_region" {
  description = "Region for the mini-app."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for every resource name."
  type        = string
  default     = "tflab4"
}

variable "vpc_cidr" {
  description = "CIDR block for the purpose-built VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.20.0.0/16."
  }
}

variable "instance_type" {
  description = "Instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "allowed_http_cidr" {
  description = "CIDR permitted to reach port 80. Defaults to the whole internet because this lab's visible result is a public web page."
  type        = string
  default     = "0.0.0.0/0"
}
