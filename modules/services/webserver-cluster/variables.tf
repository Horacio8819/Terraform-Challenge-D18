variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "public_subnets" {
  description = "Map of public subnet CIDR blocks by AZ suffix"
  type        = map(string)

  default = {
    a = "172.31.115.0/24"
    b = "172.31.116.0/24"
    c = "172.31.117.0/24"
  }
}

variable "key_name" {
    default = "WebServerKeyPair"
}

variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type        = string
}

variable "server_template_version" {
  description = "EC2 instance type for the cluster"
  type        = string
}

# variable "min_size" {
#   description = "Minimum number of EC2 instances in the ASG"
#   type        = number
# }

# variable "max_size" {
#   description = "Maximum number of EC2 instances in the ASG"
#   type        = number
# }

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "team_name" {
  description = "The name of the team responsible for this cluster"
  type        = string
}

# variable "custom_tags" {
#   description = "Custom tags to set on the Instances in the ASG"
#   type        = map(string)
#   default     = {}
# }


variable "enable_autoscaling" {
  description = "If set to true, enable auto scaling"
  type        = bool
  default = true
}

variable "environment" {
  type    = string
  description = "The environment to deploy to (e.g. dev, staging, production)"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch detailed monitoring (incurs additional cost)"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "create_dns_record" {
  description = "Whether to create a Route53 DNS record for the ALB"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "FQDN for Route53 when create_dns_record is true."
  type        = string
  default     = ""

  validation {
    condition     = !var.create_dns_record || length(trimspace(var.domain_name)) > 0
    error_message = "domain_name is required when create_dns_record is true."
  }
}

variable "route53_zone_name" {
  description = "Hosted zone name for Route53 lookup (e.g. example.com)."
  type        = string
  default     = ""

  validation {
    condition     = !var.create_dns_record || length(trimspace(var.route53_zone_name)) > 0
    error_message = "route53_zone_name is required when create_dns_record is true."
  }
}