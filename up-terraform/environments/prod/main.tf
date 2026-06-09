terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "up-prod-state-dk"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "up-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "prod" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "UP-Prod-VPC", Environment = "Production", Client = "UP" }
}

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
  tags = { Name = "UP-Prod-Public-1a", Environment = "Production" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.2.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
  tags = { Name = "UP-Prod-Public-1b", Environment = "Production" }
}

resource "aws_subnet" "private_app_1a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.2.3.0/24"
  availability_zone = "us-west-2a"
  tags = { Name = "UP-Prod-Private-App-1a", Environment = "Production" }
}

resource "aws_subnet" "private_app_1b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.2.4.0/24"
  availability_zone = "us-west-2b"
  tags = { Name = "UP-Prod-Private-App-1b", Environment = "Production" }
}

resource "aws_subnet" "private_db_1a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.2.5.0/24"
  availability_zone = "us-west-2a"
  tags = { Name = "UP-Prod-Private-DB-1a", Environment = "Production" }
}

resource "aws_subnet" "private_db_1b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.2.6.0/24"
  availability_zone = "us-west-2b"
  tags = { Name = "UP-Prod-Private-DB-1b", Environment = "Production" }
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "UP-Prod-IGW", Environment = "Production" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }
  tags = { Name = "UP-Prod-Public-RT", Environment = "Production" }
}

resource "aws_route_table_association" "pub_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb_sg" {
  name   = "UP-Prod-ALB-SG"
  vpc_id = aws_vpc.prod.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "UP-Prod-ALB-SG", Environment = "Production" }
}

resource "aws_security_group" "ec2_sg" {
  name   = "UP-Prod-EC2-SG"
  vpc_id = aws_vpc.prod.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "UP-Prod-EC2-SG", Environment = "Production" }
}

resource "aws_security_group" "rds_sg" {
  name   = "UP-Prod-RDS-SG"
  vpc_id = aws_vpc.prod.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "UP-Prod-RDS-SG", Environment = "Production" }
}

resource "aws_launch_template" "prod" {
  name_prefix            = "UP-Prod-LT-"
  image_id               = "ami-0c2d06d50ce30b442"
  instance_type          = "t3.large"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "UP-Prod-Web", Environment = "Production", Client = "UP" }
  }
}

resource "aws_autoscaling_group" "prod" {
  name                = "UP-Prod-ASG"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 6
  vpc_zone_identifier = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]
  launch_template {
    id      = aws_launch_template.prod.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "UP-Prod-Web"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
  tag {
    key                 = "Client"
    value               = "UP"
    propagate_at_launch = true
  }
}

resource "aws_db_subnet_group" "prod" {
  name       = "up-prod-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_1a.id, aws_subnet.private_db_1b.id]
  tags = { Name = "UP-Prod-DB-Subnet-Group", Environment = "Production" }
}

resource "aws_db_instance" "prod" {
  identifier             = "up-prod-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 50
  storage_encrypted      = true
  multi_az               = true
  username               = "admin"
  password               = "Admin12345678"
  db_subnet_group_name   = aws_db_subnet_group.prod.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  tags = { Name = "UP-Prod-RDS", Environment = "Production", Client = "UP" }
}

output "vpc_id" { value = aws_vpc.prod.id }
output "asg_name" { value = aws_autoscaling_group.prod.name }
output "rds_endpoint" { value = aws_db_instance.prod.endpoint }
