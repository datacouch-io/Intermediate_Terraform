resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow inbound HTTP and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-web-sg" }
}

# Rules as separate resources rather than inline blocks: inline `ingress`/`egress`
# blocks are exhaustive and fight with anything that edits rules out of band.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from the allowed CIDR"
  cidr_ipv4         = var.allowed_http_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound - needed to install the web server"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
