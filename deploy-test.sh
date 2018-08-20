#!/usr/bin/env bash

set -e

CLUSTER_NAME=test-hub

./gcloud-sdk-configure.sh

helm upgrade --dry-run test-hub rhg-hub -f jupyter-config.yml \
    --set jupyterhub.cull.enabled=true \
    --set jupyterhub.proxy.service.loadBalancerIP=$LOAD_BALANCER_IP_TEST \
    --set jupyterhub.proxy.https.hosts={$DOMAIN_TEST} \
    --set jupyterhub.proxy.secretToken="$PROXY_SECRET_TOKEN_TEST" \
    --set jupyterhub.auth.github.clientId="$GITHUB_CLIENT_ID_TEST" \
    --set jupyterhub.auth.github.clientSecret="$GITHUB_CLIENT_SECRET_TEST" \
    --set jupyterhub.auth.github.callbackUrl="https://${DOMAIN_TEST}/hub/oauth_callback"