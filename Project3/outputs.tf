output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.up_alb.dns_name
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.up_cluster.name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.up_service.name
}
