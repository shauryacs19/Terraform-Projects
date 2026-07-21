variable "environment" {
  description = "The environment for which the resources are being created."
  type        = string
  default     = "development"
}

variable "primary" {
  description = "The AWS region where the resources will be created."
  type        = string
  default     = "ap-south-1"
}

variable "secondary" {
  description = "The AWS region where the resources will be created."
  type        = string
  default     = "ap-south-2"
}

variable "primary_vpc_cidr" {
  description = "The CIDR block for the primary VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "The CIDR block for the secondary VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "instance_type" {
  description = "The instance type for the EC2 instances."
  type        = string
  default     = "t3.micro"
}

variable "primary_key_name" {
  description = "The name of the key pair for the primary VPC."
  type        = string
  default     = "vpc-peering-demo"
}

variable "secondary_key_name" {
  description = "The name of the key pair for the secondary VPC."
  type        = string
  default     = "vpc-peering-demo-two"
}