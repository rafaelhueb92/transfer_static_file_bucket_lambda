terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.44.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = local.source_bucket
  acl    = "private"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = local.destination_bucket

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

}

resource "aws_s3_bucket_public_access_block" "destination_bucket_block" {
  bucket                  = aws_s3_bucket.destination_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "destination_bucket_policy" {
  bucket = aws_s3_bucket.destination_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.destination_bucket.arn}/*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app"  
  output_path = "${path.module}/../app/replicate_files.zip"  
}

resource "aws_lambda_function" "replicate_files" {
  function_name = var.lambda_name
  runtime       = "python3.9"
  handler       = "replicate_files.handler"
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      SOURCE_BUCKET      = local.source_bucket
      DESTINATION_BUCKET = local.destination_bucket
      DESTINATION_PREFIX = "assets/" 
    }
  }

  role = aws_iam_role.lambda_role.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_${var.lambda_name}_eventbridge_role"

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
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::${local.source_bucket}/*",
            "arn:aws:s3:::${local.destination_bucket}/assets/*"
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
        "name": [local.source_bucket]
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

resource "aws_lambda_permission" "s3_invoke_permission_destination" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.replicate_files.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.destination_bucket.arn
}

# S3 Event Notification for Object Deleted in Destination Bucket
resource "aws_s3_bucket_notification" "destination_bucket_notification" {
  bucket = aws_s3_bucket.destination_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.replicate_files.arn
    events              = ["s3:ObjectRemoved:Delete"]
    filter_prefix       = "assets/"                 # Monitor files in the 'assets/' path
    filter_suffix       = ".json"                  # Focus only on JSON files
  }

  depends_on = [aws_lambda_permission.s3_invoke_permission_destination]

}
