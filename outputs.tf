output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the static website"
  value       = aws_s3_bucket.static_website_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket hosting the static website"
  value       = aws_s3_bucket.static_website_bucket.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "website_url" {
  description = "URL of the static website"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}
