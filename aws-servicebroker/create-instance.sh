#!/usr/bin/env bash

set -o errexit -o nounset

REGION=us-west-2
INSTANCE_NAME="${1}"
IP="$(curl checkip.dyndns.org | awk '{ print $NF }' | cut -d'<' -f1)"
VPC="$(aws ec2 describe-vpcs --region "${REGION}" --output json | \
    jq -r '
        .Vpcs[] |
        select(
            .Tags // [] |
             .[] |
             select(.Key == "Name") |
             .Value |
             contains("awssb")
        ) |
        .VpcId'
)"
ROLE_ARN="$(aws iam list-roles --output=json | \
    jq -r '.Roles[] | select(.RoleName | test("ServiceBroker"; "i")) | .Arn' | \
    head -n1)"
ROLE_ACCT="${ROLE_ARN%%:role/*}"
# Things seem to fall over creating the second subnet if we have fewer AZs
CONFIG="$(cat <<EOF
    {
        "AccessCidr": "${IP}/32",
        "BackupRetentionPeriod": 0,
        "MasterUsername": "master",
        "DBInstanceClass": "db.t2.micro",
        "PubliclyAccessible": "true",
        "region": "${REGION}",
        "StorageEncrypted": "false",
        "VpcId": "${VPC}",
        "target_account_id": "${ROLE_ACCT##*:}",
        "target_role_name": "${ROLE_ARN##*/}"
    }
EOF
)"

cf create-service rdsmysql custom "${INSTANCE_NAME}" -c "${CONFIG}"
