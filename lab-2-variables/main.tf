resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app"
  })
}

# Post-deploy hook: write the deployed instance's details to a local file.
# triggers force the provisioner to re-run whenever the instance changes.
resource "null_resource" "record_deployment" {
  triggers = {
    instance_id = aws_instance.app.id
    public_ip   = aws_instance.app.public_ip
    # Without this line the provisioner does not re-run when only the naming
    # changes, and deployment.txt silently goes stale while `terraform plan`
    # still reports no drift. See this lab's validation section.
    name_prefix = local.name_prefix
  }

  provisioner "local-exec" {
    command = <<-CMD
      printf '%s\n' \
        "deployed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "name=${local.name_prefix}-app" \
        "instance_id=${aws_instance.app.id}" \
        "public_ip=${aws_instance.app.public_ip}" \
        "instance_type=${aws_instance.app.instance_type}" \
        "ami=${aws_instance.app.ami}" \
        > deployment.txt
    CMD
  }
}
