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

variable "tertiary" {
  description = "The AWS region where the resources will be created."
  type        = string
  default     = "ap-southeast-1"
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

variable "tertiary_vpc_cidr" {
  description = "The CIDR block for the tertiary VPC."
  type        = string
  default     = "10.2.0.0/16"
}

variable "instance_type" {
  description = "The instance type for the EC2 instances."
  type        = string
  default     = "t3.micro"
}

# Least privilege: one key pair per region (distinct key material each).
variable "primary_key_name" {
  description = "Key pair name for the primary region."
  type        = string
  default     = "vpc-peering-primary"
}

variable "secondary_key_name" {
  description = "Key pair name for the secondary region."
  type        = string
  default     = "vpc-peering-secondary"
}

variable "tertiary_key_name" {
  description = "Key pair name for the tertiary region."
  type        = string
  default     = "vpc-peering-tertiary"
}

variable "primary_public_key_path" {
  description = "Path to the SSH public key for the primary region."
  type        = string
  default     = "keys/primary.pub"
}

variable "secondary_public_key_path" {
  description = "Path to the SSH public key for the secondary region."
  type        = string
  default     = "keys/secondary.pub"
}

variable "tertiary_public_key_path" {
  description = "Path to the SSH public key for the tertiary region."
  type        = string
  default     = "keys/tertiary.pub"
}