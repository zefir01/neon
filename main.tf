terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

locals {
  cluster_name = "eks-neon"
}

module "vpc" {
  source       = "./vpc"
  cluster_name = local.cluster_name
}

module "eks" {
  source = "./eks"
  name   = local.cluster_name
  tags   = {
    env  = "dev"
    test = "tc1"
  }
  kubernetes_version = "1.19"
  managed_node_group = {
    name          = "default"
    min_size      = 1
    max_size      = 3
    desired_size  = 2
    instance_type = "t3.small"
  }
  subnets = module.vpc.private_subnets
}

#module "jenkins" {
#  source = "./Jenkins"
#  subnet = module.vpc.public_subnets[0]
#  vpc_id = module.vpc.vpc_id
#}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "root1"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  filename        = "${path.module}/private.key"
  content         = tls_private_key.private_key.private_key_pem
  file_permission = "0400"
}
resource "local_file" "ssh_public_key" {
  filename        = "${path.module}/public.key"
  content         = aws_key_pair.generated_key.public_key
  file_permission = "0400"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_host
    token                  = module.eks.cluster_token
    cluster_ca_certificate = module.eks.cluster_ca_certificate
  }
}

module "neon" {
  source              = "./neon"
  db_subnet_group     = module.vpc.db_subnet_group
  private_subnet_ids  = module.vpc.private_subnets
  public_subnet_ids   = module.vpc.public_subnets
  database_subnet_ids = module.vpc.database_subnets
  ssh_key_name        = aws_key_pair.generated_key.key_name
  vpc_id              = module.vpc.vpc_id
  ssh_private_key     = tls_private_key.private_key.private_key_pem
  depends_on          = [module.vpc, module.eks, local_file.ssh_private_key, local_file.ssh_public_key]
  providers           = {
    helm = helm
  }
}

output "grafana_ip" {
  value = module.neon.grafana_ip
}

