#!/bin/bash

#set -eu
#set -x

set -e

openssl aes-256-cbc -K $encrypted_19fb998dc11c_key -iv $encrypted_19fb998dc11c_iv -in github_deploy_key.enc -out github_deploy_key -d
chmod 0600 github_deploy_key

helm init --client-only
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

helm dependency update rhg-hub

export GIT_SSH_COMMAND="ssh -i ${PWD}/github_deploy_key" 

chartpress --commit-range ${TRAVIS_COMMIT_RANGE} --publish-chart
# git diff
