provider "aws" {
  region = "eu-central-1"
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
module "webserver_cluster" {
  source =  "../../../../modules/services/webserver-cluster"
  cluster_name  = "webservers-dev"
  environment = var.environment
 create_dns_record = var.create_dns_record
  domain_name = var.domain_name
  route53_zone_name = var.route53_zone_name
  project_name = var.project_name
  team_name = var.team_name
  alert_email = var.alert_email
  server_template_version = var.server_template_version
  public_subnets = {
    a = "172.31.105.0/24"
    b = "172.31.106.0/24"
    c = "172.31.107.0/24"
  }
}
output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}
