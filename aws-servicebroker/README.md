# AWS Service Broker

This repository contains the SCF-oriented helm wrappers for the [AWS service
broker].

[AWS service broker]: https://github.com/awslabs/aws-servicebroker

## Setup
1. Create a VPC, make sure it has an internet gateway and that gateway is
attached to the route table.  You should be able to SSH into a VM running on
that VPC when it has a public IP address.  The VPC should contain `awssb` in the
name (or, alternatively, provide an `AWS_VPC` override to `make`).
2. (Optional) Run `make image` and `make publish` to use custom docker images.
Using the upstream images should work as well (in which case we don't need to
build our own).  If building is desired, `DOCKER_REPOSITORY` should be set to
an organization that is writable (and the same value should be used later).
3. Run `make prereq` to set up the caching tables.
4. Run `make deploy` to deploy the service broker into helm.  A role named
`ServiceBroker` is needed; alternatively, override `AWS_ROLE_ARN` to be the full
ARN of the role.
5. Run `make create-service-broker` to create a service broker in CF.
6. Run `make create-service-instance` to create an instance of the service.  The
parameters given to the instance is harder to get right.
7. Push an application that is bound to the service instance.

## Teardown
1. Run `make delete-service-instance`
2. Run `make delete-service-broker`
3. Run `make undeploy` to delete the helm chart and the cache from `make prereq`

## Example `VCAP_SERVICES`

```json
{"rdsmysql":[{
  "name": "foo",
  "instance_name": "foo",
  "binding_name": null,
  "credentials": {
    "DB_NAME": "srtohcdgrlhtcbuukptgevbbjibddnta",
    "ENDPOINT_ADDRESS": "cdki88scxztwbj.cgmtsmotuxck.us-west-2.rds.amazonaws.com",
    "MASTER_PASSWORD": "i?c,Ujkpyqaj_s),,B-rjzlz]5c;f,qx",
    "MASTER_USERNAME": "master",
    "PORT": "10001"
  },
  "syslog_drain_url": null,
  "volume_mounts": [],
  "label": "rdsmysql",
  "provider": null,
  "plan": "dev",
  "tags": [
    "AWS"
  ]
}]}

```

## Manual installation

### Prerequisites
1. Create a VPC, make sure it has an internet gateway and that gateway is
attached to the route table.  You should be able to SSH into a VM running on
that VPC when it has a public IP address.  The VPC should contain `awssb` in the
name (or, alternatively, provide an `AWS_VPC` override to `make`).
2. Set up a role for the service broker

### Deploying the service broker
1. Create the required DynamoDB table (substitute the correct region id):
```
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
		--region ${AWS_REGION} --table-name awssb
```
2. Wait for the table to finish creating.
3. Create a server certificate for the broker (substitute `CF_NAMESPACE` and `BROKER_NAMESPACE`):
    1. Get the CA certificate:
      ```
      kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert}| base64 -di > ca.pem
      ```
    2. Get the CA private key:
      ```
      kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert-key}' | base64 -di > ca.key
      ```
    3. Create a signing request:
      ```
      openssl req -newkey rsa:4096 -keyout tls.key.encrypted -out tls.req -days 365 \
      -passout pass:1234 \
      -subj '/CN=aws-servicebroker.${BROKER_NAMESPACE}' -batch \
      </dev/null
      ```
    4. Decrypt the generated broker private key:
      ```
      openssl rsa -in tls.key.encrypted -passin pass:1234 -out tls.key
      ```
    5. Sign the request with the CA certificate:
      ```
      openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -in tls.req -out tls.pem
      ```
4. Deploy the service broker:
  Required substitutions:
  - `BROKER_NAMESPACE`
  - `AWS_ACCESS_KEY` (e.g. to output of `aws configure get aws_access_key_id`)
  - `AWS_SECRET_KEY` (e.g. to output of `aws configure get aws_secret_access_key`)
  - `AWS_REGION`
  - `AWS_TARGET_ACCOUNT_ID` (to the account of the role to assume)
  - `AWS_TARGET_ROLE_NAME` (to the role name of the role to assume)
  - `AWS_VPC` (as created in the prerequisites)
  ```
  helm install \
    --repo https://awsservicebroker.s3.amazonaws.com/charts \
    aws-servicebroker \
    --version 1.0.0-beta.3 \
    --name aws \
    --namespace ${BROKER_NAMESPACE} \
    --set deployClusterServiceBroker=false \
    --set authenticate=false \
    --set aws.accesskeyid="${AWS_ACCESS_KEY}" \
    --set aws.secretkey="${AWS_SECRET_KEY}" \
    --set aws.region=${AWS_REGION} \
    --set tls.cert="$$(base64 --wrap=0 tls.pem)" \
    --set tls.key="$$(base64 --wrap=0 tls.key)" \
    --set-string aws.targetaccountid=${AWS_TARGET_ACCOUNT_ID} \
    --set aws.targetrolename=${AWS_TARGET_ROLE_NAME}} \
    --set aws.vpcid=${AWS_VPC} \
    --set brokerconfig.verbosity=0 \
    --set image=awsservicebroker/aws-servicebroker:beta
  ```
5. Wait for things to become ready (by checking with `kubectl get pods --all-namespaces`)
6. Create a service broker in CF:
  ```
	cf create-service-broker aws unused-username unused-password  https://aws-servicebroker.${BROKER_NAMESPACE}
	cf service-brokers
	cf service-access
	cf enable-service-access rdsmysql -p custom
  ```
7. Check that the service broker is registered with `cf service-brokers`
8. Check that there are services available with `cf service-access`

### Creating a service instance
1. Look for available service plans with `cf service-access`
2. [Enable service plans](https://docs.cloudfoundry.org/services/access-control.html); for example, the MySQL custom plan can be enabled via `cf enable-service-access rdsmysql -p custom`.
3. To create a service instance, use the normal `cf create-service`.  As an example, a custom MySQL instance can be created as:
```
cf create-service rdsmysql custom mysql-instance-name -c '{
  "AccessCidr": "192.0.2.24/32",
  "BackupRetentionPeriod": 0,
  "MasterUsername": "master",
  "DBInstanceClass": "db.t2.micro",
  "PubliclyAccessible": "true",
  "region": "${AWS_REGION}",
  "StorageEncrypted": "false",
  "VpcId": "${AWS_VPC}",
  "target_account_id": "${AWS_TARGET_ACCOUNT_ID}",
  "target_role_name": "${AWS_TARGET_ROLE_NAME}"
}'
```
The various variables will be need to be replaced when actually passed to `cf create-service`, of course.

### Clean up
Beyond the normal `cf delete-service` and `cf delete-service-broker`, it is useful to `helm delete aws` as well to clean up the deployed helm chart.  The manually created DynamoDB table will need to be deleted as well, via `aws dynamodb delete-tabe --table-name awssb --region ${AWS_REGION}`.

