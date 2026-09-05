output "name_prefix" {
  description = "The computed naming convention every resource in this project uses."
  value       = local.name_prefix
}

output "resolved_ami" {
  description = "The AMI the data source selected, and its publication date."
  value = {
    id            = data.aws_ami.al2023.id
    name          = data.aws_ami.al2023.name
    creation_date = data.aws_ami.al2023.creation_date
  }
}

output "instance" {
  description = "Key facts about the deployed instance."
  value = {
    id            = aws_instance.app.id
    public_ip     = aws_instance.app.public_ip
    instance_type = aws_instance.app.instance_type
    name_tag      = aws_instance.app.tags["Name"]
  }
}

output "deployed_into" {
  description = "Region the provider actually used."
  value       = data.aws_region.current.region
}
