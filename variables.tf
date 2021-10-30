variable "region" {
  type        = string
  description = "select aws region"
  //default = "us-east-1"
}

variable "aws_profile" {
  type = string
  // default = "dev"
  description = "aws profile"
}

variable "vpc-cidr" {
  type = string
  // default = "10.0.0.0/16"
  description = "VPC CIDR"
}

variable "route_cidr" {
  type = string
  //  default = "0.0.0.0/0"
  description = "Route CIDR"
}

variable "subnet_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

data "aws_availability_zones" "azs" {}

// RDS VARIABLES

variable "rds_name" {
  type = string

}

variable "rds_username" {
  type = string

}


variable "rds_password" {
  type = string

}

variable "engine" {
  type = string
}

variable "engine_version" {
  type = string
}

// BUCKET VARIABLES

variable "bucket" {
  type = string
}

// INSTANCE VARIABLES

variable "ami" {
  type = string
}


// variable "key_name" {
//   type =string
// }




