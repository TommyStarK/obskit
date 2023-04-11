# obskit

`obskit` is an attempt to ease the setup of an observability stack running on Kubernetes. It is relying exclusively upon [Grafana's open source projects](https://github.com/grafana), the `LGTM` stack. A tiny script `obskit` within this repo will help to achieve that.

The idea is to have an ad-hoc, reproducible, configurable, extendable way of deploying Grafana's tools in a dedicated cluster for observability. It also helps to deploy the agent on the Kubernetes cluster(s) of your choice, giving you the freedom to choose which application(s) you want to monitor.

The stack is deployed in `microservices` mode. You will find a [section](https://github.com/TommyStarK/obskit#production-readiness) gathering the different links I found useful to decide how to properly deploy this stack to be used in production and meet my needs/constraints. It covers things like capacity planning, pod resources, data persistence, using Ingress, autoscaling, rolling updates and self-monitoring.

The `LGTM` stack:

- [Loki](https://github.com/grafana/loki)
- [Grafana](https://github.com/grafana/grafana)
- [Tempo](https://github.com/grafana/tempo)
- [Mimir](https://github.com/grafana/mimir)
- Telemetry agent:
	- [Agent](https://github.com/grafana/agent)

:warning: I am neither a Grafana employee nor a Kubernetes guru. You should first fork this repository, review the code, and remove things you don’t want or need. Don’t blindly use my configs unless you know what that entails.

## Prerequisites

- [Bash](https://www.gnu.org/software/bash/)
- [Helm](https://helm.sh/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

## Usage

Feel free to edit the [config files](https://github.com/TommyStarK/obskit/tree/main/config) to fit to your needs.
You might want to update the [agent config](https://github.com/TommyStarK/obskit/blob/main/toolkit/agent/templates/secret/agent.yaml) as well as [Grafana config](https://github.com/TommyStarK/obskit/tree/main/toolkit/grafana/templates/configmap) in order to highlight additional metrics or any insight you may need.


```bash
❯ ./obskit -h
obskit - Observability as a service toolkit for Kubernetes

Usage: 	obskit [options] --deploy-agent
	obskit [options] --render-template
	obskit [options] --setup-cluster
	obskit [options] --delete

Options:
	-c | --cluster    Specify Kubernetes cluster
	-t | --target     Grafana tool (agent,grafana,loki,mimir,tempo)

Examples:
	# Render templates for Grafana and Tempo
	./obskit --render-template --target=grafana,tempo

	# Deploy Grafana Agent to minikube
	./obskit --deploy-agent --cluster=minikube

	# Deploy the LGTM stack to Kubernetes cluster 'demo'
	./obskit --setup-cluster --cluster=demo

	# Deploy Loki and Mimir to Kubernetes cluster 'demo'
	./obskit --setup-cluster --cluster=demo --target=loki,mimir

	# Delete Loki and Mimir from Kubernetes cluster 'demo'
	./obskit --delete --cluster=demo --target=loki,mimir

```

## Demo using GKE + Minikube

To demonstrate how to use `obskit`, we will use [GKE](https://cloud.google.com/kubernetes-engine) and [minikube](https://minikube.sigs.k8s.io/docs/). Feel free to use the cloud provider or whatever setup you want. Be aware of the required changes if you do so.

For demo purposes, the `LGTM` stack will be deployed **without** enabling data persistence, auto scaling, pod resources, ingress. See the [production readiness](https://github.com/TommyStarK/obskit#production-readiness) section for more details regarding these topics.

### Setup

First step, let's create the buckets used as long term storage by `Loki`, `Mimir` and `Tempo`:

```bash
❯ gcloud storage buckets create gs://obskit-loki/ --uniform-bucket-level-access --location=eu
❯ gcloud storage buckets create gs://obskit-mimir/ --uniform-bucket-level-access --location=eu
❯ gcloud storage buckets create gs://obskit-tempo/ --uniform-bucket-level-access --location=eu
```

Once it's done, retrieve the access key, secret access key and the endpoint for being able to connect to your buckets.
Update the [Loki](https://github.com/TommyStarK/obskit/blob/main/config/loki.yaml#L61-L65), [Mimir](https://github.com/TommyStarK/obskit/blob/main/config/mimir.yaml#L39-L44) and [Tempo](https://github.com/TommyStarK/obskit/blob/main/config/tempo.yaml#L38-L42) config file with the credentials so they can access their own storage.

Now we can create the dedicated cluster for observability:

```bash
❯ gcloud container clusters create obskit-cluster --machine-type e2-standard-8
```

Once the cluster is ready, create the `obskit` namespace:

```bash
❯ kubectl create namespace obskit
```

For demo purposes we will use `minikube` to deploy the agent:

```bash
❯ minikube start
```

Let's setup the `LGTM` stack to the « observability » dedicated cluster:

```bash
❯ ./obskit --setup-cluster --cluster=<CLUSTER_NAME>
```

Before deploying the telemetry agent we need to retrieve the endpoints to communicate with `Loki`, `Mimir` and `Tempo`:

```bash
❯ kubectl get -n obskit service loki-distributed-gateway| awk 'NR>1 {print $4}'
34.90.138.39

❯ kubectl get -n obskit service mimir-distributed-gateway| awk 'NR>1 {print $4}'
34.90.210.130

❯ kubectl get -n obskit service tempo-distributed-gateway| awk 'NR>1 {print $4}'
35.204.77.27
```

Update the [agent remotes URLs](https://github.com/TommyStarK/obskit/blob/main/config/agent.yaml#L12-L19) with the according values.
> If HTTPS is not enabled, port is 80

Next, deploy the telemetry agent to `minikube`:

```bash
❯ ./obskit --deploy-agent --cluster=minikube
```

Finally, for demo purposes you can deploy a log generator and [xk6-tracing](https://github.com/grafana/xk6-distributed-tracing) to minikube:

```bash
❯ kubectl apply -f demo/log-gen.yaml
❯ kubectl apply -f demo/xk6-tracing.yaml
```

That's it, run the following commmand to access `Grafana` and enjoy :smile:

```bash
❯ open "http://$(kubectl get -n obskit svc grafana| awk 'NR>1 {print $4}'):80/login"
```

> Grafana login: `admin`

> Grafana password: `gbpotO3SjLzpxIIu6xxthZQmfv29pw2eDn62dGsG`

> Feel free to update them, ([secret file](https://github.com/TommyStarK/obskit/blob/main/toolkit/grafana/templates/secret/grafana.yaml))

### Cleanup

- remove observability stack

```bash
❯ ./obskit --delete --cluster=<CLUSTER_NAME> --target=grafana,loki,mimir,tempo
❯ ./obskit --delete --cluster=minikube --target=agent
```

- remove clusters

```bash
❯ gcloud container clusters delete obskit-cluster
❯ minikube delete
```

- remove buckets

```bash
❯ gcloud storage rm --recursive gs://obskit-loki/
❯ gcloud storage rm --recursive gs://obskit-mimir/
❯ gcloud storage rm --recursive gs://obskit-tempo/
```

## Production readiness

### Capacity planning

- [Kubernetes production environment](https://kubernetes.io/docs/setup/production-environment/)
- [Kubernetes best practices](https://kubernetes.io/docs/setup/best-practices/)
- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Loki scalability](https://grafana.com/docs/loki/latest/operations/scalability/)
- [Loki scaling queriers](https://grafana.com/docs/loki/latest/operations/autoscaling_queriers/)
- [Mimir capacity planning](https://grafana.com/docs/mimir/latest/operators-guide/run-production-environment/planning-capacity/)
- [Tempo capacity planning](https://github.com/grafana/tempo/issues/1540#issuecomment-1178035971)

### Resources (cpu/memory)

The following links were very useful for me to understand how to specify cpu and memory for the different components.

- [Mimir capacity planning](https://grafana.com/docs/mimir/v2.6.x/operators-guide/run-production-environment/planning-capacity/)
- Mimir production-ready setup example:
	- [ingestion rate ~66K samples per second](https://github.com/grafana/mimir/blob/main/operations/helm/charts/mimir-distributed/small.yaml)
	- [ingestion rate ~660K samples per second](https://github.com/grafana/mimir/blob/main/operations/helm/charts/mimir-distributed/large.yaml)

### Persistence

`Loki`, `Mimir` and `Tempo` use S3 as long term storage. However some specific components store and process data locally before interacting
with the bucket. An outage occurring during this window could result in data loss. To avoid this situation you might want to enable
data persistence.

`Compactor` and `Ingester` are common to `Loki`, `Mimir` and `Tempo`:

- [Compactor disk space](https://grafana.com/docs/mimir/latest/operators-guide/run-production-environment/production-tips/#compactor)
- [Compactor disk utilization](https://grafana.com/docs/mimir/latest/operators-guide/architecture/components/compactor/#compactor-disk-utilization)
- [Ingester disk space](https://grafana.com/docs/mimir/latest/operators-guide/run-production-environment/production-tips/#ingester-disk-space)
- [Ingester disk IOPS](https://grafana.com/docs/mimir/latest/operators-guide/run-production-environment/production-tips/#ingester-disk-iops)

`Loki` and `Mimir` are respectively deployed with the `index-gateway` and `store-gateway`. This avoids running Queriers with a disk for persistence.

- [Loki Index Gateway](https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/#index-gateway)
- [Mimir Store-gateway](https://grafana.com/docs/mimir/latest/operators-guide/run-production-environment/production-tips/#store-gateway)

You can repeat the steps below for each service you want to enable data persistence.

1. Update the storage class and size to fit to your needs (files are located at `toolkit/<SERVICE>/templates/storageclass`, `toolkit/<SERVICE>/templates/persistentvolumeclaim`)
2. Set the `persistence` attribute to `true` in the according [service config](https://github.com/TommyStarK/obskit/tree/main/config)

### Ingress

By default, ingresses are disabled. `Grafana`, `Loki`, `Mimir` and `Tempo` are accessible through Kubernetes `LoadBalancer`. There are prerequisites for being able to expose `HTTPS` routes for those services.

You must have an Ingress controller to satisfy an ingress. Please be sure you have [Ingress-NGINX Controller](https://github.com/kubernetes/ingress-nginx/) running in your cluster. Feel free to use the ingress controller of your choice, but do not forget to update the ingress(es)
template(s) accordingly.

You can repeat the steps below for each service you want to be accessible over `HTTPS` from outside the cluster.

1. Add the certificate and key to the secret template (file is located under `toolkit/<SERVICE>/templates/secret/<SERVICE>-tls.yaml`)
2. Set the `ingress.enable` attribute to `true` in the according [service config](https://github.com/TommyStarK/obskit/tree/main/config)
3. Set the `ingress.host` attribute with your domain in the according [service config](https://github.com/TommyStarK/obskit/tree/main/config)
4. Update the [agent remotes config](https://github.com/TommyStarK/obskit/blob/main/config/agent.yaml#L12-L19)

### Autoscaling

In order to enable the `HorizontalPodAutoScaler` feature, you might want to have a look [here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

Resources like `cpu` and `memory` should be specified in the templates (see [usefull links](https://github.com/TommyStarK/obskit#resources-cpumemory)). This is used to determine the resource utilization and used by the HPA controller to scale the target up or down.

You can repeat the steps below for each service you want to enable autoscaling.

1. Set the `autoscaling` attribute to `true` in the according [service config](https://github.com/TommyStarK/obskit/tree/main/config)

### Rolling update

> incoming

### Self monitoring

> incoming
