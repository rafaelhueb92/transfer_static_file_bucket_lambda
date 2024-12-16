# AWS Lambda and Terraform Project

This project replicates specific files between S3 buckets using an AWS Lambda function and infrastructure managed by Terraform.

## Project Structure
- `.github/workflows`: GitHub Actions workflow for CI/CD.
- `app`: Contains the Lambda function code.
- `terraform`: Terraform configuration for deploying AWS infrastructure.

## Usage
1. Set up AWS credentials.
2. Deploy the infrastructure using Terraform.
3. Modify the source files in the source bucket to trigger replication.
