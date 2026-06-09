provider "aws" {
  region = var.aws_region
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "up_app" {
  name              = "/ecs/up-app"
  retention_in_days = 7
}

# IAM Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "up-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "up-alb-sg"
  description = "Allow HTTP inbound"
  vpc_id      = var.vpc_id

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
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_sg" {
  name        = "up-ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = var.vpc_id

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
}

# ALB
resource "aws_lb" "up_alb" {
  name               = "up-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
}

# Target Group
resource "aws_lb_target_group" "up_tg" {
  name        = "up-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.up_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.up_tg.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "up_cluster" {
  name = "up-app-cluster-prod"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "up_task" {
  family                   = "up-app-task-prod"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "up-app"
    image = var.ecr_image
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/up-app"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ECS Service
resource "aws_ecs_service" "up_service" {
  name            = "up-app-service-prod"
  cluster         = aws_ecs_cluster.up_cluster.id
  task_definition = aws_ecs_task_definition.up_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.up_tg.arn
    container_name   = "up-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/up-app-cluster-prod/up-app-service-prod"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.up_service]
}

# Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "up-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
