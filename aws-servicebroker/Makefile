DOCKER_REPOSITORY ?= splatform
DOCKER_TAG ?= latest
NAMESPACE ?= aws
INSTANCE_NAME ?= mysql-inst
BROKER_USERNAME ?= username
BROKER_PASSWORD ?= password
REGISTRY_HOSTNAME ?= ${empty}
REGISTRY_USERNAME ?= ${empty}
REGISTRY_PASSWORD ?= ${empty}
IAM_ROLE ?= $(shell aws iam list-roles --output=json | jq -r '.Roles[] | select(.RoleName | test("ServiceBroker"; "i")) | .Arn' | head -n1)

# Use `make COMMAND=install` to see the generated kube resources (for debugging)
COMMAND ?= upgrade --install --reuse-values --recreate-pods --force

DOCKER_PREFIX := $(if ${REGISTRY_HOSTNAME},${REGISTRY_HOSTNAME}/)

build: build-broker build-init
publish: publish-broker publish-init

build-broker:
	docker build -t ${DOCKER_PREFIX}${DOCKER_REPOSITORY}/aws-service-broker:${DOCKER_TAG} .

publish-broker:
	docker push ${DOCKER_PREFIX}${DOCKER_REPOSITORY}/aws-service-broker:${DOCKER_TAG}

build-init:
	docker build -t ${DOCKER_PREFIX}${DOCKER_REPOSITORY}/aws-service-broker-init:${DOCKER_TAG} -f Dockerfile-init .

publish-init:
	docker push ${DOCKER_PREFIX}${DOCKER_REPOSITORY}/aws-service-broker-init:${DOCKER_TAG}

deploy:
	helm ${COMMAND} --namespace ${NAMESPACE} \
		--set image.registry.hostname="${REGISTRY_HOSTNAME}" \
		--set image.registry.username="${REGISTRY_USERNAME}" \
		--set image.registry.password="${REGISTRY_PASSWORD}" \
		--set image.organization=${DOCKER_REPOSITORY} \
		--set image.tag=${DOCKER_TAG} \
		--set image.pullPolicy=Always \
		--set aws.insecure=true \
		--set aws.keyid="$$(aws configure get aws_access_key_id)" \
		--set aws.secretkey="$$(aws configure get aws_secret_access_key)" \
		--set aws.rolearn="${IAM_ROLE}" \
		--set broker.username="${BROKER_USERNAME}" \
		--set broker.password="${BROKER_PASSWORD}" \
		--debug \
		$(if $(filter install,${COMMAND}), --dry-run --name) aws ./helm

# Helpers for testing
create-service-broker:
	cf create-service-broker aws "${BROKER_USERNAME}" "${BROKER_PASSWORD}" http://aws-service-broker.${NAMESPACE}
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
