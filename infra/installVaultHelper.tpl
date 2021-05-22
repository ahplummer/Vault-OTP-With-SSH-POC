#!/bin/bash
sudo apt-get install unzip -y
wget https://releases.hashicorp.com/vault-ssh-helper/0.2.0/vault-ssh-helper_0.2.0_linux_amd64.zip
sudo unzip -q vault-ssh-helper_0.2.0_linux_amd64.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault-ssh-helper
sudo chown root:root /usr/local/bin/vault-ssh-helper
sudo mkdir /etc/vault-ssh-helper.d/
sudo tee /etc/vault-ssh-helper.d/config.hcl <<EOF
vault_addr = "http://${vault_address}:8200"
tls_skip_verify = true
ssh_mount_point = "ssh"
allowed_roles = "*"
EOF
sudo sed -i 's!@include\ common-auth!#@include\ common-auth\nauth\ requisite\ pam_exec.so\ quiet\ expose_authtok\ log=/var/log/vault-ssh.log\ /usr/local/bin/vault-ssh-helper\ -dev\ -config=/etc/vault-ssh-helper.d/config.hcl\nauth\ optional\ pam_unix.so\ not_set_pass\ use_first_pass\ nodelay\n!' /etc/pam.d/sshd
sudo sed -i 's!ChallengeResponseAuthentication\ no!ChallengeResponseAuthentication\ yes!' /etc/ssh/sshd_config
sudo systemctl restart sshd
vault-ssh-helper -verify-only -dev -config /etc/vault-ssh-helper.d/config.hcl