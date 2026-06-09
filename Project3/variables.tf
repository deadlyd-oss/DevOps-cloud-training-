variable "aws_region" {
  default = "us-west-2"
}

variable "vpc_id" {
  default = "vpc-02554214aad9fbe83"
}

variable "public_subnets" {
  default = ["subnet-0ade5a5ee8c79f6f0", "subnet-07685a36ce8e04ad9"]
}

variable "ecr_image" {
  default = "783490810970.dkr.ecr.us-west-2.amazonaws.com/up-app:latest"
}

variable "app_name" {
  default = "up-app"
}

variable "account_id" {
  default = "783490810970"
}
