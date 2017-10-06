#!/bin/bash

export STACK_NAME="OIDCAccessProxy"
export AWS_DEFAULT_PROFILE="infosec-dev-admin"
export AWS_DEFAULT_REGION="us-west-2"
export SSH_KEYS="infosec-us-west-2-keys"
export CREDSTASH_REGION="us-west-2"

# Need to delete the stack?
# aws cloudformation delete-stack --stack-name ${STACK_NAME}-dev
# sleep 60


echo Creating stack... this takes a long time
aws cloudformation create-stack --stack-name ${STACK_NAME}-dev --template-body file://us-west-2.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHKeyName,ParameterValue=${SSH_KEYS} ParameterKey=EnvType,ParameterValue=dev \
    || exit $?
aws wait stack-create-complete || exit $?

credstash_key_id="$(aws --region ${CREDSTASH_REGION} kms list-aliases --query "Aliases[?AliasName=='alias/credstash'].TargetKeyId | [0]" --output text)"
role_arn="$(aws iam get-role --role-name ${STACK_NAME}-Role --query Role.Arn --output text)"
constraints="EncryptionContextEquals={app=${STACK_NAME}}"

# Grant the IAM role permissions to decrypt
aws kms create-grant --key-id $credstash_key_id --grantee-principal $role_arn --operations "Decrypt" \
    --constraints $constraints --name ${STACK_NAME} \
    || exit $?
