output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = try(aws_ecr_repository.this[0].repository_url, null)
}

output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = try(aws_ecr_repository.this[0].name, null)
}

output "log_group_name" {
  description = "Name of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "artifacts_bucket" {
  description = "Name of the S3 artifacts bucket."
  value       = aws_s3_bucket.artifacts.bucket
}

output "lambda_role_arn" {
  description = "ARN of the IAM role assumed by the Lambda."
  value       = aws_iam_role.lambda.arn
}

output "lambda_function_name" {
  description = "Name of the sample Lambda function."
  value       = try(aws_lambda_function.sample[0].function_name, null)
}

output "lambda_function_arn" {
  description = "ARN of the sample Lambda function."
  value       = try(aws_lambda_function.sample[0].arn, null)
}
