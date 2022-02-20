data "tls_certificate" "cp_cert" {
  url = aws_eks_cluster.cp.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "open_id_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cp_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cp.identity[0].oidc[0].issuer
}

data "aws_eks_cluster_auth" "aws_iam_authenticator" {
  name = aws_eks_cluster.cp.name
}

resource "null_resource" "kube-config" {
  depends_on = [aws_eks_cluster.cp]
  provisioner "local-exec" {
    command = join(" ", [
      "bash -e",
      format("%s/script/update-kubeconfig.sh", path.module),
      format("-r %s", data.aws_region.current.name),
      format("-n %s", aws_eks_cluster.cp.name),
      "-k kubeconfig",
    ])
  }
}

provider "kubernetes" {
  //alias = "eks"
  //host                   = aws_eks_cluster.cp.endpoint
  //cluster_ca_certificate = base64decode(aws_eks_cluster.cp.certificate_authority[0].data)
  //config_context = "arn:aws:eks:eu-central-1:542109000649:cluster/eks-appmesh-tc1"
  //config_context=aws_eks_cluster.cp.arn
  //config_path    = "/home/user/.kube/config"
  //token                  = data.aws_eks_cluster_auth.aws_iam_authenticator.token
  //load_config_file       = true
  #  exec {
  #    api_version = "client.authentication.k8s.io/user"
  #    args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cp.name]
  #    command = "aws"
  #  }
  host                   = aws_eks_cluster.cp.endpoint
  token                  = data.aws_eks_cluster_auth.aws_iam_authenticator.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.cp.certificate_authority[0].data)
}


module "alb" {
  source                             = "./alb"
  aws_alb_ingress_controller_version = "2.4.0"
  cluster_host                       = aws_eks_cluster.cp.endpoint
  cluster_token                      = data.aws_eks_cluster_auth.aws_iam_authenticator.token
  cluster_ca_certificate             = base64decode(aws_eks_cluster.cp.certificate_authority[0].data)

  providers = {
    helm = helm
  }

  k8s_cluster_type = "eks"
  k8s_namespace    = "kube-system"

  aws_region_name  = data.aws_region.current.name
  k8s_cluster_name = aws_eks_cluster.cp.name

  //  k8s_pod_annotations = {
  //    "alb.ingress.kubernetes.io/target-type" = "ip"
  //  }

  aws_tags = {
    "k8s_ingress" = "test1"
  }

  depends_on = [aws_eks_cluster.cp, aws_eks_node_group.ng]
}


module "irsa" {
  source = "Young-ook/eks/aws//modules/iam-role-for-serviceaccount"

  namespace      = "default"
  serviceaccount = "external_dns"
  oidc_url       = aws_iam_openid_connect_provider.open_id_provider.url
  oidc_arn       = aws_iam_openid_connect_provider.open_id_provider.arn
  policy_arns    = ["arn:aws:iam::aws:policy/AmazonRoute53FullAccess"]
  tags           = { "env" = "test" }
}

#resource "aws_iam_role_policy_attachment" "aws_pods" {
#  role       = aws_iam_role.ng.name
#  policy_arn = module.irsa.arn[0]
#  depends_on = [aws_iam_role.ng]
#}

resource "kubernetes_cluster_role" "external_dns" {
  metadata {
    name = "externaldns"
  }
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name = "externaldns"
  }
}

resource "kubernetes_cluster_role_binding" "external_dns" {
  metadata {
    name = "externaldns-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "externaldns"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "externaldns"
    namespace = "default"
  }
}