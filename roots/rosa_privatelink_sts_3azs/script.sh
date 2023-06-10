#!/bin/bash

REGION=eu-central-1
SUBNET=subnet-02ea20da9e68ee42d,subnet-0bf44c3570cc0295b,subnet-07aff911208812359
OWNER=lmartinh
CLUSTER_NAME=lmartinh04
VERSION=4.12.14
ROSA_ENVIRONMENT=Test

rosa create ocm-role --mode auto -y --admin
rosa create user-role --mode auto -y
rosa create account-roles --mode auto -y
time rosa create cluster --region $REGION --version $VERSION --enable-autoscaling --min-replicas 3 --max-replicas 6 --private-link --cluster-name=$CLUSTER_NAME --machine-cidr=10.1.0.0/16 --subnet-ids=$SUBNET --tags=Owner:$OWNER,Environment:$ROSA_ENVIRONMENT --sts -y --multi-az  || exit 1
sleep 5
rosa create operator-roles --cluster $CLUSTER_NAME -y --mode auto
rosa create oidc-provider --cluster $CLUSTER_NAME -y --mode auto

echo "Follow logs with: rosa logs install -c $CLUSTER_NAME --watch"


