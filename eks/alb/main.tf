locals {
  aws_alb_ingress_controller_docker_image = "docker.io/amazon/aws-alb-ingress-controller:v${var.aws_alb_ingress_controller_version}"
  aws_alb_ingress_controller_version      = var.aws_alb_ingress_controller_version
  aws_alb_ingress_class                   = "alb"
  aws_vpc_id                              = data.aws_vpc.selected.id
  aws_region_name                         = data.aws_region.current.name
  aws_iam_path_prefix                     = var.aws_iam_path_prefix == "" ? null : var.aws_iam_path_prefix
}

data "aws_vpc" "selected" {
  id = var.k8s_cluster_type == "eks" ? data.aws_eks_cluster.selected[0].vpc_config[0].vpc_id : var.aws_vpc_id
}

data "aws_region" "current" {
  name = var.aws_region_name
}

data "aws_caller_identity" "current" {}

# The EKS cluster (if any) that represents the installation target.
data "aws_eks_cluster" "selected" {
  count = var.k8s_cluster_type == "eks" ? 1 : 0
  name  = var.k8s_cluster_name
}

data "aws_iam_policy_document" "ec2_assume_role" {
  count = var.k8s_cluster_type == "vanilla" ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_oidc_assume_role" {
  count = var.k8s_cluster_type == "eks" ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.selected[0].identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = [
        "system:serviceaccount:${var.k8s_namespace}:aws-alb-ingress-controller"
      ]
    }
    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.selected[0].identity[0].oidc[0].issuer, "https://", "")}"
      ]
      type = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  name        = "${var.aws_resource_name_prefix}${var.k8s_cluster_name}-alb-ingress-controller"
  description = "Permissions required by the Kubernetes AWS ALB Ingress controller to do it's job."
  path        = local.aws_iam_path_prefix

  tags = var.aws_tags

  force_detach_policies = true

  assume_role_policy = var.k8s_cluster_type == "vanilla" ? data.aws_iam_policy_document.ec2_assume_role[0].json : data.aws_iam_policy_document.eks_oidc_assume_role[0].json
}

resource "aws_iam_policy" "this" {
  policy = file("${path.module}/policy.json")
  description = "Permissions that are required to manage AWS Application Load Balancers."
  path        = local.aws_iam_path_prefix
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.this.name
}

resource "kubernetes_service_account" "this" {
  automount_service_account_token = true
  metadata {
    name        = "aws-alb-ingress-controller"
    namespace   = var.k8s_namespace
    annotations = {
      # This annotation is only used when running on EKS which can
      # use IAM roles for service accounts.
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_cluster_role" "this" {
  metadata {
    name = "aws-alb-ingress-controller"

    labels = {
      "app.kubernetes.io/name"       = "aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "configmaps",
      "endpoints",
      "events",
      "ingresses",
      "ingresses/status",
      "services",
    ]

    verbs = [
      "create",
      "get",
      "list",
      "update",
      "watch",
      "patch",
    ]
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "nodes",
      "pods",
      "secrets",
      "services",
      "namespaces",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = "aws-alb-ingress-controller"

    labels = {
      "app.kubernetes.io/name"       = "aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.this.metadata[0].name
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_service_account.this.metadata[0].namespace
  }
}

terraform {
  required_providers {
    helm = {}
  }
}

#provider "helm" {
#  kubernetes {
#    host                   = var.cluster_host
#    token                  = var.cluster_token
#    cluster_ca_certificate = var.cluster_ca_certificate
#  }
#}

resource "helm_release" "this" {
  name             = "aws-load-balancer-controller"
  chart            = "aws-load-balancer-controller"
  version          = null
  repository       = "https://aws.github.io/eks-charts"
  namespace        = "kube-system"
  create_namespace = false
  cleanup_on_fail  = true

  dynamic "set" {
    for_each = {
      "clusterName"           = var.k8s_cluster_name
      "serviceAccount.create" = "false"
      "serviceAccount.name"   = kubernetes_service_account.this.metadata[0].name
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}