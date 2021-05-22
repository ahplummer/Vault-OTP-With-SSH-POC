#!/bin/bash
pushd ../infra
# Output colors
NORMAL="\\033[0;39m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
export AWS_PAGER=""

log() {
  echo -e -n "$BLUE > $1 $NORMAL\n"
}

error() {
  echo ""
  echo -e -n "$RED >>> ERROR - $1$NORMAL\n"
}
help() {
  echo "-----------------------------------------------------------------------"
  echo "                      Available commands                              -"
  echo "-----------------------------------------------------------------------"
  echo -e -n "$BLUE"
  echo "   > init - initialize Vault"
  echo "   > addUser - adds user to vault, requires 2 additional parms"
  echo "   > ----------------------"
  echo "   > setSecret - sets a secret, requires 3 additional parms"
  echo "   > getSecret - gets a secret, requires 2 additional parms"
  echo "   > ----------------------"  
  echo "   > help - Display this help"
  echo -e -n "$NORMAL"
  echo "-----------------------------------------------------------------------"

}
setLocalEnv(){
  if [ -z ${ROOT_TOKEN+x} ]; then
    read -p "Vault Server Name? >" servername
    public_ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$servername | jq -r '.[][].PublicIP')
    private_ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$servername | jq -r '.[][].PrivateIP')
    if [ ${#public_ip_address} -ge 1 ]; then
      echo Public IP is found, setting creds
    else
      echo Could not find server tagged Name=$servername
      exit 1
    fi
    echo \#\!/bin/bash > vault.env
    echo export VAULT_ADDR=http://${public_ip_address}:8200 >> vault.env
    echo export VAULT_INTERNAL_ADDR=http://${private_ip_address}:8200 >> vault.env
    source vault.env
  else
    echo Already have root token, skipping setting environment.
  fi
}
loginOTP(){
  source vault.env
  vault login -method=userpass username=$1 password=$2 > /dev/null
  public_ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$3 | jq -r '.[][].PublicIP')
  echo Public IP for $3 is $public_ip_address
  private_ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$3 | jq -r '.[][].PrivateIP')
  echo Private IP for $3 is $private_ip_address
  tempkey=$(vault write ssh/creds/otp_key_role ip=$private_ip_address | grep "key " | awk '{print $(NF)}')
  echo Use this key for the temporary password: $tempkey
  ssh ubuntu@$public_ip_address
}

init(){
  if [ -f "vault.env" ]; then
    echo vault.env exists, skipping creation of it.
  else
    setLocalEnv
    vault operator init -key-shares=1 -key-threshold=1 > initoutput
    export roottoken=$(cat initoutput | grep Root | awk '{print $4}')
    export unsealtoken=$(cat initoutput | grep Unseal | awk '{print $4}')
    echo export ROOT_TOKEN=$roottoken >> vault.env
    echo export UNSEAL_TOKEN=$unsealtoken >> vault.env
    rm -rf initoutput
  fi
  sleep 2
  source vault.env
  vault operator unseal $UNSEAL_TOKEN
  vault login $ROOT_TOKEN
  vault secrets enable kv-v2
  vault secrets enable ssh
  vault write ssh/roles/otp_key_role \
    key_type=otp \
    default_user=ubuntu \
    cidr_list=0.0.0.0/0
  vault policy write sshuser-otp ./sshuser.hcl
  vault auth enable userpass
}
setSecret(){
  if [ -f ".env" ]
  then
    source .env
  else
    error "For this command, you'll need a pre-configured Vault instance; try './vault.sh initS3' or './vault.sh' initLocal"
    exit 1
  fi
  vault login $ROOT_TOKEN >/dev/null
  vault kv put kv-v2/$1 $1=$2
}
getSecret(){
  if [ -f ".env" ]
  then
    source .env
  else
    error "For this command, you'll need a pre-configured Vault instance; try './vault.sh initS3' or './vault.sh' initLocal"
    exit 1
  fi
  vault login $ROOT_TOKEN >/dev/null
  export secret=$(VAULT_FORMAT=json vault kv get kv-v2/$1 | jq -r '.data.data.'$1)
  echo $secret
}
addUser(){
  source vault.env
  vault login $ROOT_TOKEN >/dev/null
  vault write auth/userpass/users/$1 policies=sshuser-otp password=$2
}

# Check at least 1 argument is given #
if [ $# -lt 1 ]
then
        help
        error "Usage : $0 command"
        exit 1
fi

case "$1" in
# Display help
help) 
    help
    ;;
addUser) 
if [[ -z $2 || -z $3 ]]
    then
      error "You need two additional parms for this command (user, password)"
    else
      addUser $2 $3
    fi
    ;;
loginOTP) 
if [[ -z $2 || -z $3 || -z $4 ]]
    then
      error "You need three additional parms for this command (user, password, server)"
    else
      loginOTP $2 $3 $4
    fi
    ;;
# Set Secret
setSecret) 
if [[ -z $2 || -z $3 ]]
    then
      error "You need two additional parms for this command (key, secret)"
    else
      setSecret $2 $3
    fi
    ;;
# Get Secret
getSecret) 
    if [ -z $2 ]
    then
      error "You need one additional parm for this command (a key)."
    else
      getSecret $2 $3 
    fi
    ;;
*) error "Invalid option"
    #other things?
   ;;
esac

popd