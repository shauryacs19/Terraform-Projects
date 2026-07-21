# Terraform Projects

A collection of hands-on AWS infrastructure projects built with Terraform.
Each project lives in its own folder with its own documentation.

## Projects

| Project | Description |
|---|---|
| [static-website-hosting-s3-cloudfront](static-website-hosting-s3-cloudfront/) | Static website hosted on a private S3 bucket, served globally over HTTPS via CloudFront with Origin Access Control. |
| [vpc-peering](vpc-peering/) | Two VPCs in different AWS regions (Mumbai & Hyderabad) connected privately with a cross-region VPC peering connection, verified with live traffic between EC2 instances over private IPs. |

## Conventions

- Each project manages its own remote Terraform state in S3.
- Secrets and generated files (`*.pem`, `terraform.tfvars`, state, `.terraform/`)
  are git-ignored per project — never committed.
- Every project includes a `terraform.tfvars.example` and a detailed `README.md`.
