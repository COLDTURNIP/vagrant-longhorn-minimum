# Vagrant K3s Longhorn

Create minimum Longhorn-ready K3s cluster using Vagrant.

## Prerequisite

Follow the Vagrant installation guide to setup Vagrant with VirtualBox.

https://developer.hashicorp.com/vagrant/docs/installation

## Usage

To create cluster:

```
export DISTRO=ubuntu
VAGRANT_VAGRANTFILE=Vagrantfile.$DISTRO vagrant up
```

To destroy cluster:

```
VAGRANT_VAGRANTFILE=Vagrantfile.$DISTRO vagrant destroy -f
```

The `shared` folder is shared between host and VM instances. VM exchange the information under this folder, for example, the K3s token.

The kubeconfig file would be generated as `shared/${DISTRO}-k3s.yaml`. Access the cluster using `KUBECONFIG=$(pwd)/shared/${DISTRO}-k3s.yaml kubectl ...`.

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
