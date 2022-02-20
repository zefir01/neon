variable "db_subnet_group" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "database_subnet_ids" {
  type = list(string)
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "ssh_key_name" {
  type = string
}
variable "ssh_private_key" {
  type = string
}