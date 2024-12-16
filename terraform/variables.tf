variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "source_bucket" {
  description = "Source bucket name"
}

variable "destination_bucket" {
  description = "Destination bucket name"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
}

variable "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  default     = "s3-object-modification"
}

variable "eventbridge_description" {
  description = "Description of the EventBridge rule"
  default     = "Triggers on new versions of specific files in the source bucket"
}
