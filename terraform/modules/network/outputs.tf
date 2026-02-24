output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "IDs of the created subnets."
  value       = aws_subnet.this[*].id
}

output "security_group_id" {
  description = "ID of the shared security group."
  value       = aws_security_group.this.id
}
