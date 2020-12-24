#!/usr/bin/env bash

set -e

# Make sure you're logged in to gcloud and have the correct permissions
EMAIL=$(gcloud config get-value account)
PROJECTID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
CLUSTER_NAME=compute-rhg
DEPLOYMENT_NAME=compute-rhg
URL=testing.climate-kube.com
HELM_SPEC=jupyter-config.yml
NUM_NODES=1
MAX_WORKER_NODES=200
MIN_WORKER_NODES=0
DISK_SIZE=100
NB_MACHINE_TYPE=n1-highmem-8
WORKER_MACHINE_TYPE=n1-highmem-8
# PREEMPTIBLE_FLAG=
PREEMPTIBLE_FLAG=--preemptible

# Start cluster on Google cloud
gcloud container clusters create $CLUSTER_NAME --num-nodes=$NUM_NODES \
  --machine-type=n1-standard-2 --zone=$ZONE --project=$PROJECTID \
  --enable-ip-alias --no-enable-legacy-authorization

# get rid of default pool that we don't want
echo deleting default pool
gcloud container node-pools delete default-pool --cluster $CLUSTER_NAME \
  --zone=$ZONE --project=$PROJECTID --quiet

# core-pool
echo creating core pool...
core_machine_type="n1-standard-2"
core_labels="hub.jupyter.org/node-purpose=core"
gcloud container node-pools create core-pool --cluster=${CLUSTER_NAME} \
 --machine-type=${core_machine_type} --zone=${ZONE} --num-nodes=2 \
 --node-labels ${core_labels}

# jupyter-pools
echo creating jupyter pool...
jupyter_taints="hub.jupyter.org_dedicated=user:NoSchedule"
jupyter_labels="hub.jupyter.org/node-purpose=user"
gcloud container node-pools create jupyter-pool --cluster=${CLUSTER_NAME} \
  --machine-type=${NB_MACHINE_TYPE} --disk-type=pd-ssd --zone=${ZONE} \
  --num-nodes=0 --enable-autoscaling --min-nodes=0 --max-nodes=10 \
  --node-taints ${jupyter_taints} --node-labels ${jupyter_labels}

# dask-pool
echo creating dask pool...
dask_taints="k8s.dask.org_dedicated=worker:NoSchedule"
dask_labels="k8s.dask.org/node-purpose=worker"
gcloud container node-pools create dask-pool --cluster=${CLUSTER_NAME} \
  ${PREEMPTIBLE_FLAG} --machine-type=${WORKER_MACHINE_TYPE} --disk-type=pd-ssd \
  --zone=${ZONE} --num-nodes=0 --enable-autoscaling --min-nodes=0 \
  --max-nodes=${MAX_WORKER_NODES} --node-taints ${dask_taints} \
  --node-labels ${dask_labels}

# make sure you have the credentials for this cluster loaded
echo get credentials for cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE \
  --project $PROJECTID

#this will give you admin access on the cluster
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin --user=$EMAIL

# ############
# ## Only strictly necessary if helm 3 (but ok to do either way)
# create namespace
echo creating namespace...
kubectl create namespace $DEPLOYMENT_NAME
# ############


# # ############
# ## Only necessary if helm 2 (will break otherwise b/c helm 3 has no tiller)
# #Give the tiller process cluster-admin status
# kubectl create serviceaccount tiller --namespace=kube-system
# kubectl create clusterrolebinding tiller --clusterrole cluster-admin \
#   --serviceaccount=kube-system:tiller
#
# #strangely this allows helm to install tiller into the kubernetes cluster
# helm init --service-account tiller
#
# # this patches the security of the deployment so that no other processes in the cluster can access the other pods
# kubectl --namespace=kube-system patch deployment tiller-deploy --type=json \
#   --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'
# # ############

# Make sure you are in the rhg-hub repo for this:
echo add pangeo repo to cluster...
helm repo add pangeo https://pangeo-data.github.io/helm-chart/
helm repo update

# generate a secret token for the cluster
echo generating secret token...
secret_token=$(openssl rand -hex 32)
echo "SECRET_TOKEN=$secret_token"

# secret_token=5486775e2cbb0a533aa81977a4ba9cf9697ba33de12b3f819edeed2596cba820
# secret_token=782d44af360f3d7f41b86a15555f817cd67d1f6e880dff421bf23105c931ea70

## NOTE: you will need to change 600s to 600 in both the install and upgrade commands
## if working with Helm 2
echo installing helm chart...
helm install $DEPLOYMENT_NAME pangeo/pangeo --version 19.09.27-86dd66c  --namespace=$DEPLOYMENT_NAME \
  --timeout 600s -f $HELM_SPEC \
  --set jupyterhub.proxy.https.hosts="{${URL}}" \
  --set jupyterhub.proxy.secretToken="${secret_token}" \
  --set jupyterhub.auth.github.clientId="${GITHUB_CLIENT_ID}" \
  --set jupyterhub.auth.github.clientSecret="${GITHUB_SECRET_TOKEN}" \
  --set jupyterhub.auth.github.callbackUrl="https://${URL}/hub/oauth_callback"

echo "waiting for cluster to boot"
sleep 120

echo "retrieving external IP"
EXTERNAL_IP=$(kubectl -n ${CLUSTER_NAME} get service proxy-public -o wide | awk '{print $4}' | tail -n1)

echo "IMPORTANT"
echo "To update the cluster, run the following command. Save this somewhere as you will need the secret tokens:"
echo

echo "helm upgrade ${DEPLOYMENT_NAME} pangeo/pangeo --version 19.09.27-86dd66c  --timeout 600s --namespace=${DEPLOYMENT_NAME} -f $HELM_SPEC \\"
echo "   --set jupyterhub.proxy.service.loadBalancerIP=${EXTERNAL_IP} \\"
echo "   --set jupyterhub.proxy.https.hosts=\"{${URL}}\" \\"
echo "   --set jupyterhub.proxy.secretToken=\"${secret_token}\" \\"
echo "   --set jupyterhub.auth.github.clientId=\"<GITHUB_CLIENT_ID>\" \\"
echo "   --set jupyterhub.auth.github.clientSecret=\"<GITHUB_SECRET_TOKEN>\" \\"
echo "   --set jupyterhub.auth.github.callbackUrl=\"https://${URL}/hub/oauth_callback\""


# Complete the installation using the cluster deployment instructions
# https://paper.dropbox.com/doc/Cluster-Deployments--AgOxfFIh7eCjBgsbFjTjjMpOAg-TQN0OpVDCIR3zW5PGJSRf
