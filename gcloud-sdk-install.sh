#!/usr/bin/env bash

set -e

curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-212.0.0-linux-x86_64.tar.gz > google-cloud-sdk-212.0.0-linux-x86_64.tar.gz
tar zxvf google-cloud-sdk-212.0.0-linux-x86_64.tar.gz google-coud-sdk
bash google-cloud-sdk/install.sh --disable-prompts