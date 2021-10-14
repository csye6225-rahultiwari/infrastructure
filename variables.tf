variable "region" {
  type        = string
  description = "select aws region"
}


variable "aws_profile" {
  type        = string
  description = "aws profile"
}

variable "vpc-cidr" {
  type        = string
  description = "VPC CIDR"
}

variable "route_cidr" {
  type        = string
  description = "Route CIDR"
}


variable "subnet_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

data "aws_availability_zones" "azs" {}