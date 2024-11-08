# Vagrant K3s Longhorn

Create minimum Longhorn-ready K3s cluster using Vagrant.

## Usage

```
$ vagrant up --provider=virtualbox
```

The kubeconfig file would be generated as shared/k3s.yaml. Access the cluster using `KUBECONFIG=$(pwd)/shared/k3s.yaml kubectl ...`.

It will take more than 1x minutes to install reqired modules on each nodes. Please be patient.

## References

- https://akos.ma/blog/vagrant-k3s-and-virtualbox/
- https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
- https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning
