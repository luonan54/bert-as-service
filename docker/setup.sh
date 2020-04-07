#!/bin/bash

FILE=./docker/Dockerfile
if ![test -f "$FILE"] then
   echo "Run this script from the top level directory of Bert As Service."
   exit 1
fi

#
# Prerequisites
#
# 1. Install GCloud, gsutil
# https://cloud.google.com/sdk/install
# https://cloud.google.com/storage/docs/gsutil_install
#
# 2. Install Kubectl
# https://kubernetes.io/docs/tasks/tools/install-kubectl/
#
# 3. Install Docker 
# https://docs.docker.com/install/
#

# Name of your GCP project for billing, etc.
export GCP_PROJECT=bert-project
export GCP_ZONE=us-east1-c
export GCP_CLUSTER=bert-cluster

# Setup gcloud
#
gcloud init
gcloud projects create $GCP_PROJECT --name="Bert as a Service"
gcloud config set project $GCP_PROJECT

#
# Required API access

#
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable containeranalysis.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
gcloud services enable replicapool.googleapis.com
gcloud services enable replicapoolupdater.googleapis.com
gcloud services enable storage-component.googleapis.com
#
# Optional API access
#
gcloud services enable language.googleapis.com
gcloud services enable tpu.googleapis.com
gcloud services enable translate.googleapis.com
gcloud services enable videointelligence.googleapis.com
gcloud services enable vision.googleapis.com
gcloud services enable sheets.googleapis.com
gcloud services enable runtimeconfig.gogoleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable drive.googleapis.com
gcloud services enable file.googleapis.com
gcloud services enable kgraph.googleapis.com
gcloud services enable kgsearch.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable monitoring.googleapis.com

# setup access to docker
sudo usermod -a -G docker ${USER}
gcloud auth configure-docker

#
# Choose your GPU accelerators from the list for your region
#
# gcloud compute accelerator-types list
#
# Then go online and reserve sufficient GPUs of your chosen type in your quota
# https://console.cloud.google.com/iam-admin/quotas
#
export GCP_GPU=nvidia-tesla-k80
export GCP_GPU_COUNT=4
export GCP_GPU_POOL=bert_gpu_pool

# create a cluster to use these GPUs
gcloud container clusters create $GCP_CLUSTER \
--accelerator type=$GCP_GPU,count=$GCP_CPU_COUNT \
--zone $GCP_ZONE

# create a pool of nodes for the cluster
gcloud container node-pools create $GCP_GPU_POOL \
--accelerator type=$GCP_GPU,count=$GCP_GPU_COUNT --zone $GCP_ZONE \
--cluster $GCP_CLUSTER [--num-nodes 1 --min-nodes 0 --max-nodes 5 \
--enable-autoscaling]

# hook up kubectl to our cluster
gcloud container clusters get-credentials $GCP_CLUSTER --region=$GCP_ZONE

# install NVidia drivers
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

# Build our container image
docker build -t bert-as-service -f ./docker/Dockerfile .
docker tag bert-as-service gcr.io/$GCP_PROJECT/bert-as-service
docker push gcr.io/$GCP_PROJECT/bert-as-service

# Reserve a global IP address for our bert service
gcloud compute addresses create bert-ip --global
gcloud compute addresses describe bert-ip

