# output variables

output "cluster" {
  description = "The EKS cluster attributes"
  value       = aws_eks_cluster.cp
}


output "tags" {
  description = "The generated tags for EKS integration"
  value = {
    "shared"       = local.eks-shared-tag
    "owned"        = local.eks-owned-tag
    "elb"          = local.eks-elb-tag
    "internal-elb" = local.eks-internal-elb-tag
  }
}

data "aws_region" "current" {}

output "kubeconfig" {
  description = "Bash script to update kubeconfig file"
  value = join(" ", [
    "bash -e",
    format("%s/script/update-kubeconfig.sh", path.module),
    format("-r %s", data.aws_region.current.name),
    format("-n %s", aws_eks_cluster.cp.name),
    "-k kubeconfig",
  ])
}

output "oidc" {
  value = aws_eks_cluster.cp.identity[0].oidc[0].issuer
}

output "cluster_host" {
  value = aws_eks_cluster.cp.endpoint
}
output "cluster_token" {
  value = data.aws_eks_cluster_auth.aws_iam_authenticator.token
}

output "cluster_ca_certificate" {
  value = base64decode(aws_eks_cluster.cp.certificate_authority[0].data)
}