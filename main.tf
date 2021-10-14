// Create VPC
// Creating AWS VPC using Terraform



locals {
  enable_dns_hostnames    = true
  instance_tenancy        = "default"
  map_public_ip_on_launch = true
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  instance_tenancy     = local.instance_tenancy
  enable_dns_hostnames = local.enable_dns_hostnames

  tags = {
    Name = "VPC"
  }
}

// Creating Internet Gateway and attaching it to VPC
// terraform aws create internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "IGW-VPC"
  }
}

// Creating Public Subnets
// terraform aws create subnet
resource "aws_subnet" "public-subnets" {

  depends_on = [aws_vpc.vpc]
  // for_each = local.subnet_az_cidr
  count                   = length(var.subnet_cidr)
  map_public_ip_on_launch = local.map_public_ip_on_launch
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.subnet_cidr, count.index)
  availability_zone       = element(data.aws_availability_zones.azs.names, count.index)


  tags = {
    Name = "Public Subnet"
  }
}

// Creating Route Table and Add Public Route
// terraform aws create route table

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.route_cidr
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "Public Route Table"
  }
}


// Associate Public Subnet 1 to "Public Route Table"
// terraform aws associate subnet with route table

resource "aws_route_table_association" "public-subnets-route-table-association" {
  count          = length(var.subnet_cidr)
  subnet_id      = element(aws_subnet.public-subnets.*.id, count.index)
  route_table_id = aws_route_table.public-route-table.id
}



