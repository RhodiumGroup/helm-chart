#!/usr/bin/env bash

set -e

CLUSTER_NAME=test-hub

bash gcloud-sdk-configure.sh

echo "get credentials"
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID

# echo "create clusterrolebinding cluster-admin-binding"
# kubectl create clusterrolebinding travis-cluster-admin-binding --clusterrole=cluster-admin --user=$TRAVIS_SERVICE_ACCOUNT || \
#     kubectl get clusterrolebinding travis-cluster-admin-binding

echo "create tiller"
kubectl --namespace kube-system create sa tiller || kubectl --namespace kube-system get sa tiller

echo "create clusterrolebinding tiller"
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller || kubectl get clusterrolebinding tiller

echo "init"
helm init --service-account tiller --upgrade

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

helm upgrade --install test-hub rhg-hub -f jupyter-config.yml \
    --set jupyterhub.cull.enabled=true \
    --set jupyterhub.proxy.service.loadBalancerIP=$LOAD_BALANCER_IP_TEST \
    --set jupyterhub.proxy.https.hosts={$DOMAIN_TEST} \
    --set jupyterhub.proxy.secretToken="$PROXY_SECRET_TOKEN_TEST" \
    --set jupyterhub.auth.github.clientId="$GITHUB_CLIENT_ID_TEST" \
    --set jupyterhub.auth.github.clientSecret="$GITHUB_CLIENT_SECRET_TEST" \
    --set jupyterhub.auth.github.callbackUrl="https://${DOMAIN_TEST}/hub/oauth_callback"