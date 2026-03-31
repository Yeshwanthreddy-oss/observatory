variable "aws_region" {
  description = "AWS region reported to the LocalStack-emulated services."
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint that every AWS service is routed to."
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  description = "Name prefix applied to every provisioned resource."
  type        = string
  default     = "observatory"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for the two subnets (must be within vpc_cidr)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "log_retention_days" {
  description = "Retention for the CloudWatch log group, in days."
  type        = number
  default     = 14
}
