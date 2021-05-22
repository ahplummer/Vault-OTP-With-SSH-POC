#!/bin/bash
export AWS_PAGER=""
pushd ../infra
source infra.env
terraform destroy
aws s3 rm s3://$TF_VAR_STATE_BUCKET_NAME --recursive
aws s3 rb s3://$TF_VAR_STATE_BUCKET_NAME
rm -rf infra.env
rm -rf vault.env
rm -rf ec2*
popd