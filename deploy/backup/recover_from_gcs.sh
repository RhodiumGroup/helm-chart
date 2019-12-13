#!/usr/bin/#!/usr/bin/env bash

project=rhg-project-1
zone=us-west1-a
namespace=compute-rhg

# not true for rhg-hub or test-hub. be warned.
cluster=$namespace

gcloud container clusters get-credentials $cluster --zone $zone --project $project

gcs_backup_dir=gs://compute-rhg-backups/test-manual-backups-2019-12-07

token_file=rhg-project-1-compute-rhg-backup-manager.json

# active_users=$(for pod in $(kubectl -n $namespace get pods | grep jupyter- | awk '{print $1}'); do user=${pod/jupyter-/}; echo $user; done);
active_users=$(for user in delgadom; do echo $user; done);

i=0;
for cluster_user in $active_users; do
    kubectl cp -n $namespace $token_file jupyter-$cluster_user:/home/jovyan/;
    kubectl exec jupyter-$cluster_user --namespace $namespace -- bash -c "\
    sudo apt-get update -qq > /dev/null; \
    sudo apt-get --yes -qq install --upgrade apt-utils kubectl google-cloud-sdk > /dev/null 2>&1; \
    gcloud auth activate-service-account -q --key-file /home/jovyan/$token_file >/dev/null 2>&1; \
    gsutil -m -q cp -r $gcs_backup_dir/$cluster_user/home/jovyan/ /home/ >/dev/null; \
    gcloud auth revoke compute-rhg-backup-manager@rhg-project-1.iam.gserviceaccount.com >/dev/null 2>&1; \
    rm -f /home/jovyan/$token_file";
    echo $((i++));
done | tqdm --total $(echo $active_users | wc -w) > /dev/null
