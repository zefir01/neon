## managed kubernetes cluster

data "aws_partition" "current" {}

## control plane (cp)
# security/policy
resource "aws_iam_role" "cp" {
  name = format("%s-cp", local.name)
  tags = merge(local.default-tags, var.tags)
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = format("eks.%s", data.aws_partition.current.dns_suffix)
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-cluster" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKSClusterPolicy", data.aws_partition.current.partition)
  role       = aws_iam_role.cp.id
}

resource "aws_iam_role_policy_attachment" "eks-service" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKSServicePolicy", data.aws_partition.current.partition)
  role       = aws_iam_role.cp.id
}

resource "aws_eks_cluster" "cp" {
  name     = format("%s", local.name)
  role_arn = aws_iam_role.cp.arn
  version  = var.kubernetes_version
  tags     = merge(local.default-tags, var.tags)

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids = var.subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster,
    aws_iam_role_policy_attachment.eks-service,
  ]
}

## node groups (ng)
# security/policy
resource "aws_iam_role" "ng" {
  name  = format("%s-ng", local.name)
  tags  = merge(local.default-tags, var.tags)
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = [format("ec2.%s", data.aws_partition.current.dns_suffix)]
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks-ng" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKSWorkerNodePolicy", data.aws_partition.current.partition)
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "eks-cni" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKS_CNI_Policy", data.aws_partition.current.partition)
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ecr-full" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", data.aws_partition.current.partition)
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ecr-read" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", data.aws_partition.current.partition)
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ssm-managed" {
  policy_arn = format("arn:%s:iam::aws:policy/AmazonSSMManagedInstanceCore", data.aws_partition.current.partition)
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = { for key, val in var.policy_arns : key => val }
  policy_arn = each.value
  role       = aws_iam_role.ng.name
}

## managed node groups

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "mng" {
  base64_encode = true
  gzip          = false

  # Main cloud-config configuration file.
  part {
    content_type = "text/x-shellscript"
    content      = <<-EOT
    #!/bin/bash
    ${var.enable_ssm ? "yum install -y amazon-ssm-agent\nsystemctl enable amazon-ssm-agent\nsystemctl start amazon-ssm-agent" : ""}
    EOT
  }
}

resource "aws_launch_template" "mng" {
  name      = format("eks-%s", uuid())
  tags      = merge(local.default-tags, local.eks-tag, var.tags)
  user_data = data.template_cloudinit_config.mng.rendered

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = "20"
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.eks-owned-tag, var.tags)
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
}

resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.cp.name
  //node_group_name = aws_eks_cluster.cp.name
  node_role_arn   = aws_iam_role.ng.arn
  subnet_ids      = var.subnets
  ami_type        = "AL2_x86_64" # available values ["AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64"]
  instance_types  = [var.managed_node_group.instance_type]
  version         = aws_eks_cluster.cp.version
  tags            = merge(local.default-tags, var.tags)
  node_group_name_prefix = aws_eks_cluster.cp.name

  scaling_config {
    max_size     = var.managed_node_group.max_size
    min_size     = var.managed_node_group.min_size
    desired_size = var.managed_node_group.desired_size
  }

  launch_template {
    id      = aws_launch_template.mng.id
    version = aws_launch_template.mng.latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role.ng,
    aws_iam_role_policy_attachment.eks-ng,
    aws_iam_role_policy_attachment.eks-cni,
    aws_iam_role_policy_attachment.ecr-full,
  ]
}


