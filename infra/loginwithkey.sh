#!/bin/bash
export AWS_PAGER=""
if [ -z $1 ]; then
  read -p "Server name? >" servername
else 
  servername=$1
  echo Will use $servername
fi

if [ ${#servername} -ge 1 ]; then
  echo Server name is $servername, will look up IP address for tagged Name=$servername in EC2. Will use first EC2 in list.
else
  exit 1
fi

ip_address=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$servername | jq -r '.[][].PublicIP')
if [ ${#ip_address} -ge 1 ]; then
  echo IP Address is $ip_address, will look up Instance ID now...
else
  echo Could not find server tagged Name=$servername
  exit 1
fi

instance_id=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$servername | jq -r '.[][].InstanceId')
if [ ${#instance_id} -ge 1 ]; then
  echo Instance_ID is $instance_id, will look up secret by the same name.
  aws secretsmanager get-secret-value --secret-id $instance_id | jq -r '.SecretString' > ec2secret
  chmod 700 ec2secret
  ssh -i ec2secret ubuntu@$ip_address
  rm -f ec2secret
else
  echo Could not find instance_id for server tagged Name=$servername
  exit 1
fi
