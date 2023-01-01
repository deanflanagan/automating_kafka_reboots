#!/bin/bash

set -e

AWS_PROFILE=$1

aws sso login --profile $AWS_PROFILE
kubectl config use-context <YOUR-DESIRED-CONTEXT>

echo -e KAFKA_ENV=dev | tee .env 
echo -e AWS_PROFILE=$AWS_PROFILE | tee -a .env
echo -e AWS_REGION=us-east-1 | tee -a .env
echo -e BOOTSTRAP_SERVER=localhost | tee -a .env

pip install .
