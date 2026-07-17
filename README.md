# Static Website Hosting with S3 and CloudFront

Terraform configuration that provisions a static website on AWS using a
private S3 bucket as the origin and CloudFront as the CDN, with access
locked down via Origin Access Control (OAC) — no public S3 access required.

See [ARCHITECTURE.md](ARCHITECTURE.md) for a diagram and design notes.

## Features

- Private S3 bucket (all public access blocked) for website content
- CloudFront distribution with Origin Access Control (OAC) as the only
  path to the bucket
- HTTPS enforced via `redirect-to-https`
- Site content (`www/`) uploaded to S3 automatically via Terraform,
  with content types inferred from file extension
- Remote state stored in S3

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- An AWS account and credentials configured (e.g. via `aws configure` or
  environment variables)
- An existing S3 bucket for Terraform remote state (see `backend.tf`)

## Usage

```bash
terraform init
terraform plan
terraform apply
```

After apply, the website is available at the `website_url` output
(the CloudFront domain).

To update the site content, edit the files under `www/` and re-run
`terraform apply` — changed files are re-uploaded automatically (tracked
via MD5 hash).

To tear everything down:

```bash
terraform destroy
```

## Project Structure

```
.
├── main.tf          # S3 bucket, bucket policy, OAC, CloudFront distribution, site uploads
├── variables.tf      # Input variables
├── outputs.tf         # Output values (bucket name, CloudFront domain, website URL)
├── providers.tf       # AWS provider and default tags
├── backend.tf          # Remote state backend (S3) and required providers
├── local.tf             # Local values
├── terraform.tfvars      # Variable values (not committed)
├── www/                    # Static site content (HTML/CSS/JS)
└── ARCHITECTURE.md          # Architecture overview and diagram
```

## Configuration

| Variable      | Description                              | Default                        |
|---------------|-------------------------------------------|---------------------------------|
| `bucket_name` | Name of the S3 bucket for the website      | `shaurya-static-website-bucket` |

Override defaults via `terraform.tfvars` or `-var` flags.

## Notes

- The S3 bucket is fully private; CloudFront reaches it only through the
  Origin Access Control, enforced by the bucket policy's `AWS:SourceArn`
  condition.
- `terraform.tfvars` and Terraform state/lock files are excluded from
  version control (see `.gitignore`).
