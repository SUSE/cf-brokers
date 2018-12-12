# AWS Service Broker
 
## Setup

### Prerequisites

1.Ensure you've SCF deployed on an EKS cluster.

2.Create the required DynamoDB table where the AWS service broker will store the data:
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
3.Wait for the table to finish creating.

4.Create a server certificate for the broker (substitute `CF_NAMESPACE` and `BROKER_NAMESPACE`):

    a. Get the CA certificate:
      ```
      kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert}| base64 -di > ca.pem
      ```
    b. Get the CA private key:
      ```
      kubectl get secret -n ${CF_NAMESPACE} -o jsonpath='{.items[*].data.internal-ca-cert-key}' | base64 -di > ca.key
      ```
    c. Create a signing request:
      ```
      openssl req -newkey rsa:4096 -keyout tls.key.encrypted -out tls.req -days 365 \
      -passout pass:1234 \
      -subj '/CN=aws-servicebroker.${BROKER_NAMESPACE}' -batch \
      </dev/null
      ```
    d. Decrypt the generated broker private key:
      ```
      openssl rsa -in tls.key.encrypted -passin pass:1234 -out tls.key
      ```
    e. Sign the request with the CA certificate:
      ```
      openssl x509 -req -CA ca.pem -CAkey ca.key -CAcreateserial -in tls.req -out tls.pem
      ```

5.Install the AWS service broker as documented at 

https://github.com/awslabs/aws-servicebroker/blob/master/docs/getting-started-k8s.md

Skip the installation of the Kubernetes Service Catalog part. While installing the
AWS service broker make sure to update the helm chart version (the version as of this
writing is 1.0.0-beta.3). For the broker install, pass in a value indicating the Cluster
Service Broker should not be installed.

`helm install aws-sb/aws-servicebroker --name aws-servicebroker --namespace aws-sb --version 1.0.0-beta.3 --set aws.secretkey=$aws_access_key --set aws.accesskeyid=$aws_key_id --set deployClusterServiceBroker=false --set tls.cert="$(base64 -w0 tls.pem)" --set tls.key="$(base64 -w0 tls.key)" --set aws.tablename=awssb --set aws.vpcid=$vpcid --set aws.region=$aws_region --set authenticate=false`

6.Create a service broker in CF:
  ```
	cf create-service-broker aws-servicebroker unused-username unused-password  https://aws-servicebroker.${BROKER_NAMESPACE}
	cf service-brokers
	cf service-access
	cf enable-service-access rdsmysql -p custom
  ```

7.Check that the service broker is registered with `cf service-brokers`

8.Check that there are services available with `cf service-access`

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

