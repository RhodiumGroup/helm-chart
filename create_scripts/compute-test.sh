#!/usr/bin/env bash

set -e

# Make sure you're logged in to gcloud and have the correct permissions
EMAIL=$(gcloud config get-value account)
PROJECTID=$(gcloud config get-value project)
ZONE=$(gcloud config get-value compute/zone)
CLUSTER_NAME=test-hub
NUM_NODES=1
MAX_WORKER_NODES=1000
MIN_WORKER_NODES=0

# Start cluster on Google cloud
gcloud container clusters create $CLUSTER_NAME --num-nodes=$NUM_NODES --machine-type=n1-standard-2 --zone=$ZONE --project=$PROJECTID

#this enables autoscaling of the cluster
gcloud container node-pools create worker-pool --zone=$ZONE --cluster=$CLUSTER_NAME --machine-type=n1-highmem-8 --preemptible --enable-autoscaling --num-nodes=$MIN_WORKER_NODES --max-nodes=$MAX_WORKER_NODES --min-nodes=$MIN_WORKER_NODES --disk-size=100

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
helm dependency update rhg-hub

#Install the dask images from helm
## --name and --namespace are arbitary values I use to identify this deployment##
# helm install rhg-hub --name={release} --namespace={deployment_name} -f rhg-hub/values.yml -f rhg-hub/secret.yaml
# helm install rhg-hub --name=test-cluster --namespace=test-hub

# Complete the installation using the cluster deployment instructions, but
# change "upgrade" to "install":
# https://paper.dropbox.com/doc/Cluster-Deployments--AgOxfFIh7eCjBgsbFjTjjMpOAg-TQN0OpVDCIR3zW5PGJSRf
