NOTEBOOK_IMAGE=$(python -c "import yaml; f = open('jupyter-config.yml'); spec = yaml.load(f.read()); print('{}:{}'.format(spec['jupyterhub']['singleuser']['image']['name'], spec['jupyterhub']['singleuser']['image']['tag']));")
docker pull $NOTEBOOK_IMAGE
docker run -d --name notebook -t $NOTEBOOK_IMAGE
docker cp notebook:/pre-home/worker-template.yml worker-template.yml
WORKER_IMAGE=$(python -c "import yaml; f = open('worker-template.yml'); spec = yaml.load(f.read()); print(spec['spec']['containers'][0]['image']);")
docker stop notebook
docker rm notebook
docker pull $WORKER_IMAGE
# start scheduler in notebook server
docker run -p 127.0.0.1:8888:8888 -p 127.0.0.1:8786:8786 -p 127.0.0.1:8787:8787 -d $NOTEBOOK_IMAGE start.sh /opt/conda/bin/dask-scheduler --port 8786 --bokeh-port 8787 &
# start worker
docker run -p 127.0.0.1:8666:8666 -p 127.0.0.1:8785:8785 --net="host" -d $WORKER_IMAGE /opt/conda/bin/dask-worker localhost:8786 --worker-port 8666 --nanny-port 8785 &
# notebook server for user connection
docker create --name tester -p 127.0.0.1:8765:8765 $NOTEBOOK_IMAGE
# copy test suite to test image
docker cp notebook_test.py tester:/usr/bin
# start the tester notebook
docker start tester
# run test suite
docker exec tester python /usr/bin/notebook_test.py