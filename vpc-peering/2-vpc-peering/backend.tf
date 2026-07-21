terraform{
    backend "s3" {
        bucket = "shaurya-terraform-state-bucket"
        key    = "vpc-peering/terraform.tfstate"
        region = "ap-south-1"
        encrypt = true
    }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}