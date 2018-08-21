#!/usr/bin/env bash

set -e

# gcloud components update --quiet
# gcloud components install kubectl --quiet
gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$EMAIL
kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

export HELM_HOST=localhost:44134
helm init --client-only --service-account tiller
kubectl --namespace=kube-system patch deployment tiller-deploy \
    --type=json \
    --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo add rhg-hub https://rhodiumgroup.github.io/helm-chart/
helm dependency update rhg-hub
helm repo update