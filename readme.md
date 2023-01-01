# Kafka Automated Reboots

This document outlines how to intiate an automated job to reboot Kafka nodes in a given environment. It can be run locally (depending on your EC2 permissions) or deployed to Kubernetes. Note there is no code (application) logic as that is propietary to my employer. Instead I will outline how one might go about it. 

**Table of Contents**

1. [Introduction](#introduction)
2. [How it works](#logic)
3. [Local Testing Against Develop](#local-deploy)
4. [Kubernetes deployment](#live-deploy)
5. [Policy considerations](#policy)

## Introduction <a name="introduction"></a>

A company may have a business/security requirement to reboot EC2 instances for instance upgrades. Kafka nodes must be done in a cycle, accounting for messages replication to come back in sync. Depending on how many nodes one has, this can take hours every time. Leveraging boto3 we can automate this process away while safely allowing under replicated partitions to come back in sync.

## How it works <a name="logic"></a>

Everything can be coded in python3 using boto3, logging, slack and pytest among others. The way the cycle works (see the main method in the `cycle_cluster.py` file) is as follows:

1. List a schedule of all kafka and zookeeper nodes on the cluster.
2. Get current status of all nodes (running, stopped etc). If any node is stopped restart - this accounts for an interrupted/incomplete cycle if the host/pod job had stopped for any reason. 
3. Nominate a kafka node to send messages to/from, and to check on under-replicated-paritions. Note when this node needs to be restarted a different 'polling' node is chosen. 
4. If not a dry run, message to a slack channel cycle is beginning. 
5. For each node, send message to kafka cluster of state before start. 
6. Stop instance, then report under-replicated-partitions. 
7. Start instance and wait for under-replicated-paritions to clear (equals 0).
8. Continue with rest of nodes, sending appropriate errors/warnings thorugh slack if necessary. 
9. Once cycle complete, report to slack and 'close cycle' message to broker. 

You can also test the behaviour of 'what happens if the pod goes down during a cycle?'. If a pod was interrupted, step 2 checks 'was the last cycle unfinished' and if so, start and stopped instances. 

## Local Testing Against Develop <a name="local-deploy"></a>

This example will walk through testing locally by connecting to an environment. Run `localSetup.sh` passing in your desired profile to setup access to the kubectl environment/context and to generate the environment variables we need locally to test against. 

One can first test to see if you have all the permissions/setup correct to run locally. Simply run `pytest` which will collect 8 files and run through tests needed to complete a full cycle. If passed, you can then run `python3 rebooter --dry-run` to see what happens during a cycle. 

To initiate a full reboot run `python3 rebooter --no-dry-run`. Logs will be generated locally though stdout and a logfile. 

Note slack alerts are disabled for local testing.

## Kubernetes deployment<a name="live-deploy"></a>

The idea behind automating this is that it can exist as an ad-hoc job one can run (or set as a cron job) that can be handled in a Kubernetes pod. One can link an AWS role (with appropriate permissions) to a service account, have the service account assume the role and do what it needs to. See the `policy.json`, `trust-relationship` and `role-policy.json` documents for how I did that. Then in our `deployment.yaml`, we'll add the ARN number and it should work. 

A docker image is made including Java as the base and then Python is added. This is then packaged and pushed to your ECR as follows:

```
aws ecr get-login-password --region $AWS_REGION --profile <YOUR-ECR-PROFILE> | docker login --username AWS --password-stdin <YOUR-ECR-ACCOUNT>.dkr.ecr.$AWS_REGION.amazonaws.com

export IMAGE_NAME=<YOUR-IMAGE-NAME>
docker build -t Dockerfile -t $IMAGE_NAME:latest .
LAST_ID=$(docker images $IMAGE_NAME | awk 'NR>1{ print $3}')
docker tag $LAST_ID <YOUR-ECR-ACCOUNT>.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_NAME:latest
```
To generate a helm chart, one can run:

`helm template deployment/ --namespace scripting-tools -f deployment/values.yaml -f deployment/profiles/develop/values.yaml --debug  >> manifest.yaml`

Apply it by:

`kubectl apply -f manifest.yaml`

## Policy considerations<a name="policy"></a>

Included in this repo are `role-policy.json` and `trust-relationship.json`. Both are needed for a programmatic role on AWS to act upon AWS resources (detailed in the role-policy) via a pod, which is the intermediary. The `trustrelationship.json` lists a specific 'Allow' for the principal actor - a named pod in Kubernetes - for authorized use via the use of OIDC endpoints. These endpoints are actually available in any Kubernetes cluster and are very helpful in leveraging pods to do work on instances as standalone jobs. 