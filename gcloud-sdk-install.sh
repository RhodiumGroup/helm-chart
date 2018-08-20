#!/usr/bin/env bash

set -e

curl https://sdk.cloud.google.com/ > install_google_cloud.sh
bash install_google_cloud.sh --disable-prompts