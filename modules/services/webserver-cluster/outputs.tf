output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.app_asg.name
  description = "The name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  description = "The security group ID of the ALB"
  value       = aws_security_group.alb_sg.id
}

output "instance_security_group_id" {
  description = "The security group ID of the EC2 instances"
  value       = aws_security_group.ec2_sg.id
}