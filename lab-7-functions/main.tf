data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

# for_each over the COMPUTED map. Not one resource name is typed by hand.
resource "aws_instance" "env" {
  for_each = local.env_map

  ami           = data.aws_ami.al2023.id
  instance_type = each.value.instance_type

  tags = merge(local.computed_tags, {
    Name       = each.value.name
    Env        = each.key
    EnvLabel   = local.env_labels[each.key]
    EnvIndex   = tostring(each.value.index)
    Production = tostring(each.value.is_production)
  })
}
