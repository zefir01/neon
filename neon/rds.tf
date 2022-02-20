resource "aws_security_group" "rds_sg" {
  name_prefix = "rds_sg"
  vpc_id      = var.vpc_id
  tags        = {
    Name = "RDS sg"
  }

}
locals {
  all_cidr = "0.0.0.0/0"
}
resource "aws_security_group_rule" "rds_sg_allow_all" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = [local.all_cidr]
}
resource "aws_security_group_rule" "rds_sg_allow_egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [local.all_cidr]
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "neon"

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "14.1"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.micro"

  allocated_storage     = 10
  max_allocated_storage = 20

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "neon"
  username = "neon_proxy"
  port     = 5432

  multi_az               = true
  db_subnet_group_name   = var.db_subnet_group
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60
  monitoring_role_name                  = "example-monitoring-role-name"
  monitoring_role_description           = "Description for monitoring role"

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  //tags = local.tags
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
}


