# A module communicates results ONLY through outputs. Nothing else it creates
# is reachable from the caller.

output "instance_ids" {
  description = "IDs of every instance this module created."
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IPv4 addresses of every instance."
  value       = aws_instance.web[*].public_ip
}

output "urls" {
  description = "Ready-to-open URLs, one per instance."
  value       = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}

output "security_group_id" {
  description = "The security group the module created."
  value       = aws_security_group.web.id
}

output "instance_count" {
  description = "How many instances the module actually created."
  value       = length(aws_instance.web)
}
