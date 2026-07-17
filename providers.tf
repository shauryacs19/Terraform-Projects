provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
        Project     = "Static Website Hosting"
        Environment = "production"
        managed_by   = "Terraform"
    }
  }
}