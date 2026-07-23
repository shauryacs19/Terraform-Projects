output "primary_tgw_id" {
  description = "Transit Gateway ID in the primary region"
  value       = aws_ec2_transit_gateway.primary_tgw.id
}

output "secondary_tgw_id" {
  description = "Transit Gateway ID in the secondary region"
  value       = aws_ec2_transit_gateway.secondary_tgw.id
}

output "tgw_peering_attachment_id" {
  description = "Cross-region Transit Gateway peering attachment ID"
  value       = aws_ec2_transit_gateway_peering_attachment.tgw_peer.id
}

output "primary_vpc_id" {
  description = "Primary VPC ID"
  value       = aws_vpc.primary_vpc.id
}

output "secondary_vpc_id" {
  description = "Secondary VPC ID"
  value       = aws_vpc.secondary_vpc.id
}

output "primary_instance_private_ip" {
  description = "Private IP of the primary instance"
  value       = aws_instance.primary_instance.private_ip
}

output "primary_instance_public_ip" {
  description = "Public IP of the primary instance (for SSH)"
  value       = aws_instance.primary_instance.public_ip
}

output "secondary_instance_private_ip" {
  description = "Private IP of the secondary instance"
  value       = aws_instance.secondary_instance.private_ip
}

output "secondary_instance_public_ip" {
  description = "Public IP of the secondary instance (for SSH)"
  value       = aws_instance.secondary_instance.public_ip
}
