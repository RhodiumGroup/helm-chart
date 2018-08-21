#!/usr/bin/env bash

set -e

# gcloud components update --quiet
# gcloud components install kubectl --quiet
gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

helm init --client-only --service-account tiller
helm dependency update rhg-hub
helm repo add https://jupyterhub.github.io/helm-chart/
helm repo add rhg-hub