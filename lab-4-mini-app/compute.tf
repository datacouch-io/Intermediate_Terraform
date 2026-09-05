data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

locals {
  # templatefile() keeps the shell script in its own file instead of buried in
  # a heredoc, so an editor can syntax-highlight it and a reviewer can read it.
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    project_name = var.project_name
    region       = var.aws_region
  })
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = local.user_data

  # Replace the instance when the script changes, rather than leaving a running
  # box with stale content and no way to tell.
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-web" }
}
