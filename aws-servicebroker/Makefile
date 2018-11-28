DOCKER_REPOSITORY ?= awsservicebroker
DOCKER_TAG ?= beta
NAMESPACE ?= aws
INSTANCE_NAME ?= mysql-inst
BROKER_VERSION ?= 1.0.0-beta.3
BROKER_USERNAME ?= username
BROKER_PASSWORD ?= password
CF_NAMESPACE ?= cf

REGION ?= us-west-2
AWS_VPC ?= $(shell aws ec2 describe-vpcs --region "${REGION}" --output json | \
    jq -r '                                                                   \
        .Vpcs[] |                                                             \
        select(                                                               \
            .Tags // [] |                                                     \
             .[] |                                                            \
             select(.Key == "Name") |                                         \
             .Value |                                                         \
             contains("awssb")                                                \
        ) |                                                                   \
        .VpcId'                                                               \
)

image:
	${MAKE} -C src image IMAGE=${DOCKER_REPOSITORY}/aws-servicebroker TAG=${DOCKER_TAG}
	docker push ${DOCKER_REPOSITORY}/aws-servicebroker:${DOCKER_TAG}

helm:
	${MAKE} -C src helm

.PHONY: helm

prereq:
	aws dynamodb wait table-not-exists --table-name awssb --region ${REGION}
	aws dynamodb create-table \
		--attribute-definitions \
			AttributeName=id,AttributeType=S \
			AttributeName=userid,AttributeType=S \
			AttributeName=type,AttributeType=S \
		--key-schema \
			AttributeName=id,KeyType=HASH \
			AttributeName=userid,KeyType=RANGE \
		--global-secondary-indexes \
			'IndexName=type-userid-index,KeySchema=[{AttributeName=type,KeyType=HASH},{AttributeName=userid,KeyType=RANGE}],Projection={ProjectionType=INCLUDE,NonKeyAttributes=[id,userid,type,locked]},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5}' \
		--provisioned-throughput \
			ReadCapacityUnits=5,WriteCapacityUnits=5 \
		--region ${REGION} --table-name awssb
	aws dynamodb wait table-exists --table-name awssb --region ${REGION}

undeploy:
	-helm delete --purge aws
	-aws dynamodb delete-table --table-name awssb --region ${REGION}

ca.key:
	kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert-key}' | base64 -di > $@

ca.pem:
	kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert}' | base64 -di > $@

tls.key.encrypted:
	openssl req -newkey rsa:4096 -keyout tls.key.encrypted -out tls.req -days 365 \
		-passout pass:1234 \
		-subj '/CN=aws-servicebroker.${NAMESPACE}' -verbose -batch \
		</dev/null

tls.req: tls.key.encrypted
	# built as a side effect

tls.key: tls.key.encrypted
	openssl rsa -in $< -passin pass:1234 -out $@

tls.pem: tls.req ca.key ca.pem
	openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial \
		-in tls.req -out tls.pem
	-rm -f ca.srl

.INTERMEDIATE: tls.pem tls.key tls.req tls.key.encrypted ca.pem ca.key ca.srl

deploy: tls.pem tls.key
	helm install \
		--repo https://awsservicebroker.s3.amazonaws.com/charts \
		aws-servicebroker \
		--version ${BROKER_VERSION} \
		--name aws \
		--namespace aws \
		--set deployClusterServiceBroker=false \
		--set authenticate=false \
		--set aws.accesskeyid="$$(aws configure get aws_access_key_id)" \
		--set aws.secretkey="$$(aws configure get aws_secret_access_key)" \
		--set aws.region=${REGION} \
		--set tls.cert="$$(base64 --wrap=0 tls.pem)" \
		--set tls.key="$$(base64 --wrap=0 tls.key)" \
		--set-string aws.targetaccountid=138384977974 \
		--set aws.targetrolename=ServiceBroker \
		--set aws.vpcid=${AWS_VPC} \
		--set brokerconfig.verbosity=0 \
		--set image=${DOCKER_REPOSITORY}/aws-servicebroker:${DOCKER_TAG}

# Helpers for testing
create-service-broker:
	cf create-service-broker aws "${BROKER_USERNAME}" "${BROKER_PASSWORD}" https://aws-servicebroker.${NAMESPACE}
	cf service-brokers
	cf service-access
	cf enable-service-access rdsmysql -p custom

delete-service-broker:
	cf delete-service-broker -f aws

create-service-instance:
	./create-instance.sh ${INSTANCE_NAME}

delete-service-instance:
	cf delete-service -f ${INSTANCE_NAME}

cleanup:
	./cleanup.sh
