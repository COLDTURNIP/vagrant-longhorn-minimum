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

## Optional storage network

Storage networking is disabled by default. To enable it, edit `Vagrantfile`:

```ruby
enable_storage_network = true
network_stack = "dual"
```

The storage address families follow `network_stack`:

| `network_stack` | Storage address families |
|---|---|
| `ipv4` | IPv4 |
| `ipv6` | IPv6 |
| `dual` | IPv4 and IPv6 |
| `dual6` | IPv4 and IPv6; Kubernetes remains IPv6-first |

Recreate the disposable VMs after changing either option. Reprovisioning is not
an enable/disable migration and does not clean up old pod attachments or routes.
Destroying the VMs removes their data:

```bash
vagrant destroy -f
vagrant up
```

When enabled, provisioning installs Multus and the
`longhorn-system/vagrant-storage-network` NAD. The NAD delegates to ipvlan L3 on
`lhstorage0`, with host-local IP allocation from a separate subnet per node:

| Node | IPv4 storage subnet | IPv6 storage subnet |
|---|---|---|
| Master | `192.168.1.0/24` | `fd00:168:1::/64` |
| Worker1 | `192.168.2.0/24` | `fd00:168:2::/64` |
| Worker2 | `192.168.3.0/24` | `fd00:168:3::/64` |
| Worker3 | `192.168.4.0/24` | `fd00:168:4::/64` |

Only the selected families are configured. Each node also gets a host-side
ipvlan sibling, `lhstoragehost`, using its subnet's gateway address (`.1` or
`::1`). Host-local IPAM reserves this address, so pods cannot allocate it.
Local storage routes use the sibling; remote storage routes use the other VMs'
addresses on `lhstorage0`. Less-preferred unreachable routes for these specific
storage subnets prevent primary-default-route fallback if preferred routes are
removed. This does not replace verification of isolation under other route or
policy changes.

The `longhorn-storage-host.service` recreates the host endpoint, routes, and
Flannel CNI subnet file before K3s starts after reboot. Longhorn's generated Helm
values select this NAD; provisioning also sets `storage-network` when
`longhorn_version` requests an automatic Longhorn installation.

When disabled, no Multus/NAD or storage host endpoint is provisioned, and the
Longhorn storage-network value is empty. The second VM NIC remains because K3s
uses it for node connectivity even without a secondary pod network.

After installing Longhorn with storage networking enabled, the existing live
verification helper checks pod attachments, host TCP access to storage
endpoints, and a synthetic V2 volume write/read. It creates and normally removes
a demo namespace and StorageClass; run it only on a disposable development
cluster:

```bash
bash verify_longhorn_storage_network.sh
```

After setup, the Longhorn dashboard is available after exporting the port:

```bash
sudo bash longhorn_frontend_proxy.sh

# the dashboard is available now at http://localhost:8080
```

## References

- https://akos.ma/blog/vagrant-k3s-and-virtualbox/
- https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
- https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning
