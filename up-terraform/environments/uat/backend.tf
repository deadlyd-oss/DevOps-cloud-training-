terraform {
  backend "s3" {
    bucket         = "up-uat-assets-dk"
    key            = "uat/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "up-terraform-state-lock"
    encrypt        = true
  }
}
