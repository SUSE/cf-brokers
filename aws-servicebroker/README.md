# AWS Service Broker

This repository contains the SCF-oriented helm wrappers for the [AWS service
broker].

[AWS service broker]: https://github.com/awslabs/aws-servicebroker

## Setup
1. Create a VPC, make sure it has an internet gateway and that gateway is
attached to the route table.  You should be able to SSH into a VM running on
that VPC when it has a public IP address.
2. (Optional) Run `make image` and `make publish` to use custom docker images.
Using the upstream images should work as well (in which case we don't need to
build our own).  If building is desired, `DOCKER_REPOSITORY` should be set to
an organization that is writable (and the same value should be used later).
3. Run `make prereq` to set up the caching tables.
4. Run `make deploy` to deploy the service broker into helm.  A role named
`ServiceBroker` is needed.
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
