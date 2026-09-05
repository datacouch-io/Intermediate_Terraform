data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  tags = {
    Name = "tf-lab6-app"
  }
}

# ERROR 4: a conditional resource whose output is referenced as if it always exists
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  tags = {
    Name = "tf-lab6-bastion"
  }
}
