#!/usr/bin/env bash

# You must set GITHUB_CLIENT_ID and GITHUB_SECRET_TOKEN env variables before running

set -e

# Make sure you're logged in to gcloud and have the correct permissions
EMAIL=$(gcloud config get-value account)
PROJECTID=$(gcloud config get-value project)
ZONE=us-west1-b
CLUSTER_NAME=adrastea
DEPLOYMENT_NAME=adrastea
URL=adrastea.climate-kube.com
HELM_SPEC=jupyter-config.yml
NUM_NODES=1
MAX_WORKER_NODES=5000
MIN_WORKER_NODES=0
DISK_SIZE=100
DISK_TYPE=pd-ssd
NB_MACHINE_TYPE=n1-highmem-8
WORKER_MACHINE_TYPE=n1-highmem-8
CORE_MACHINE_TYPE=n1-standard-2
# PREEMPTIBLE_FLAG=
PREEMPTIBLE_FLAG=--preemptible

# # Start cluster on Google cloud
# gcloud container clusters create $CLUSTER_NAME \
#   --num-nodes=$NUM_NODES \
#   --machine-type=n1-standard-2 \
#   --zone=$ZONE \
#   --project=$PROJECTID \
#   --enable-ip-alias \
#   --no-enable-basic-auth \
#   --disk-type=${DISK_TYPE} \
#   --enable-network-policy

# set default cluster for future commands
gcloud config set container/cluster $CLUSTER_NAME

# get rid of default pool that we don't want
gcloud container node-pools delete default-pool --quiet

# core-pool
core_machine_type="n1-standard-2"
core_labels="hub.jupyter.org/node-purpose=core"
gcloud container node-pools create core-pool \
 --machine-type=${core_machine_type} \
 --zone=${ZONE} \
 --num-nodes=2 \
 --node-labels ${core_labels} \
 --metadata disable-legacy-endpoints=true

# jupyter-pools
jupyter_taints="hub.jupyter.org_dedicated=user:NoSchedule"
jupyter_labels="hub.jupyter.org/node-purpose=user"
gcloud container node-pools create jupyter-pool \
  --machine-type=${NB_MACHINE_TYPE} \
  --disk-type=${DISK_TYPE} \
  --zone=${ZONE} \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10 \
  --node-taints ${jupyter_taints} \
  --node-labels ${jupyter_labels} \
  --metadata disable-legacy-endpoints=true

# dask-pool
dask_taints="k8s.dask.org_dedicated=worker:NoSchedule"
dask_labels="k8s.dask.org/node-purpose=worker"
gcloud container node-pools create dask-pool \
  ${PREEMPTIBLE_FLAG} \
  --machine-type=${WORKER_MACHINE_TYPE} \
  --disk-type=pd-ssd \
  --zone=$ZONE \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=${MAX_WORKER_NODES} \
  --node-taints ${dask_taints} \
  --node-labels ${dask_labels} \
  --metadata disable-legacy-endpoints=true

# make sure you have the credentials for this cluster loaded
gcloud container clusters get-credentials $CLUSTER_NAME \
--zone $ZONE \
--project $PROJECTID

#this will give you admin access on the cluster
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=$EMAIL

# create namespace
kubectl create namespace $DEPLOYMENT_NAME

# Make sure you are in the rhg-hub repo for this:
helm repo add dask https://helm.dask.org
helm repo update

# generate a secret token for the cluster
secret_token=$(openssl rand -hex 32)
secret_token2=$(openssl rand -hex 32)

## NOTE: you will need to change 600s to 600 in both the install and upgrade commands
## if working with Helm 2
helm install $DEPLOYMENT_NAME dask/daskhub \
  --namespace=$DEPLOYMENT_NAME \
  --timeout 600s -f $HELM_SPEC \
  --wait \
  --render-subchart-notes \
  --set jupyterhub.proxy.https.hosts="{${URL}}" \
  --set jupyterhub.proxy.secretToken="${secret_token}" \
  --set jupyterhub.auth.github.clientId="${GITHUB_CLIENT_ID}" \
  --set jupyterhub.auth.github.clientSecret="${GITHUB_SECRET_TOKEN}" \
  --set jupyterhub.hub.services.dask-gateway.apiToken="${secret_token2}" \
  --set dask-gateway.gateway.auth.jupyterhub.apiToken="${secret_token2}" \
  --set jupyterhub.auth.github.callbackUrl="https://${URL}/hub/oauth_callback"

EXTERNAL_IP=$(kubectl -n ${CLUSTER_NAME} get service proxy-public -o wide | awk '{print $4}' | tail -n1)

echo "IMPORTANT"
echo "To update the cluster, run the following command. Save this somewhere as you will need the secret tokens:"
echo

echo "helm upgrade ${DEPLOYMENT_NAME} dask/daskhub \\"
echo "   --timeout 600s \\"
echo "   --namespace=${DEPLOYMENT_NAME} \\"
echo "   -f $HELM_SPEC \\"
echo "   --set jupyterhub.proxy.service.loadBalancerIP=${EXTERNAL_IP} \\"
echo "   --set jupyterhub.proxy.https.hosts=\"{${URL}}\" \\"
echo "   --set jupyterhub.proxy.secretToken=\"${secret_token}\" \\"
echo "   --set jupyterhub.auth.github.clientId=\"<GITHUB_CLIENT_ID>\" \\"
echo "   --set jupyterhub.auth.github.clientSecret=\"<GITHUB_SECRET_TOKEN>\" \\"
echo "   --set jupyterhub.hub.services.dask-gateway.apiToken=\"${secret_token2}\" \\"
echo "   --set dask-gateway.gateway.auth.jupyterhub.apiToken=\"${secret_token2}\" \\"
echo "   --set jupyterhub.auth.github.callbackUrl=\"https://${URL}/hub/oauth_callback\" \\"
echo "   --wait \\"
echo "   --render-subchart-notes \\"
echo "   --cleanup-on-fail"


# Complete the installation using the cluster deployment instructions
# https://paper.dropbox.com/doc/Cluster-Deployments--AgOxfFIh7eCjBgsbFjTjjMpOAg-TQN0OpVDCIR3zW5PGJSRf
