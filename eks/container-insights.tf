provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.cp.endpoint
    token                  = data.aws_eks_cluster_auth.aws_iam_authenticator.token
    cluster_ca_certificate = base64decode(aws_eks_cluster.cp.certificate_authority[0].data)
  }
}

## kubernetes container-insights

locals {
  metrics_enabled = true
  logs_enabled    = true
}

locals {
  suffix = (local.metrics_enabled || local.logs_enabled) ? random_string.containerinsights-suffix.0.result : ""
}

module "irsa-metrics" {
  source         = "Young-ook/eks/aws//modules/iam-role-for-serviceaccount"
  count          = local.metrics_enabled ? 1 : 0
  name           = join("-", compact(["irsa", aws_eks_cluster.cp.name, "amazon-cloudwatch", local.suffix]))
  namespace      = "amazon-cloudwatch"
  serviceaccount = "amazon-cloudwatch"
  oidc_url       = aws_iam_openid_connect_provider.open_id_provider.url
  oidc_arn       = aws_iam_openid_connect_provider.open_id_provider.arn
  policy_arns    = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  tags           = var.tags
}

resource "helm_release" "metrics" {
  count            = local.metrics_enabled ? 1 : 0
  name             = "aws-cloudwatch-metrics"
  chart            = "aws-cloudwatch-metrics"
  version          = null
  repository       = "https://aws.github.io/eks-charts"
  namespace        = "amazon-cloudwatch"
  create_namespace = true
  cleanup_on_fail  = true

  dynamic "set" {
    for_each = {
      "clusterName"                                               = aws_eks_cluster.cp.name
      "serviceAccount.name"                                       = "amazon-cloudwatch"
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.irsa-metrics[0].arn[0]
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}

module "irsa-logs" {
  source         = "Young-ook/eks/aws//modules/iam-role-for-serviceaccount"
  count          = local.logs_enabled ? 1 : 0
  name           = join("-", compact(["irsa", aws_eks_cluster.cp.name, "aws-for-fluent-bit", local.suffix]))
  namespace      = "kube-system"
  serviceaccount = "aws-for-fluent-bit"
  oidc_url       = aws_iam_openid_connect_provider.open_id_provider.url
  oidc_arn       = aws_iam_openid_connect_provider.open_id_provider.arn
  policy_arns    = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  tags           = var.tags
}

resource "helm_release" "logs" {
  count           = local.logs_enabled ? 1 : 0
  name            = "aws-for-fluent-bit"
  chart           = "aws-for-fluent-bit"
  version          = null
  repository       = "https://aws.github.io/eks-charts"
  namespace       = "kube-system"
  cleanup_on_fail = true

  dynamic "set" {
    for_each = {
      "cloudWatch.enabled"                                        = true
      "cloudWatch.region"                                         = data.aws_region.current.name
      "cloudWatch.logGroupName"                                   = format("/aws/containerinsights/%s/application", aws_eks_cluster.cp.name)
      "firehose.enabled"                                          = false
      "kinesis.enabled"                                           = false
      "elasticsearch.enabled"                                     = false
      "serviceAccount.name"                                       = "aws-for-fluent-bit"
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.irsa-logs[0].arn[0]
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "random_string" "containerinsights-suffix" {
  count   = local.metrics_enabled || local.logs_enabled ? 1 : 0
  length  = 5
  upper   = false
  lower   = true
  number  = false
  special = false
}

