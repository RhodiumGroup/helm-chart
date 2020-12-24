#!/usr/bin/env bash

set -e

EMAIL=$(gcloud config get-value account)
PROJECTID=compute-impactlab
REGION=us-west
ZONE=us-west1-a
CLUSTER_NAME=impactlab-hub
DEPLOYMENT_NAME=impactlab-hub
URL=compute.impactlab.org
HELM_SPEC=impactlab-config.yml
NUM_NODES=1
MAX_JUPYTER_NODES=500
MIN_JUPYTER_NODES=0
MAX_DASK_NODES=5000
MIN_DASK_NODES=0
DISK_SIZE=100
NB_MACHINE_TYPE=n1-highmem-8
WORKER_MACHINE_TYPE=n1-highmem-8
PREEMPTIBLE_FLAG=--preemptible


# Start cluster on Google cloud
gcloud container clusters create $CLUSTER_NAME --num-nodes=$NUM_NODES --machine-type=n1-standard-2 --zone=$ZONE --project=$PROJECTID

# get rid of default pool that we don't want
echo; echo deleting default pool
gcloud container node-pools delete default-pool --cluster $CLUSTER_NAME \
  --zone=$ZONE --project=$PROJECTID --quiet

# core-pool
echo; echo creating core pool...
core_machine_type="n1-standard-2"
core_labels="hub.jupyter.org/node-purpose=core"
gcloud container node-pools create core-pool --cluster=${CLUSTER_NAME} \
   --machine-type=${core_machine_type} --zone=${ZONE} --num-nodes=2 \
   --node-labels ${core_labels}

# jupyter-pools
echo; echo creating jupyter pool...
jupyter_taints="hub.jupyter.org_dedicated=user:NoSchedule"
jupyter_labels="hub.jupyter.org/node-purpose=user"
gcloud container node-pools create jupyter-pool --cluster=${CLUSTER_NAME} \
    --machine-type=${NB_MACHINE_TYPE} --disk-type=pd-ssd --zone=${ZONE} \
    --num-nodes=0 --enable-autoscaling --min-nodes=0 \
    --max-nodes=${MAX_JUPYTER_NODES} --node-taints ${jupyter_taints} \
    --node-labels ${jupyter_labels}

# dask-pool
echo; echo creating dask pool...
dask_taints="k8s.dask.org_dedicated=worker:NoSchedule"
dask_labels="k8s.dask.org/node-purpose=worker"
gcloud container node-pools create dask-pool --cluster=${CLUSTER_NAME} \
    --machine-type=${WORKER_MACHINE_TYPE} --disk-type=pd-ssd --zone=${ZONE} \
    --num-nodes=0 --enable-autoscaling --min-nodes=0 \
    --max-nodes=${MAX_DASK_NODES} --node-taints ${dask_taints} \
    --node-labels ${dask_labels} ${PREEMPTIBLE_FLAG}

# make sure you have the credentials for this cluster loaded
echo; echo get credentials for cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE \
  --project $PROJECTID

# #this enables autoscaling of the cluster
# gcloud container node-pools create worker-pool --zone=$ZONE --cluster=$CLUSTER_NAME --machine-type=n1-standard-8 --preemptible --enable-autoscaling --num-nodes=$MIN_WORKER_NODES --max-nodes=$MAX_WORKER_NODES --min-nodes=$MIN_WORKER_NODES --disk-size=50

#this will give you admin access on the cluster
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$EMAIL

echo; echo creating namespace...
kubectl create namespace $DEPLOYMENT_NAME

# Make sure you are in the rhg-hub repo for this:
echo; echo add pangeo repo to cluster...
helm repo add pangeo https://pangeo-data.github.io/helm-chart/
helm repo update

#Install the dask images from helm
## --name and --namespace are arbitary values I use to identify this deployment##
# helm install rhg-hub --name={release} --namespace={deployment_name} -f rhg-hub/values.yml -f rhg-hub/secret.yaml
