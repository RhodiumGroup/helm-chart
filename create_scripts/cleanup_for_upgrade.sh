# The script will delete resources that were meant to be temporary
# The bug that caused this is fixed in version 0.7b1 of the Helm chart
NAMESPACE=test-cluster

resource_types="daemonset,serviceaccount,clusterrole,clusterrolebinding,job"
for bad_resource in $(kubectl get $resource_types --namespace $NAMESPACE | grep '/pre-pull' | awk '{print $1}');
do
    kubectl delete $bad_resource --namespace $NAMESPACE --now
done

kubectl delete $resource_types --selector hub.jupyter.org/deletable=true --namespace $NAMESPACE --now
