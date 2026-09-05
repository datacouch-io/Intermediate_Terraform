output "function_results" {
  description = "What each function actually produced, so you can see the transformation."
  value = {
    "length(environments)"      = local.env_count
    "join(\"-\", ...)"          = local.all_names
    "sort(names)"               = local.sorted
    "split(\",\", owner_csv)"   = local.owners_raw
    "trimspace(each)"           = local.owners
    "owner domains (distinct)"  = local.owner_domain
    "upper(substr(env,0,3))"    = local.env_labels
  }
}

output "generated_names" {
  description = "Every resource name, computed from the environments list."
  value       = { for k, v in aws_instance.env : k => v.tags["Name"] }
}

output "instance_types" {
  description = "Instance type per environment, via lookup() with a fallback."
  value       = { for k, v in aws_instance.env : k => v.instance_type }
}

output "resource_addresses" {
  description = "Terraform addresses, showing for_each keys rather than [0],[1],[2]."
  value       = [for k, _ in local.env_map : "aws_instance.env[\"${k}\"]"]
}
