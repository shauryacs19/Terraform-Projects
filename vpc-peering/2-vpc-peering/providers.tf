provider "aws" {
  region = "ap-south-1"
  alias = "primary"
}

provider "aws" {
  region = "ap-south-2"
  alias = "secondary"
}