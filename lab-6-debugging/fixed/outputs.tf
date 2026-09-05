output "app_id" {
  value = aws_instance.app.id
}

# CORRECT: one() collapses a 0-or-1 element list to a single value or null.
# Works whether enable_bastion is true or false. try() would also work but
# hides genuine errors; one() only tolerates the empty case.
output "bastion_ip" {
  description = "Bastion public IP, or null when the bastion is disabled."
  value       = one(aws_instance.bastion[*].public_ip)
}
