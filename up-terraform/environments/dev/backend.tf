terraform {
  backend "s3" {
    bucket         = "up-dev-assets-dk"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "up-terraform-state-lock"
    encrypt        = true
  }
}
