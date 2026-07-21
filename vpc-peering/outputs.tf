output "primary_instance_private_ip" {
  description = "Private IP of the primary instance"
  value       = aws_instance.primary_instance.private_ip
}

output "primary_instance_public_ip" {
  description = "Public IP of the primary instance"
  value       = aws_instance.primary_instance.public_ip
}

output "secondary_instance_private_ip" {
  description = "Private IP of the secondary instance"
  value       = aws_instance.secondary_instance.private_ip
}

output "secondary_instance_public_ip" {
  description = "Public IP of the secondary instance"
  value       = aws_instance.secondary_instance.public_ip
}
