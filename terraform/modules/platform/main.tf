# ECR repository — where the sample service image would be pushed.
# ECR is a LocalStack Pro feature, so it is gated off by default; it (and the
# Lambda below) apply against real AWS or LocalStack Pro. The network / IAM /
# S3 / CloudWatch resources are all LocalStack Community-supported and always on.
resource "aws_ecr_repository" "this" {
  count                = var.enable_pro_features ? 1 : 0
  name                 = "${var.project}-svc"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name    = "${var.project}-svc"
    Project = var.project
  }
}

# CloudWatch log group for the Lambda / service logs.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/${var.project}/app"
  retention_in_days = var.log_retention_days

  tags = {
    Project = var.project
  }
}

# S3 bucket for build/deploy artifacts.
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-artifacts"
  force_destroy = true

  tags = {
    Name    = "${var.project}-artifacts"
    Project = var.project
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role the Lambda assumes.
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Project = var.project
  }
}

# Minimal permissions: write to the log group.
data "aws_iam_policy_document" "lambda_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "${var.project}-lambda-logs"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

# Package the trivial handler into a zip at plan time.
data "archive_file" "lambda" {
  count       = var.enable_pro_features ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/build/lambda.zip"
}

# The deployable sample workload.
resource "aws_lambda_function" "sample" {
  count            = var.enable_pro_features ? 1 : 0
  function_name    = "${var.project}-sample"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda[0].output_path
  source_code_hash = data.archive_file.lambda[0].output_base64sha256
  timeout          = 10

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      PROJECT = var.project
    }
  }

  tags = {
    Project = var.project
  }

  depends_on = [aws_iam_role_policy.lambda_logs]
}
