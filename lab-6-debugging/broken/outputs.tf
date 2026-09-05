output "app_id" {
  value = aws_instance.app.id
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
