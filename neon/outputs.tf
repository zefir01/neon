output "solana_ip" {
  value = module.ec2_solana.private_ip
}
output "grafana_ip" {
  value = module.ec2_grafana.public_ip
}