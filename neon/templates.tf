resource "local_file" "solana_endpoints" {
  content = templatefile("${path.module}/templates/endpoints.tpl", {
    solana_private_ip = module.ec2_solana.private_ip
    postgres_ip       = module.db.db_instance_address
  })
  filename = "${path.module}/deploy/endpoints.yaml"
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    bastion_ip       = module.ec2_bastion.public_ip
    solana_ip        = module.ec2_solana.private_ip
    private_key_path = abspath("${path.module}/../private.key")
    grafana_ip        = module.ec2_grafana.public_ip
  })
  filename = "${path.module}/ansible/inventory.yml"
}

resource "local_file" "secrets" {
  content = templatefile("${path.module}/templates/secrets.tpl", {
    postgres-password = base64encode(module.db.db_instance_password)
  })
  filename = "${path.module}/deploy/secrets.yml"
}