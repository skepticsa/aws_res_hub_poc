variable "project" {
  type        = string
  description = "Project name"
}

variable "region" {
  type        = string
  description = "Region of the VPC"
}

variable "availability_zones" {
  type        = list(any)
  description = "List of availability zones"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr_blocks" {
  type        = list(any)
  description = "List of public subnet CIDR blocks"
}

variable "private_subnet_cidr_blocks" {
  type        = list(any)
  description = "List of private subnet CIDR blocks"
}

variable "ec2_ami" {
  type        = string
  description = "ami for ec2"
}

variable "ec2_type" {
  type        = string
  description = "ec2 type"
}

variable "myip_cidr" {
  type        = list(any)
  description = "My IP address"
}

variable "username" {
  type        = string
  description = "RDS root username"
}

variable "password" {
  type        = string
  description = "RDS root password"
}
