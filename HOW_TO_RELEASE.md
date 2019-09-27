# Releasing 

## Build a paired set of docker notebook+worker images.

This is the minimum that’s required - if you want other images then make sure you have working notebook and worker images as well as the ones you want. The helm chart only cares about the notebook image, but it’s important to keep these all in sync so we build them together.

To do this, either push to dev or modify travis so your branch will deploy to docker

Once this is done, find your image’s tag. This will look like a commit hash. If you’re deploying to compute.rhg or compute.impactlab, this is worthy of a version bump. In this case, use the version tag. Don’t use latest or dev, as docker may fail to update the image when you push a change.

## Upgrade the notebook image used in the helm chart

Clone the [helm chart repo](https://github.com/RhodiumGroup/helm-chart/). Create a new branch for your modification.

Modify the notebook tag deployed by changing the `jupyterhub.singleuser.image.tag` field in `jupyter-config.yml` and `impactlab-config.yml`. We test using the former spec, so impactlab-config is only used for the compute.impactlab.org deployment, but it’s good practice to keep these in sync, and you’ll need to make sure they’re in sync before your PR gets merged and deployed to the production servers.

## Push your changes to your new branch on github

We test the pairing of the core notebook & worker on travis. The notebook image you specify in `jupyter-config.yml` will be pulled and booted in the travis environment. Inside the notebook image, the `worker-template.yml` file includes the name & tag of the paired worker image it was built with (identified either by commit hash or release tag) (we [sneak this in](https://github.com/RhodiumGroup/docker_images/blob/master/.travis.yml#L12) during the docker_image travis build process). Testing this pairing by pushing to github will give you another check to make sure that your build will deploy successfully.
 
## Choose a cluster to target for your deployment test

Cluster updates follow the following path on their way to deployment:

Step 1: Image build test

Commits to RhodiumGroup/docker_images trigger travis to build & test notebook & worker images before deploying to dockerhub

Step 2: Image pairing test

Commits to RhodiumGroup/helm-chart trigger travis to test the notebook/worker pairing. This pairing tests communication between the notebook and worker using a dask localcluster hosted by the notebook that the worker connects to. This does not test worker scaling with dask_kubernetes, data storage/access with fuse or google.cloud.storage, or any interface/visualization features, but can check a range of standard workflows.

This test suite could really use some TLC, as it’s quite a powerful feature of our workflow but currently includes only very basic tests.

Step 3: Bleeding-edge deployment

Deploy your cluster to a bleeding-edge cluster:

  * test-cluster (at testing.cliamte-kube.com)
  * test-cluster-2 (at test2.climate-kube.com)

These two clusters are used the same way and simply provide additional testing capacity. Deployments should be iterated on these clusters, ironing out any issues the developer can identify to make sure the next phase goes smoothly.

This is usually the longest stage of the deployment pipeline, and often involves going back to the drawing board and making bug fixes to your docker images. Some important things to check:

* Successful worker spinup & shutdown. Make sure both manual & automatic scaling results in pods being created & destroyed, and that 


Step 4: Canary deployment

Once all known bugs have been 
