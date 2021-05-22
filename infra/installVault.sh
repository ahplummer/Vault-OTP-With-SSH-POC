#!/bin/bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault tmux -y
sudo echo "{
  \"listener\":  {
    \"tcp\":  {
      \"address\":  \"0.0.0.0:8200\",
      \"tls_disable\":  \"true\"
    }
  },
  \"backend\": {
    \"file\": {
      \"path\": \"/vault/file\"
    }
  },
  \"default_lease_ttl\": \"168h\",
  \"max_lease_ttl\": \"0h\",
  \"api_addr\": \"http://0.0.0.0:8200\",
  \"ui\": \"true\"
}" >> /home/ubuntu/vaultconfig.json
#sudo apt-get install tmux -y
sudo tmux new-session -d -s main
sudo tmux new-window -d -t 'main' -n vlt -c /home/ubuntu
sudo tmux send-keys -t 'main:vlt' 'sudo vault server -config=/home/ubuntu/vaultconfig.json' Enter
