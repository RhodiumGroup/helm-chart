#!/usr/bin/env bash

set -e

CLUSTER_NAME=jhub-cluster

bash gcloud-sdk-configure.sh

echo "get credentials"
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID

# echo "create clusterrolebinding cluster-admin-binding"
kubectl create clusterrolebinding travis-cluster-admin-binding --clusterrole=cluster-admin --user=$TRAVIS_SERVICE_ACCOUNT || \
    kubectl get clusterrolebinding travis-cluster-admin-binding

# echo "create tiller"
# kubectl --namespace kube-system create sa tiller

# echo "create clusterrolebinding tiller"
# kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

echo "init"
helm init --client-only --service-account tiller

# echo "patch deployment"
# kubectl --namespace=kube-system patch deployment tiller-deploy \
#     --type=json \
#     --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

echo "repo add jupyterhub"
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/

echo "repo add rhg-hub"
helm repo add rhg-hub https://rhodiumgroup.github.io/helm-chart/

echo "dependency update rhg-hub"
helm dependency update rhg-hub

echo "repo update"
helm repo update

helm upgrade --dry-run jhub-cluster rhg-hub -f jupyter-config.yml \
    --set jupyterhub.proxy.service.loadBalancerIP=$LOAD_BALANCER_IP_DEPLOY \
    --set jupyterhub.proxy.https.hosts={$DOMAIN_DEPLOY} \
    --set jupyterhub.proxy.secretToken="$PROXY_SECRET_TOKEN_DEPLOY" \
    --set jupyterhub.auth.github.clientId="$GITHUB_CLIENT_ID_DEPLOY" \
    --set jupyterhub.auth.github.clientSecret="$GITHUB_CLIENT_SECRET_DEPLOY" \
    --set jupyterhub.auth.github.callbackUrl="https://${DOMAIN_DEPLOY}/hub/oauth_callback"