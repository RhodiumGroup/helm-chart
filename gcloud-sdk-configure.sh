#!/usr/bin/env bash

set -e

# gcloud components update --quiet
# gcloud components install kubectl --quiet
gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

helm init --client-only --service-account tiller
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
helm dependency update rhg-hub