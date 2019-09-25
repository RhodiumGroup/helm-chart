#!/usr/bin/env bash

set -e

# Make sure you're logged in to gcloud and have the correct permissions
EMAIL=$(gcloud config get-value account)
PROJECTID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
CLUSTER_NAME=test-cluster
DEPLOYMENT_NAME=test-cluster
URL=testing.climate-kube.com
HELM_SPEC=jupyter-config.yml
NUM_NODES=1
MAX_WORKER_NODES=200
MIN_WORKER_NODES=0
DISK_SIZE=100
PREEMPTIBLE_FLAG=
# PREEMPTIBLE_FLAG=--preemptible

# Start cluster on Google cloud
gcloud container clusters create $CLUSTER_NAME --num-nodes=$NUM_NODES --machine-type=n1-standard-2 --zone=$ZONE --project=$PROJECTID --enable-ip-alias

#this enables autoscaling of the cluster
gcloud container node-pools create worker-pool --zone=$ZONE --cluster=$CLUSTER_NAME --machine-type=n1-highmem-8 $PREEMPTIBLE_FLAG --enable-autoscaling --num-nodes=$MIN_WORKER_NODES --max-nodes=$MAX_WORKER_NODES --min-nodes=$MIN_WORKER_NODES --disk-size=$DISK_SIZE

#this will give you admin access on the cluster
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$EMAIL

#we create a service account tiller in the kube-system namespace
#tiller is the server/cluster side tool for helm to install and manage our containers
#This produce a service account names tiller in the kube cluster
kubectl --namespace kube-system create sa tiller

#Give the tiller process cluster-admin status
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

#strangely this allows helm to install tiller into the kubernetes cluster
helm init --service-account tiller

# this patches the security of the deployment so that no other processes in the cluster can access the other pods
kubectl --namespace=kube-system patch deployment tiller-deploy --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

# Make sure you are in the rhg-hub repo
# update the jupyterhub dependency just to check
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm dependency update rhg-hub

# make sure you have the credentials for this cluster loaded
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECTID

# generate a secret token for the cluster
secret_token=$(openssl rand -hex 32)

helm install rhg-hub --name=$DEPLOYMENT_NAME --namespace=$CLUSTER_NAME --timeout 600 -f $HELM_SPEC \
    --set jupyterhub.cull.enabled=true \
    --set jupyterhub.proxy.https.hosts="{${URL}}" \
    --set jupyterhub.proxy.secretToken="${secret_token}" \
    --set jupyterhub.auth.github.clientId="${GITHUB_CLIENT_ID}" \
    --set jupyterhub.auth.github.clientSecret="${GITHUB_SECRET_TOKEN}" \
    --set jupyterhub.auth.github.callbackUrl="https://${URL}/hub/oauth_callback"

echo "waiting for cluster to boot"
sleep 120

EXTERNAL_IP=$(kubectl -n ${CLUSTER_NAME} get service proxy-public -o wide | awk '{print $4}' | tail -n1)

echo "IMPORTANT"
echo "To update the cluster, run the following command. Save this somewhere as you will need the secret tokens:"
echo

echo "helm upgrade ${CLUSTER_NAME} rhg-hub --timeout 600 -f $HELM_SPEC \\"
echo "   --set jupyterhub.cull.enabled=true \\"
echo "   --set jupyterhub.proxy.service.loadBalancerIP=${EXTERNAL_IP} \\"
echo "   --set jupyterhub.proxy.https.hosts=\"{${URL}}\" \\"
echo "   --set jupyterhub.proxy.secretToken=\"${secret_token}\" \\"
echo "   --set jupyterhub.auth.github.clientId=\"<GITHUB_CLIENT_ID>\" \\"
echo "   --set jupyterhub.auth.github.clientSecret=\"<GITHUB_SECRET_TOKEN>\" \\"
echo "   --set jupyterhub.auth.github.callbackUrl=\"https://${URL}/hub/oauth_callback\""


# Complete the installation using the cluster deployment instructions
# https://paper.dropbox.com/doc/Cluster-Deployments--AgOxfFIh7eCjBgsbFjTjjMpOAg-TQN0OpVDCIR3zW5PGJSRf
