resource "aws_iam_policy" "grafana" {
  policy      = file("${path.module}/cw_policy.json")
  description = "Permissions that are required to manage read from CloudWatch"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name_prefix           = "Grafana"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "grafana" {
  policy_arn = aws_iam_policy.grafana.arn
  role       = aws_iam_role.grafana.name
}

resource "aws_iam_role_policy_attachment" "grafana1" {
  count = length(local.role_policy_arns)

  role       = aws_iam_role.grafana.name
  policy_arn = element(local.role_policy_arns, count.index)
}

resource "aws_security_group" "grafana_sg" {
  name_prefix = "ec2_sg"
  vpc_id      = var.vpc_id
  tags        = {
    Name = "EC2 sg"
  }

}

resource "aws_security_group_rule" "grafana_allow_all" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.grafana_sg.id
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = [local.all_cidr]
}
resource "aws_security_group_rule" "grafana_sg_allow_egress" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.grafana_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [local.all_cidr]
}

resource "aws_iam_instance_profile" "grafana" {
  name = "EC2-Grafana-Profile"
  role = aws_iam_role.grafana.name
}

module "ec2_grafana" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "grafana"

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = var.ssh_key_name
  monitoring             = true
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana.name


  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "null_resource" "ansible_grafana" {
  provisioner "remote-exec" {
    connection {
      host        = module.ec2_grafana.public_ip
      user        = "ec2-user"
      private_key = var.ssh_private_key
    }

    inline = ["echo 'Grafana connected!'"]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${path.module}/ansible/inventory.yml ${path.module}/ansible/site.yml --limit grafana"
  }
  depends_on = [local_file.ssh_private_key, local_file.inventory, module.ec2_grafana]
}