# Overview

NVIDIA IndeX is a 3D volumetric interactive visualization SDK that allows
scientists and researchers to visualize and interact with massive data sets,
make real-time modifications, and navigate to the most pertinent parts of the
data, all in real-time, to gather better insights faster. IndeX leverages GPU
clusters for scalable, real-time, visualization and computing of multi-valued
volumetric data together with embedded geometry data.

To learn more about NVIDIA IndeX, please go to our [page](https://developer.nvidia.com/index).

This application allows you to run NVIDIA IndeX in a Kubernetes cluster. The
viewer that comes bundled with the IndeX release is used. By default it loads
and shows a demo dataset. TODO: reference. Users can load their own data in
IndeX. This will be desribed in a section below.

The Kubernetes cluster in which the IndeX application is installed requires
having available NVIDIA GPUs for the application to function correctly.

The application can be launched either by "Click to Deploy" directly from the
Google Marketplace or by using the command line. Both ways are covered in this
document.


## Architecture 

![Architecture diagram](resources/nvindex-k8s-app-architecture.png)

The application starts a IndeX cluster instance, which is available on the
exposed viewer service on HTPP and HTTPS. The session is protected by a user
(nvindex) and a password. The password can be entered manually when launching
via CLI or is generated automatically when using the Click To Deploy.

The TLS certificates are generated automatically for "Click to Deploy" (self
signed). When using CLI they have to be provided by the user. More details are
provided in the  [Update your SSL certificate](#update-your-ssl-certificate)
section.

To achieve scaling of large volume data, IndeX runs in a cluster. For a cluster
of N nodes, one of these nodes will have the extra responsibility of serving the
UI, the other nodes will be workers. That means there is 1 viewer and N-1 workers
in a cluster of N nodes. In Kubernetes, this is modeled through 2 deployments:
    - The viewer deployment: which has 1 replica.
    - The worker deployment: which has N-1 replicas.

For a cluster of size 1 (N=1), there will be 1 viewer and 0 workers.

There are 2 ClusterIP services set up for setting up and running the cluster.
For public access, there will be a LoadBalancer service which points to the viewer
pod.

Loading your own data is covered in the [Loading your own data](#loading-your-own-data) section.


# Installation

## Quick Install via Google Cloud Marketplace

For a quick spin of NVIDIA IndeX, you can launch it directly from the Google
Cloud Marketplace. Follow the
[on-screen instructions](https://console.cloud.google.com/marketplace/details/google/nvindex).

Before launching, make sure that you have NVIDIA GPUs available in the cluster.

## Command line instructions

### Prerequisites

You'll need the following tools in your development environment. If you are
using Cloud Shell, `gcloud`, `kubectl`, Docker, and Git are installed in your
environment by default.

-   [gcloud](https://cloud.google.com/sdk/gcloud/)
-   [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
-   [docker](https://docs.docker.com/install/)
-   [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
-   [helm](https://helm.sh/)

Configure `gcloud` as a Docker credential helper:

```shell
gcloud auth configure-docker
```

#### Create a Google Kubernetes Engine cluster

Create a new cluster from the command line:

```shell
export CLUSTER=nvindex-cluster
export ZONE=us-west1-a

gcloud container clusters create "$CLUSTER" --zone "$ZONE"
```

Configure `kubectl` to connect to the new cluster.

```shell
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
```

#### Clone this repo

Clone this repo and the associated tools repo.

```shell
git clone --recursive https://github.com/NVIDIA/nvindex-cloud.git
```

#### Install the Application resource definition

An Application resource is a collection of individual Kubernetes components,
such as Services, Deployments, and so on, that you can manage as a group.

To set up your cluster to understand Application resources, run the following
command:

```shell
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

You need to run this command once.

The Application resource is defined by the
[Kubernetes SIG-apps](https://github.com/kubernetes/community/tree/master/sig-apps)
community. The source code can be found on
[github.com/kubernetes-sigs/application](https://github.com/kubernetes-sigs/application).

### Install the Application

Navigate to the `gcp-marketplace` directory:

```shell
cd gcp-marketplace/
```

### Setting up the Variables

First, set the name and namespace:
```shell
export NAME=my-nvindex-app
export NAMESPACE=default
```

Next, choose the number of nodes and how many GPUs you have allocated in one node:
```shell
export NODE_COUNT=1
export GPU_COUNT=1
```
Note: It is possible to launch the application with 0 gpus, but nothing will be rendered.

A password has to be selected:
```shell
export NVINDEX_PASSWORD=testpassword
```
The user will always be `nvindex`.

Load the default dataset and scene file:

```shell
export NVINDEX_DATA_LOCATION="gs://nvindex-data-samples/supernova_ncsa_small"
export NVINDEX_SCENE_FILE=default-scene.yaml
```

For loading your own dataset, please refer to the [Loading your own data](#loading-your-own-data)
section.

Configure the launcher image:
```shell
export TAG=0.3
export NVINDEX_IMAGE="https://marketplace.gcr.io/nvidia-nvidx/nvindex:${TAG}"
```

Create a new certificate (if you have your own, skip this step:

```shell
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/tls.key \
    -out /tmp/tls.crt \
    -subj "/CN=nginx/O=nginx"

```

Set the `TLS_CERTIFICATE_CRT` and `TLS_CERTIFICATE_KEY` variables to your certificate:

```shell
export TLS_CERTIFICATE_KEY="$(cat /tmp/tls.key | base64)"
export TLS_CERTIFICATE_CRT="$(cat /tmp/tls.crt | base64)"
```

#### Create a namespace in your Kubernetes cluster

If you use a different namespace than `default`, run the command below to create
a new namespace:

```shell
kubectl create namespace "$NAMESPACE"
```

### Expand the manifest template

Use `helm template` to expand the template. We recommend that you save the
expanded manifest file for future updates to the application.

```shell
helm template chart/nvindex \
    --name $NAME \
    --set "name=$NAME" \
    --set "imageNvindex=$NVINDEX_IMAGE" \
    --set "nodeCount=$NODE_COUNT" \
    --set "gpuCount=$GPU_COUNT" \
    --set "tls.base64EncodedPrivateKey=$TLS_CERTIFICATE_KEY" \
    --set "tls.base64EncodedCertificate=$TLS_CERTIFICATE_CRT" \
    --set "viewerGeneratedPassword=$NVINDEX_PASSWORD" \
    --set "dataLocation=$NVINDEX_DATA_LOCATION" \
    > ${NAME}_manifest.yaml
```

#### Apply the Manifest to your Kubernetes Cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```shell
kubectl apply -f "${NAME}_manifest.yaml" --namespace "${NAMESPACE}"
```
Once the deployment is ready, you can proceed to the next section.
Please make sure that the viewer service has a external IP assigned
before proceeding.

#### Connecting to the NVIDIA IndeX viewer

By default, the IndeX viewer is protected by basic HTTP authentication. The
username is `nvindex` and the password is stored in the password secret object.

To connect to the viewer, there are two possibilities:

- Go to the Application section of the Kubernetes cluster. Select the
  application. There you should see the external IP at which the viewer
  is accessible, the username and the password.
  To get the GCP Console URL for your app, run the following command:

   ```shell
        echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${NAME}"
   ```

- Another approach is to get the IP and credentials from the CLI:

    ```shell
        echo "Login: https://"$(kubectl get service/${NAME}-viewer --namespace ${NAMESPACE} --output jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        echo "User: nvindex"
        echo "Password: "$(kubectl get secrets --namespace ${NAMESPACE} ${NAME}-password --output jsonpath='{.data.viewer-password}' | base64 -d -)"
    ```

Both HTTP and HTTPS can be used.

Once logged in, you should see the following page:
![Successful launch](resources/successful_launch.png)

For more info on using the application, please refer to the
[Using NVIDIA IndeX](#using-nvidia-index) section.

### Delete the Application from the Kubernetes Cluster

```shell
kubectl delefe -f "${NAME}_manifest.yaml"
```

# Loading your own Data

If you want to load and visualize your own data, you will have to:

* Upload your data to a Google Storage Bucket.
* Write a scene file describing where your data is located and how it should
  be rendered.
* Upload scene data and meta-data to the same bucket as the data.


## Directory structure

The scene file location must respect a certain directory structure relative to the
selected `dataLocation`. For example, having `gs://your-bucket/root/` set as
`dataLocation`, the directory structure would be:

```
gs://your-bucket/root/example_dataset1/scene/
```

The scene file and metadata must go into `gs://your-bucket/root/example_dataset1/scene`.
The root directory `gs://your-bucket/root` will be copied to the `/scenes`
directory in the container. The application will look into the `/scenes` directory
and scan for first level directories that contain the path `scene/scene.prj` and
that path is a valid scene file config. All the directories matching this
criteria will be shown in the scene selector.

The data directory is not copied inside the container: the IndeX application
reads it directly from the bucket. That also means that the data can be stored
in a different location/bucket.

## Scene file

When loading your own data, a scene configuration is required (`scene.prj`).
This file and it's dependencies (colormaps, xac shaders, etc) have to be
present in the same directory. Note: the data is an exception here, it can
be stored in any path specified in the project file.

A good example of a scene file would be the default scene found
under `gs://nvindex-data-samples/scenessupernova_ncsa_small/scene/scene.prj`.
