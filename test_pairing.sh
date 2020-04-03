#!/usr/bin/env bash

set -e

NOTEBOOK_IMAGE=$(python -c "import yaml; f = open('jupyter-config.yml'); spec = yaml.safe_load(f.read()); print(spec['jupyterhub']['singleuser']['profileList'][0]['kubespawner_override']['image']);")

echo "pull notebook $NOTEBOOK_IMAGE"
docker pull $NOTEBOOK_IMAGE

echo "start notebook image"
docker run -d --name notebook -t $NOTEBOOK_IMAGE /bin/bash

echo "copy worker template from running notebook"
docker cp notebook:/pre-home/worker-template.yml worker-template.yml

WORKER_IMAGE=$(python -c "import yaml; f = open('worker-template.yml'); spec = yaml.load(f.read()); print(spec['spec']['containers'][0]['image']);")
echo "retrieved worker image $WORKER_IMAGE from notebook worker-template"

echo "shut down notebook"
docker stop notebook
docker rm notebook

echo "pull worker $WORKER_IMAGE"
docker pull $WORKER_IMAGE

echo "start scheduler in notebook server"
docker run --net="host" -d $NOTEBOOK_IMAGE start.sh dask-scheduler --port 8786 --bokeh-port 8787 &

echo "start worker"
docker run --net="host" -d $WORKER_IMAGE dask-worker 127.0.0.1:8786 --worker-port 8666 --nanny-port 8785 &

echo "notebook server for user connection"
docker create --name tester --net="host" $NOTEBOOK_IMAGE

echo "copy test suite to test image"
docker cp notebook_test.py tester:/usr/bin

echo "start the tester notebook"
docker start tester

echo "run test suite"
docker exec tester python /usr/bin/notebook_test.py

echo "closing containers"
docker stop $(docker ps -q);
docker rm $(docker ps --all -q);

echo "done"
