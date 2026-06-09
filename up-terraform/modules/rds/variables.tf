variable "environment" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_id" {}
variable "subnet_id_b" {}
variable "db_instance_class" { default = "db.t3.micro" }
variable "allocated_storage" { default = 20 }
variable "db_name" {}
variable "db_username" {}
variable "db_password" { sensitive = true }
