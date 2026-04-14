provider "aws" {
  region = var.aws_region
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
data "aws_vpc" "default" {
  default = true
}
data "aws_availability_zones" "all" {}
resource "aws_subnet" "public" {
  for_each = var.public_subnets
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = each.value
  availability_zone       = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.cluster_name}-public-${each.key}"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]

  is_production = var.environment == "production"
  is_staging    = var.environment == "staging"
  is_dev        = var.environment == "dev"

  instance_type    = local.is_production ? "t3.small" : (local.is_staging ? "t3.small" : "t3.micro")
  min_cluster_size = local.is_production ? 4 :( local.is_staging ? 3 : 2)
  max_cluster_size = local.is_production ? 10 :( local.is_staging ? 6 : 4)
  server_port      = local.is_production ? 3050 : ( local.is_staging ? 3040 : 3030)
  
  enable_autoscaling = !local.is_dev
  enable_monitoring  = local.is_production
  deletion_policy    = local.is_production ? "Retain" : "Delete"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }

  merged_tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-instance"
    }
  )

}


# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }
  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips
  }
  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
}

# EC2 Instance Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "${var.cluster_name}-instance-sg"
  description = "Allow traffic from ALB only"
  ingress {
    from_port       = local.server_port
    to_port         = local.server_port
    protocol        = local.tcp_protocol
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips
  }
  tags = {
    Name = "${var.cluster_name}-instance-sg"
  }
}

# Launch Template (your Node.js bootstrap included)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(
    templatefile("${path.module}/user_data.sh.tpl", {
      cluster_name = var.cluster_name,
      server_port = local.server_port
      server_template_version = var.server_template_version
    })
  )

  lifecycle {
    create_before_destroy = true
  }
  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-instance"
  })
  }
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [for s in aws_subnet.public : s.id]

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-instance"
  })
    
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.cluster_name}-tg"
  port     = local.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-instance"
  })
  
  
}
# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Auto Scaling Group (Cluster Core)
resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "${var.cluster_name}-asg"
  desired_capacity    = local.min_cluster_size
  min_size            = local.min_cluster_size
  max_size            = local.max_cluster_size
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  lifecycle {
   create_before_destroy = true
  }

  dynamic "tag" {
    for_each = local.merged_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  
}


resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}


resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  count = var.enable_detailed_monitoring ? 1 : 0
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
  alarm_name  = "${var.cluster_name}-high-cpu-utilization"
  alarm_description   = "CPU utilization exceeded 80%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 120
  statistic           = "Average"
  threshold           = 80
  unit                = "Percent"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# SNS Topic (notification channel)
resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"
}

# Optional: Email subscription
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_route53_zone" "primary" {
  count = var.create_dns_record ? 1 : 0
  name = var.route53_zone_name
}

resource "aws_route53_record" "alb_route53_record" {
  count = var.create_dns_record ? 1 : 0
  zone_id = aws_route53_zone.primary[0].zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}