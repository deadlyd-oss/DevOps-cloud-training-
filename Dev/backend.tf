terraform {
  backend "s3" {
    bucket = "up-dev-assets-[your-initials]"
    key    = "dev/terraform.tfstate"
    region = "us-west-2"
  }
}