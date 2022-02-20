resource "aws_security_group" "ep_sg" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "default_rule_ingress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ep_sg.id
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "default_rule_egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ep_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_availability_zones" "zones" {}
locals {
  azs = [sort(data.aws_availability_zones.zones.names)[0], sort(data.aws_availability_zones.zones.names)[1]]
}

module "vpc" {
  version            = "3.0.0"
  source             = "terraform-aws-modules/vpc/aws"
  #  source             = "../.terraform/modules/eks.vpc"
  name               = "main"
  azs                = local.azs
  cidr               = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true

  # Amazon ECS tasks using the Fargate launch type and platform version 1.3.0 or earlier only require
  # the com.amazonaws.region.ecr.dkr Amazon ECR VPC endpoint and the Amazon S3 gateway endpoints.
  #
  # Amazon ECS tasks using the Fargate launch type and platform version 1.4.0 or later require both
  # the com.amazonaws.region.ecr.dkr and com.amazonaws.region.ecr.api Amazon ECR VPC endpoints and
  # the Amazon S3 gateway endpoints.
  #
  # For more details, please visit the https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html

  # enable dns support
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags  = tomap({
    "kubernetes.io/cluster/${var.cluster_name}" = "shared", "kubernetes.io/role/elb" = "1"
  })
  private_subnet_tags = tomap({
    "kubernetes.io/cluster/${var.cluster_name}" = "shared", "kubernetes.io/role/internal-elb" = "1"
  })
  create_database_subnet_group = true
  database_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.0.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.ep_sg.id]

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint" }
    },
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    lambda = {
      service             = "lambda"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ecs_telemetry = {
      service             = "ecs-telemetry"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      //policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      //policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
    },
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    codedeploy = {
      service             = "codedeploy"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    codedeploy_commands_secure = {
      service             = "codedeploy-commands-secure"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    elasticloadbalancing = {
      service             = "elasticloadbalancing"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    autoscaling = {
      service             = "autoscaling"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    appmesh-envoy-management = {
      service             = "appmesh-envoy-management"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

output "public_subnets" {
  value = module.vpc.public_subnets
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
output "database_subnets" {
  value = module.vpc.database_subnets
}
output "vpc_id" {
  value = module.vpc.vpc_id
}