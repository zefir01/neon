all:
  vars:
    ansible_user: "ec2-user"
    ansible_ssh_private_key_file: "${private_key_path}"
    accelerate: true
    ansible_ssh_pipelining: true
    ansible_become: yes
    ansible_ssh_common_args: '-o ControlPersist=60s -o ControlMaster=auto -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  children:
    bastion:
      hosts:
        bastion1:
          ansible_host: ${bastion_ip}
    solana:
      hosts:
        solana1:
          ansible_host: ${solana_ip}
          ansible_ssh_common_args: '-o ControlPersist=60s -o ControlMaster=auto -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlPersist=60s -o ControlMaster=auto -i ${private_key_path} -W %h:%p ec2-user@${bastion_ip}"'
    grafana:
      hosts:
        grafana1:
          ansible_host: ${grafana_ip}