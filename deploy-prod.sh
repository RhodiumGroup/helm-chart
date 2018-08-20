#!/usr/bin/env bash

set -e

CLUSTER_NAME=jhub-cluster

./gcloud-sdk-configure.sh

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID

helm upgrade --dry-run jhub-cluster rhg-hub -f jupyter-config.yml \
    --set jupyterhub.proxy.service.loadBalancerIP=$LOAD_BALANCER_IP_DEPLOY \
    --set jupyterhub.proxy.https.hosts={$DOMAIN_DEPLOY} \
    --set jupyterhub.proxy.secretToken="$PROXY_SECRET_TOKEN_DEPLOY" \
    --set jupyterhub.auth.github.clientId="$GITHUB_CLIENT_ID_DEPLOY" \
    --set jupyterhub.auth.github.clientSecret="$GITHUB_CLIENT_SECRET_DEPLOY" \
    --set jupyterhub.auth.github.callbackUrl="https://${DOMAIN_DEPLOY}/hub/oauth_callback"