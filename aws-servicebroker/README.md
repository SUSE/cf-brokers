# AWS Service Broker

This repository contains the SCF-oriented helm wrappers for the [AWS service
broker].

[AWS service broker]: https://github.com/awslabs/aws-servicebroker

## Setup
1. Create a VPC, make sure it has an internet gateway and that gateway is
attached to the route table.  You should be able to SSH into a VM running on
that VPC when it has a public IP address.
2. Run `make build` and `make publish` to ensure the docker images are
accessible.  It may be a good idea to override `$DOCKER_REPOSITORY` to prevent
clobbering shared images.n
3. Run `make deploy` to deploy the service broker into helm.  You will need to
override the `IAM_ROLE` variable to point to an IAM role with the appropriate
permissions. (Alternatively, have a role with the string `ServiceBroker` in its
name.)
4. Run `make create-service-broker` to create a service broker in CF.
5. Run `make create-service-instance` to create an instance of the service.  The
parameters given to the instance is harder to get right.
6. Push an application that is bound to the service instance.

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
