# Architecture Variations

While core Kubernetes components remain consistent, deployment and management approaches vary.

## Control plane deployment options

| Option | Description |
|---|---|
| **Traditional deployment** | Control plane components run directly on dedicated machines or VMs, often managed as systemd services. |
| **Static Pods** | Components deployed as static Pods managed by the kubelet on specific nodes. Common approach used by kubeadm. |
| **Self-hosted** | Control plane runs as Pods within the cluster itself, managed by Deployments and StatefulSets. |
| **Managed Kubernetes** | Cloud providers abstract the control plane, managing its components as part of their service offering. |

## Workload placement considerations

- **Small / dev clusters**: Control plane components and user workloads may share the same nodes.
- **Large production clusters**: Dedicated nodes for control plane components, separated from user workloads.
- Some organizations run critical add-ons or monitoring tools on control plane nodes.

## Cluster management tools

Tools like **kubeadm**, **kops**, and **Kubespray** offer different approaches to deploying and managing clusters, each with its own method of component layout and management.

## Customization and extensibility

- **Custom schedulers** can work alongside or replace the default kube-scheduler.
- **API server extensions** via CustomResourceDefinitions (CRDs) and API Aggregation.
- **Cloud provider integration** through the cloud-controller-manager.

This flexibility lets organizations tailor clusters to specific needs, balancing operational complexity, performance, and management overhead.
