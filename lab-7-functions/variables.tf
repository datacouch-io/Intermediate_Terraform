# THE single source of truth for this lab. Every resource name, every tag and
# the number of instances is derived from this one list. Add an element and
# infrastructure follows; nothing else in the configuration is edited.
variable "environments" {
  description = "Environment names to deploy. Everything else is computed from this."
  type        = list(string)
  default     = ["dev", "staging", "prod"]

  validation {
    condition     = length(var.environments) == length(distinct(var.environments))
    error_message = "environments must not contain duplicates."
  }

  validation {
    condition     = length(var.environments) > 0
    error_message = "environments must contain at least one entry."
  }
}

variable "project" {
  description = "Project slug used as the first element of every generated name."
  type        = string
  default     = "tflab7"
}

variable "aws_region" {
  description = "Region."
  type        = string
  default     = "us-east-1"
}

# A raw, messy string of the kind you get from a CI variable or a CSV column.
variable "owner_csv" {
  description = "Comma-separated owner emails, deliberately messy, to be split and cleaned."
  type        = string
  default     = " platform@example.com, sre@example.com ,data@example.com "
}

# Per-environment sizing, as a map. Demonstrates lookup() with a default.
variable "size_map" {
  description = "Instance type per environment. Environments absent from this map fall back to the default."
  type        = map(string)
  default = {
    prod    = "t3.small"
    staging = "t3.micro"
  }
}

# Which environment names count as production. Kept as data, not baked into an
# expression -- `env == "prod"` in locals.tf is a hardcoded environment name,
# which is exactly what this lab argues against. Caught by validate.sh check 8.
variable "production_envs" {
  description = "Environment names that should be treated as production."
  type        = list(string)
  default     = ["prod"]
}
