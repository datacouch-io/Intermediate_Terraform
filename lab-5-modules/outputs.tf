output "workspace" {
  description = "Which workspace produced this deployment."
  value       = terraform.workspace
}

output "settings_used" {
  description = "The per-workspace settings that were selected."
  value       = local.env
}

output "vpc_id" {
  description = "VPC created by the EXTERNAL registry module."
  value       = module.vpc.vpc_id
}

output "urls" {
  description = "Every web server URL in this environment."
  value       = module.web.urls
}

output "instance_ids" {
  description = "Every instance ID in this environment."
  value       = module.web.instance_ids
}
