# Vagrant K3s Longhorn

Create minimum Longhorn-ready K3s cluster using Vagrant.

## Usage

```
$ vagrant up --provider=virtualbox
```

The kubeconfig file would be generated as shared/k3s.yaml. Access the cluster using `KUBECONFIG=$(pwd)/shared/k3s.yaml kubectl ...`.

It will take more than 1x minutes to install reqired modules on each nodes. Please be patient.

After setup, the Longhorn dashboard is available after exporting the port:

```
sudo bash longhorn_frontend_proxy.sh

# the dashboard is available now at http://localhost:8080
```

## References

- https://akos.ma/blog/vagrant-k3s-and-virtualbox/
- https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
- https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning
