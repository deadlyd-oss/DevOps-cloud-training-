provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "../../modules/vpc"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  region             = var.region
}

module "ec2" {
  source        = "../../modules/ec2"
  environment   = var.environment
  ami_id        = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id
  vpc_id        = module.vpc.vpc_id
}

module "rds" {
  source            = "../../modules/rds"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  subnet_id         = module.vpc.public_subnet_id
  subnet_id_b       = module.vpc.public_subnet_id_b
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_instance_class = "db.t3.small"
  allocated_storage = 50
}

output "vpc_id" { value = module.vpc.vpc_id }
output "ec2_public_ip" { value = module.ec2.public_ip }
output "rds_endpoint" { value = module.rds.db_endpoint }
