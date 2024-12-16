terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket
  acl    = "private"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = var.destination_bucket
  acl    = "private"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}../app"  # Path to your Lambda function directory
  output_path = "${path.module}../app/replicate_files.zip"  # Output path for the zip file
}

resource "aws_lambda_function" "replicate_files" {
  function_name = var.lambda_name
  runtime       = "python3.9"
  handler       = "replicate_files.handler"
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      SOURCE_BUCKET      = var.source_bucket
      DESTINATION_BUCKET = var.destination_bucket
    }
  }

  role = aws_iam_role.lambda_role.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_eventbridge_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name   = "lambda-s3-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            "arn:aws:s3:::${var.source_bucket}/*",
            "arn:aws:s3:::${var.destination_bucket}/*"
          ]
        }
      ]
    })
  }
}

resource "aws_cloudwatch_event_rule" "s3_eventbridge_rule" {
  name        = var.eventbridge_rule_name
  description = var.eventbridge_description

  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created", "Object Updated"],
    "detail": {
      "bucket": {
        "name": [var.source_bucket]
      },
      "object": {
        "key": ["users.json", "dashboards.json"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "eventbridge_to_lambda" {
  rule      = aws_cloudwatch_event_rule.s3_eventbridge_rule.name
  target_id = "replicate-files-lambda"
  arn       = aws_lambda_function.replicate_files.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.replicate_files.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_eventbridge_rule.arn
}
