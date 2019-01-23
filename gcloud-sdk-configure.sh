#!/usr/bin/env bash

set -e

# gcloud components update --quiet
# gcloud components install kubectl --quiet

echo "activate-service-account"
gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"

echo "config set project"
gcloud config set project $PROJECT_ID

echo "config set compute/zones"
gcloud config set compute/zone $ZONE
