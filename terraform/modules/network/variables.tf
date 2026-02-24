variable "project" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "subnet_cidrs" {
  description = "CIDR blocks for the two subnets."
  type        = list(string)

  validation {
    condition     = length(var.subnet_cidrs) == 2
    error_message = "Exactly two subnet CIDRs are required."
  }
}
