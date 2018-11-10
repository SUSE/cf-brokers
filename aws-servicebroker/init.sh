#!/usr/bin/env bash

if aws dynamodb describe-table --region "${REGION}" --table-name "${TABLE_NAME}" ; then
    echo "Table exists, not creating"
    exit 0
fi

INDEXES="$(tr -d '[:space:]' <<EOF
    IndexName=type-userid-index,
    KeySchema=[
        {AttributeName=type,KeyType=HASH},
        {AttributeName=userid,KeyType=RANGE}
    ],
    Projection={
        ProjectionType=INCLUDE,
        NonKeyAttributes=[id,userid,type,locked]
    },
    ProvisionedThroughput={
        ReadCapacityUnits=5,
        WriteCapacityUnits=5
    }
EOF
)"

aws dynamodb create-table \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=userid,AttributeType=S \
        AttributeName=type,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
        AttributeName=userid,KeyType=RANGE \
    --global-secondary-indexes "${INDEXES}" \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "${REGION}" \
    --table-name "${TABLE_NAME}"

while true ; do
    status="$(aws dynamodb describe-table --region "${REGION}" --table-name "${TABLE_NAME}" --query Table.TableStatus --output text)"
    echo "Table ${TABLE_NAME} has status ${status}"
    if [[ "${status}" != "CREATING" ]] ; then
        break
    fi
done
echo "Table created."
