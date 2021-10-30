// Create VPC
// terraform aws create vpc

locals {
  enable_dns_hostnames = true
  instance_tenancy     = "default"


  map_public_ip_on_launch = true
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  instance_tenancy     = local.instance_tenancy
  enable_dns_hostnames = local.enable_dns_hostnames

  tags = {
    Name = "CSYE6225-VPC"
  }
}

// Create Internet Gateway and Attach it to VPC
// terraform aws create internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "IGW-VPC"
  }
}

// Create Public Subnets
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
    Name = "Subnet ${count.index + 1}"
  }
}

// Create Route Table and Add Public Route
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


// Associate Public Subnet to "Public Route Table"
// terraform aws associate subnet with route table

resource "aws_route_table_association" "public-subnets-route-table-association" {
  count          = length(var.subnet_cidr)
  subnet_id      = element(aws_subnet.public-subnets.*.id, count.index)
  route_table_id = aws_route_table.public-route-table.id
}


resource "aws_db_subnet_group" "db-subnet" {
  name       = "test-group-1"
  subnet_ids = aws_subnet.public-subnets.*.id
}


resource "aws_db_parameter_group" "rds" {
  name   = "rds-csye6225-pg"
  family = "postgres13"

  parameter {
    name         = "log_connections"
    value        = 1
    apply_method = "pending-reboot"
  }


}

// Network Interface

resource "aws_network_interface" "my-interface" {

  subnet_id       = element(aws_subnet.public-subnets.*.id, 1)
  security_groups = [aws_security_group.webserver.id]

  tags = {
    Name = "csye6225-Interface"
  }
}








resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow"
        }
      ]
    }
EOF
}

#Policy

resource "aws_iam_policy" "WebAppS3" {
  name        = "WebAppS3"
  description = "policy for webApp"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.bucket}",
                "arn:aws:s3:::${var.bucket}/*"
            ]
        }
    ]
}
EOF
}

#IAM Policy
resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}

#IAM Instance Profile
resource "aws_iam_instance_profile" "csye6225_profile" {
  name = "csye6225_profile"
  role = aws_iam_role.EC2-CSYE6225.name
}







