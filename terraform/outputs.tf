output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "IDs of the two subnets."
  value       = module.network.subnet_ids
}

output "security_group_id" {
  description = "ID of the shared security group."
  value       = module.network.security_group_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = module.platform.ecr_repository_url
}

output "log_group_name" {
  description = "Name of the CloudWatch log group."
  value       = module.platform.log_group_name
}

output "artifacts_bucket" {
  description = "Name of the S3 artifacts bucket."
  value       = module.platform.artifacts_bucket
}

output "lambda_role_arn" {
  description = "ARN of the IAM role assumed by the Lambda."
  value       = module.platform.lambda_role_arn
}

output "lambda_function_name" {
  description = "Name of the deployable sample Lambda function."
  value       = module.platform.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployable sample Lambda function."
  value       = module.platform.lambda_function_arn
}
