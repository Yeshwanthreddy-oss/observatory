# Two AZs spread across whatever region the provider is emulating.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project}-vpc"
    Project = var.project
  }
}

resource "aws_subnet" "this" {
  count = length(var.subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "${var.project}-subnet-${count.index + 1}"
    Project = var.project
  }
}

# A minimal security group: allow all egress, no ingress by default.
resource "aws_security_group" "this" {
  name        = "${var.project}-sg"
  description = "Shared security group for ${var.project} workloads"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-sg"
    Project = var.project
  }
}
