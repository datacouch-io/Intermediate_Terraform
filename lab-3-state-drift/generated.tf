# CAPTURED SAMPLE -- this is real output from `terraform plan
# -generate-config-out=generated.tf` during the authoring run, kept as a reference for
# what Terraform actually writes for you. Resource IDs have been replaced with
# EXAMPLEID placeholders; your own run produces this file with your real IDs.
#
# Note what it produced that you would NOT have written yourself: an `egress` block
# (AWS adds a default allow-all egress rule to every new security group), and a
# `tags_all` block that duplicates `tags` -- tags_all is computed and should be
# deleted. See Lab 3 Step 7.

# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "sg-EXAMPLEID"
resource "aws_security_group" "imported" {
  description = "Created outside Terraform, to be imported"
  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
    to_port          = 0
  }]
  ingress = [{
    cidr_blocks      = ["10.0.0.0/8"]
    description      = "internal https"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
  }]
  name                   = "tf-lab3-orphan-sg"
  region                 = "us-east-1"
  revoke_rules_on_delete = null
  tags = {
    Course = "intermediate-terraform"
    Lab    = "3"
    Name   = "tf-lab3-orphan-sg"
  }
  tags_all = {
    Course = "intermediate-terraform"
    Lab    = "3"
    Name   = "tf-lab3-orphan-sg"
  }
  vpc_id = "vpc-EXAMPLEID"
}
