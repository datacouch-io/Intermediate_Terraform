# A module's variables are its API. Everything a caller may set lives here,
# with a type, a description, and a default only where a sane one exists.

variable "name" {
  description = "Base name for resources this module creates. Must be unique per caller."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to place the instance in. The caller owns the network."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security group is created in."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "How many identical web servers to create."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5
    error_message = "instance_count must be between 1 and 5 (a lab guardrail, not an AWS limit)."
  }
}

variable "allowed_http_cidr" {
  description = "CIDR permitted to reach port 80."
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Environment label, surfaced on the served page and in tags."
  type        = string
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
