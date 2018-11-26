#!/usr/bin/env bash

set -o nounset

for lg in $(aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/CfnServiceBroker' --output text --query logGroups[].logGroupName) ; do
	aws logs delete-log-group --log-group-name "$lg"
done

for og in $(aws rds describe-option-groups --output text --query OptionGroupsList[].OptionGroupName) ; do
	if [[ "$og" != "${og#cfnservicebroker-}" ]] ; then
		aws rds delete-option-group --option-group-name "$og"
	fi
done

for pg in $(aws rds describe-db-parameter-groups --query DBParameterGroups[].DBParameterGroupName --output text) ; do
	if [[ "$pg" != "${pg#cfnservicebroker-}" ]] ; then
		aws rds delete-db-parameter-group --db-parameter-group-name "$pg"
	fi
done

