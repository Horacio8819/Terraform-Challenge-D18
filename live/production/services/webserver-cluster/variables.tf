variable "environment" {
  type    = string
  description = "The environment to deploy to (e.g. dev, staging, production)"
  default = "dev"
}
variable "create_dns_record" {
  description = "Whether to create a Route53 DNS record for the ALB"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "FQDN for Route53 when create_dns_record is true."
  type        = string
  default     = "dev-horacio-app.example.com"

  validation {
    condition     = !var.create_dns_record || length(trimspace(var.domain_name)) > 0
    error_message = "domain_name is required when create_dns_record is true."
  }
}

variable "route53_zone_name" {
  description = "Hosted zone name for Route53 lookup (e.g. example.com)."
  type        = string
  default     = "dev-api.example.com"

  validation {
    condition     = !var.create_dns_record || length(trimspace(var.route53_zone_name)) > 0
    error_message = "route53_zone_name is required when create_dns_record is true."
  }
}


variable "project_name" {
  description = "The name of the project"
  type        = string
  default = "dev-grade-deployment"
}

variable "team_name" {
  description = "The name of the team responsible for this cluster"
  type        = string
  default = "dev Team"
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default = "horace.djousse@yahoo.com"
  sensitive = true
}

variable "server_template_version" {
  description = "EC2 instance type for the cluster"
  type        = string
  default = "v0.0.3"
}