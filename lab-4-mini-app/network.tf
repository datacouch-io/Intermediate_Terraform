# A purpose-built VPC. Labs 1-3 used the default VPC; a real project does not.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for public DNS names on instances

  tags = { Name = "${var.project_name}-vpc" }
}

# Without an internet gateway the subnet is private no matter what else you do.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1) # 10.20.1.0/24 from a /16
  availability_zone = data.aws_availability_zones.available.names[0]

  # What actually makes this subnet "public" is the route table below; this
  # only saves you from attaching an EIP by hand.
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-subnet" }
}

# THE line that makes the subnet public: a default route to the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
