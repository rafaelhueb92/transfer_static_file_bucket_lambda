data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
    source_bucket = "${var.source_bucket}-${local.account_id}"
    destination_bucket = "${var.destination_bucket}-${local.account_id}"
}