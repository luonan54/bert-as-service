#!/bin/bash

FILE=./docker/Dockerfile
if [ ! -f "$FILE" ]; then
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
# 4. Create a new project and enable billing,
#    settting GCP_PROJECT below.
# https://console.cloud.google.com/cloud-resource-manager

# Name of your GCP project for billing, etc.
export GCP_PROJECT=jsp-bert
export GCP_ZONE=us-east1-c
export GCP_CLUSTER=bert-cluster

#
# Point gcloud to our new project
#
echo "Pointing gcloud to $GCP_PROJECT"
gcloud config set project $GCP_PROJECT

#
# Required API access (sync)
#
echo "Enabling APIs"
echo "...Identity"
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
echo "...Compute & Storage"
gcloud services enable compute.googleapis.com
gcloud services enable storage-component.googleapis.com
echo "...Kubernetes"
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable containeranalysis.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
echo "...Clusters"
gcloud services enable replicapool.googleapis.com
gcloud services enable replicapoolupdater.googleapis.com
#
# Optional API access (async)
#
echo "...AI Platform"
gcloud services enable bigquery.googleapis.com --async
gcloud services enable language.googleapis.com --async
gcloud services enable tpu.googleapis.com --async
gcloud services enable translate.googleapis.com --async
gcloud services enable videointelligence.googleapis.com --async
gcloud services enable vision.googleapis.com --async
gcloud services enable sheets.googleapis.com --async
gcloud services enable runtimeconfig.googleapis.com --async
gcloud services enable logging.googleapis.com --async
gcloud services enable drive.googleapis.com --async
gcloud services enable file.googleapis.com --async
gcloud services enable kgraph.googleapis.com --async
gcloud services enable kgsearch.googleapis.com --async
gcloud services enable pubsub.googleapis.com --async
gcloud services enable monitoring.googleapis.com --async

#
# Choose your GPU accelerators from the list for your region
#
# gcloud compute accelerator-types list
#
# Then go online and reserve sufficient GPUs of your chosen type in your quota
# https://console.cloud.google.com/iam-admin/quotas
#
export GCP_GPU=nvidia-tesla-k80
export GCP_GPU_COUNT=2
export GCP_GPU_POOL=bert-gpu-pool

# create a cluster to use these GPUs
echo "Creating a GPU node pool"
gcloud container clusters create $GCP_CLUSTER \
--accelerator=type=$GCP_GPU,count=$GCP_GPU_COUNT \
--zone $GCP_ZONE

# create a pool of nodes for the cluster
echo "Creating a GPU cluster"
gcloud container node-pools create $GCP_GPU_POOL \
--accelerator=type=$GCP_GPU,count=$GCP_GPU_COUNT --zone $GCP_ZONE \
--cluster=$GCP_CLUSTER \
--enable-autoscaling --max-nodes=3 --min-nodes=0

# hook up kubectl to our cluster
echo "Enabling kubernetes access"
gcloud container clusters get-credentials $GCP_CLUSTER --region=$GCP_ZONE

# install NVidia drivers
echo "Installing GPU device drivers"
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

# Build our container image
echo "Building docker container for Bert"
gcloud auth configure-docker
docker build -t bert-as-service -f ./docker/Dockerfile .
docker tag bert-as-service gcr.io/$GCP_PROJECT/bert-as-service
docker push gcr.io/$GCP_PROJECT/bert-as-service

# Reserve a global IP address for our bert service
echo "Getting an IP address"
gcloud compute addresses create bert-ip --global
export GCP_BERT_IP=`gcloud compute addresses list | grep bert-ip | awk '{print $2}'`

# Stand up service
echo "Standing up Bert as a service"
kubectl apply -f docker/bert-deployment.yaml
kubectl apply -f docker/bert-as-service.yaml
kubectl apply -f docker/bert-ingress.yaml

# Test service
#
# curl -X POST http://$GCP_BERT_IP/encode \
#  -H 'content-type: application/json' \
#  -d '{"id": 123,"texts": ["hello world"], "is_tokenized": false}'

echo "Bert will be live at $GCP_BERT_IP"
