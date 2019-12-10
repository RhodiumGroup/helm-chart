#!/usr/bin/#!/usr/bin/env bash

project=rhg-project-1
zone=us-west1-a
namespace=rhodium-jupyter

# create a google compute instance in the same zone & project as the
# cluster. the below commands assume you're running ubuntu... so... that's
# preferable
instance=mikes-crazy-solo-instance-please-dont-let-this-run-past-jan2020

gcs_backup_dir=gs://compute-rhg-backups/test-manual-backups-$(date +%F)

token_file=rhg-project-1-compute-rhg-backup-manager.json

# copy our gcloud service account token to the instance
gcloud compute scp -q $token_file $instance:~/ > /dev/null

gcloud compute ssh --zone $zone $instance -- bash -c "echo && "\
"sudo apt-get update -qq > /dev/null; "\
"sudo apt-get --yes -qq install --upgrade apt-utils kubectl google-cloud-sdk > /dev/null 2>&1; "\
"gcloud auth activate-service-account -q --key-file ~/$token_file >/dev/null 2>&1; " > /dev/null 2>&1

in_list() {
    local search="$1"
    shift
    local list=("$@")
    for file in "${list[@]}" ; do
        [[ $file == $search ]] && return 0
    done
    return 1
}

# compile a list of cluster users
claims=$(kubectl -n $namespace get PersistentVolumes | grep claim- | awk '{print $6}')

# get a list of currently running pods
running_pods=$(for pod in $(kubectl -n $namespace get pods | grep jupyter- | awk '{print $1}'); do echo ${pod/jupyter-/}; done)

cluster_users=$(
    for claim in $claims; do
        claim_user=${claim#*/};
        cluster_user=${claim_user/claim-/};
        if ! in_list $cluster_user $running_pods; then
            echo $cluster_user;
        fi
    done
);

# cluster_users=$(for user in mattgoldklang smohan moonlimb; do echo $user; done)

# enumerate counter
i=0

# loop over our user list
for cluster_user in $cluster_users; do

    # get the GKE persistent volume claim and associated GCE Volume ID
    claim=$(kubectl -n $namespace get PersistentVolumes | grep "$namespace/claim-$cluster_user\ " | awk '{print $1}')
    volume=$(gcloud compute disks list --filter="zone:($zone) name:($claim)" | grep $claim | awk '{print $1}');

    # attach the volume to the instance
    gcloud compute instances attach-disk -q $instance --disk $volume --zone $zone > /dev/null

    # mount the volume and copy the data to GCS
    gcloud compute ssh --zone $zone $instance -- bash -c "echo &&\
    sudo mkdir /mnt/$cluster_user && \
    sudo mount /dev/sdb /mnt/$cluster_user && \
    gsutil -m cp -r /mnt/$cluster_user $gcs_backup_dir/$cluster_user/home/jovyan; \
    sudo umount /mnt/$cluster_user && \
    sudo rm -r /mnt/$cluster_user"

    # detach the volume from the instance
    gcloud compute instances detach-disk -q $instance --disk $volume --zone $zone > /dev/null

    echo $i
    i=$((i+1));

done
# done | tqdm --total $(echo "$cluster_users" | wc -w) > /dev/null

# remove the credentials from the temporary instance
gcloud compute ssh --zone $zone $instance -- bash -c "echo && "\
"gcloud auth revoke compute-rhg-backup-manager@rhg-project-1.iam.gserviceaccount.com >/dev/null 2>&1; "\
"rm -f ~/$token_file; " > /dev/null 2>&1
