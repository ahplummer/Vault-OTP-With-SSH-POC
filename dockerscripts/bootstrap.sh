#!/bin/bash
export AWS_PAGER=""
source .env
pushd ../infra
aws configure
export logininfo=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print $3}')
if [ ${#logininfo} -ge 1 ]; then
  echo 'Using login info'
else
  exit 1
fi

rm -rf ./infra.env

if [ -z ${RANDOM_INFRA_STRING+x} ]; then
  export RANDOM_INFRA_STRING="$(openssl rand -hex 5)"
  echo $RANDOM_INFRA_STRING "is new, and will be used to generate infra..."
else
  echo $RANDOM_INFRA_STRING "was previously set, and will be used to generate infra..."
fi
echo export RANDOM_INFRA_STRING=$(echo $RANDOM_INFRA_STRING) >> ./infra.env
export TF_VAR_STATE_BUCKET_NAME="tfstate-${RANDOM_INFRA_STRING}-sshpoc"
export TF_VAR_STATE_BUCKET_KEY="tfstate"
echo export TF_VAR_STATE_BUCKET_NAME=$(echo $TF_VAR_STATE_BUCKET_NAME) >> ./infra.env
echo export TF_VAR_STATE_BUCKET_KEY=$(echo $TF_VAR_STATE_BUCKET_KEY) >> ./infra.env

read -p "What AWS region should we build in? (us-east-1, us-east-2 are valid) [${TF_VAR_REGION}] >" TF_VAR_REGION
case $TF_VAR_REGION in
  "" | "us-east-1")
    echo "US East 1 will be used"
    export TF_VAR_REGION="us-east-1"
    ;;
   *)
    echo "There was a problem with your selection..."
    exit 1
    ;;
esac
echo export TF_VAR_REGION=$(echo $TF_VAR_REGION) >> ./infra.env

read -p "What name of the server do you want to tag with? [example-ec2] >" TF_VAR_EC2_NAME
case $TF_VAR_EC2_NAME in
  "" | "example-ec2")
    echo Default of example-ec2 will be used.
    export TF_VAR_EC2_NAME="example-ec2"
    ;;
   *)
    echo Your selected name $TF_VAR_EC2_NAME will be used.
    ;;
esac
echo export TF_VAR_EC2_NAME=$(echo $TF_VAR_EC2_NAME) >> ./infra.env

read -p "What name of the server do you want to tag with? [vault-ec2] >" TF_VAR_VAULT_NAME
case $TF_VAR_VAULT_NAME in
  "" | "vault-ec2")
    echo Default of vault-ec2 will be used.
    export TF_VAR_VAULT_NAME="vault-ec2"
    ;;
   *)
    echo Your selected name $TF_VAR_VAULT_NAME will be used.
    ;;
esac
echo export TF_VAR_VAULT_NAME=$(echo $TF_VAR_VAULT_NAME) >> ./infra.env

read -p "What is the project name? This will be used as a tag. (no spaces) [${TF_VAR_PROJECT}] >" TF_VAR_PROJECT
case $TF_VAR_PROJECT in
  "")
    export TF_VAR_PROJECT="secretproject"
    ;;
esac
echo export TF_VAR_PROJECT=$(echo $TF_VAR_PROJECT) >> ./infra.env

if aws s3 ls s3://$TF_VAR_STATE_BUCKET_NAME 2>&1 | grep -q 'NoSuchBucket'
then
    echo "Creating bucket now..."
    aws s3api create-bucket --bucket $TF_VAR_STATE_BUCKET_NAME --region $TF_VAR_REGION 
else
    echo "Bucket already created..."
fi

rm -rf ec2*
ssh-keygen -f ./ec2 -b 2048 -t rsa -q -N ""

rm -rf ./.terraform

terraform init --backend-config "bucket=$TF_VAR_STATE_BUCKET_NAME" --backend-config "key=$TF_VAR_STATE_BUCKET_KEY" --backend-config "region=$TF_VAR_REGION" 
terraform apply
popd