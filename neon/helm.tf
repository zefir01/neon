terraform {
  required_providers {
    helm = {}
  }
}

resource "helm_release" "this" {
  name             = "neon-chart"
  chart            = "${path.module}/neon-chart"
  version          = null
  namespace        = "default"
  create_namespace = false
  cleanup_on_fail  = true

  dynamic "set" {
    for_each = {
      "postgresHost" = module.db.db_instance_address
      "postgresDB"   = "neon"
      "postgresUser" = "neon_proxy"
      "postgresPass" = base64encode(module.db.db_instance_password)
      "solanaIp"     = module.ec2_solana.private_ip
    }
    content {
      name  = set.key
      value = set.value
    }
  }
  depends_on = [module.ec2_solana, null_resource.ansible_solana]
}