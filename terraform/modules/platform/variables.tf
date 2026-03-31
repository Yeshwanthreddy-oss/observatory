variable "project" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the CloudWatch log group, in days."
  type        = number
  default     = 14
}

variable "vpc_id" {
  description = "VPC the Lambda is associated with (informational tag)."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs the Lambda's VPC config attaches to."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs applied to the Lambda's VPC config."
  type        = list(string)
}

variable "enable_pro_features" {
  description = "Provision ECR + Lambda (LocalStack Pro / real AWS only)."
  type        = bool
  default     = false
}
