variables {
  cluster_name  = "test-cluster"
  environment = "dev"
  create_dns_record = false
  project_name = "devops-project"
  team_name = "devOps"
  alert_email = "horace.djousse@yahoo.com"
  server_template_version = "latest"
  public_subnets = {
    a = "172.31.105.0/24"
    b = "172.31.106.0/24"
    c = "172.31.107.0/24"
  }
}



run "validate_cluster_name" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.app_asg.name_prefix == "test-cluster-asg"
    error_message = "ASG name prefix must match the cluster_name variable"
  }
}

run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_template.app_lt.instance_type == "t3.micro"
    error_message = "Instance type must match the instance_type variable"
  }
}


run "validate_security_group_port" {
  command = apply

  assert {
    condition = anytrue([
      for rule in aws_security_group.ec2_sg.ingress :
      rule.from_port == (
        var.environment == "production" ? 3050 :
        (var.environment == "staging" ? 3040 : 3030)
      )
    ])

    error_message = "Security group must allow correct port based on environment"
  }
}