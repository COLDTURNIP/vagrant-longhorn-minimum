# Vagrant K3s Longhorn

Create minimum Longhorn-ready K3s cluster using Vagrant.

## Prerequisite

Follow the Vagrant installation guide to setup Vagrant with VirtualBox.
https://developer.hashicorp.com/vagrant/docs/installation

### VM Provider ###

Make sure that libvirt and qemu are installed, and KVM is enabled. To OpenSUSE:

  $ sudo zypper install libvirt qemu virt-manager libvirt-daemon-driver-qemu qemu-kvm

And install the Vagrant with libvirt provider plugin:
https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html

Alternatively, it is even more recommended to make good use of containerized Vagrant with libvirt:
https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html#docker--podman

### Libvirt Network ###

A Libvirt network "vagrant-longhorn" will be generated automatcially, and
join the "trusted" firewalld zone. Make sure the Libvirt is built with
firewalld support.

### Shared Folder ###

The host folder ./shared is mounted into VM's /vagrant_shared, and synced
using Virtiofs. Add the following memory backend configuration in host's
/etc/libvirt/qemu.conf:

  memory_backing_dir = "/dev/shm/"

Refer to Libvirt's official document for more detail:
https://libvirt.org/kbase/virtiofs.html#other-options-for-vhost-user-memory-setup

## Usage

To create cluster:

```bash
vagrant up
```

To destroy cluster:

```bash
vagrant destroy -f
```

The `shared` folder is shared between host and VM instances. VMs and the host exchange the information under this folder. It is useful for adding local-built container images:

```bash
vagrant ssh libvirt-ubuntu-k3s-$node -- sudo k3s ctr images import /vagrant_shared/my_saved_images.tar
```

The kubeconfig file would be generated as `shared/libvirt-${DISTRO}-k3s.yaml`. Access the cluster using `KUBECONFIG=$(pwd)/shared/libvirt-${DISTRO}-k3s.yaml kubectl ...`.

It will take more than 10 minutes to install reqired modules on each nodes.

After setup, the Longhorn dashboard is available after exporting the port:

```bash
sudo bash longhorn_frontend_proxy.sh

# the dashboard is available now at http://localhost:8080
```

## References

- https://akos.ma/blog/vagrant-k3s-and-virtualbox/
- https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
- https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning
