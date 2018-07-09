[![build status](https://travis-ci.org/RhodiumGroup/docker_images.svg?branch=master)](https://travis-ci.org/RhodiumGroup/docker_images) [![notebook pulls](https://img.shields.io/docker/pulls/rhodium/notebook.svg?label=notebook%20pulls)](https://hub.docker.com/r/rhodium/notebook/) [![worker pulls](https://img.shields.io/docker/pulls/rhodium/worker.svg?label=worker%20pulls)](https://hub.docker.com/r/rhodium/worker/)


Docker images and Helm Charts for Rhodium Group Jupyterhub Deployments


To make updates to the docker images and helm charts

1. Clone it to your local machine
2. Create a new branch
3. Make edits to the dockerfiles in the `worker` and `notebook` directories.  
4. Commit your changes
5. Tag your image with `python bump.py`
6. Push to github and make a pull request to master
7. If your build passes on Travis, we'll merge it and it will deploy to dockerhub and our [helm chart repo](https://rhodiumgroup.github.io/helm-chart/)

Any questions please email jsimcock@rhg.com

