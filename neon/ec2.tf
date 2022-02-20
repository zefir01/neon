data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    //values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2_sg"
  vpc_id      = var.vpc_id
  tags        = {
    Name = "EC2 sg"
  }

}

resource "aws_security_group_rule" "ec2_sg_allow_all" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ec2_sg.id
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = [local.all_cidr]
}
resource "aws_security_group_rule" "ec2_sg_allow_egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ec2_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [local.all_cidr]
}

module "ec2_bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "bastion"

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = var.ssh_key_name
  monitoring             = true
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name


  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_solana" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "solana"

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t3.large"
  key_name               = var.ssh_key_name
  monitoring             = true
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  depends_on = [module.ec2_bastion]
}

resource "local_file" "ssh_private_key" {
  filename        = "${path.module}/private.key"
  content         = var.ssh_private_key
  file_permission = "0400"
}

resource "null_resource" "ansible_solana" {
  provisioner "remote-exec" {
    connection {
      host        = module.ec2_solana.public_ip
      user        = "ec2-user"
      private_key = var.ssh_private_key
    }

    inline = ["echo 'Grafana connected!'"]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${path.module}/ansible/inventory.yml ${path.module}/ansible/site.yml --limit \"solana, bastion\""
  }
  depends_on = [local_file.ssh_private_key, local_file.inventory, module.ec2_bastion, module.ec2_solana]
}