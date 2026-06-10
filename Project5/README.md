# Project 5 - EKS Observability

## Components Deployed
- CloudWatch Container Insights (all 5 log types)
- CloudWatch Dashboard: UP-EKS-Observability
  - Pod CPU Usage
  - Pod Memory Usage  
  - Pod Restarts
- SNS Topic: up-eks-alerts -> urbanpoison19@gmail.com
- CloudWatch Alarm: up-eks-pod-restart-alert
- CloudTrail: up-eks-cloudtrail -> s3://up-eks-cloudtrail-dk
- Pod self-healing demonstrated

## Evidence
- Container Insights daemonsets deployed
- SNS subscription confirmed
- Dashboard created in us-west-2
- Pod deletion and auto-recovery captured
