# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============
# Prerequisite
# ============
#
# Follow the Vagrant installation guide to setup Vagrant with VirtualBox.
# https://developer.hashicorp.com/vagrant/docs/installation
#
# ## VM Provider ##
#
# Make sure that libvirt and qemu are installed, and KVM is enabled. To OpenSUSE:
#
#   $ sudo zypper install libvirt qemu virt-manager libvirt-daemon-driver-qemu qemu-kvm
#
# And install the Vagrant with libvirt provider plugin:
# https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html
#
# Alternatively, it is even more recommended to make good use of containerized Vagrant with libvirt:
# https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html#docker--podman
#
# ## Libvirt Network ##
#
# A Libvirt network "vagrant-longhorn" will be generated automatcially, and
# join the "trusted" firewalld zone. Make sure the Libvirt is built with
# firewalld support.
#
# ## Shared Folder ##
#
# The host folder ./shared is mounted into VM's /vagrant_shared, and synced
# using Virtiofs. Add the following memory backend configuration in host's
# /etc/libvirt/qemu.conf:
#
#   memory_backing_dir = "/dev/shm/"
#
# Refer to Libvirt's official document for more detail:
# https://libvirt.org/kbase/virtiofs.html#other-options-for-vhost-user-memory-setup
#
# =====
# Usage
# =====
#
# To create cluster:
#
# ```bash
# vagrant up
# ```
#
# To destroy cluster:
#
# ```bash
# vagrant destroy -f
# ```
#
# The `shared` folder is shared between host and VM instances. VMs and the host exchange the information under this folder. It is useful for adding local-built container images:
#
# ```bash
# vagrant ssh libvirt-ubuntu-k3s-$node -- sudo k3s ctr images import /vagrant_shared/my_saved_images.tar
# ```
#
# The kubeconfig file would be generated as `shared/libvirt-${DISTRO}-k3s.yaml`. Access the cluster using `KUBECONFIG=$(pwd)/shared/libvirt-${DISTRO}-k3s.yaml kubectl ...`.
#
# It will take more than 10 minutes to install reqired modules on each nodes.
#
# After setup, the Longhorn dashboard is available after exporting the port:
#
# ```bash
# sudo bash longhorn_frontend_proxy.sh
#
# # the dashboard is available now at http://localhost:8080
# ```
#
# ==========
# References
# ==========
# - https://akos.ma/blog/vagrant-k3s-and-virtualbox/
# - https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
# - https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning

box_image = "bento/ubuntu-24.04"

k3s_version = "" 
#k3s_version = "v1.23.17+k3s1" 
longhorn_version = 'v1.9.0'
#longhorn_version = 'v1.8.1'
#longhorn_version = 'v1.7.3'
#longhorn_version = 'v1.6.4'
#longhorn_version = 'v1.5.5'
#longhorn_version = 'v1.4.4'
#longhorn_version = 'v1.3.3'
#longhorn_version = 'v1.2.6'

libvirt_network_name = "vagrant-longhorn"
libvirt_network_interface = "virbr1"
libvirt_network_subnet = "192.168.156"
libvirt_network_firewalld_zone = "trusted"

master_host = "libvirt-ubuntu-k3s-master"
master_ip = "#{libvirt_network_subnet}.20"
master_cpu = "4"
master_memory = "4096"

workers = { "libvirt-ubuntu-k3s-worker1" => "192.168.156.21",
            "libvirt-ubuntu-k3s-worker2" => "192.168.156.22",
            #"libvirt-ubuntu-k3s-worker3" => "192.168.156.23",
            #"libvirt-arch-k3s-worker2" => "192.168.156.32",
            #"libvirt-arch-k3s-worker3" => "192.168.156.33",
           }
worker_cpu = "3"
worker_memory = "3584"

kubeconfig_file = "libvirt-ubuntu-k3s.yaml"
k3s_token = "libvirt-ubuntu-token"

# block disk is needed by Longhorn engine V2
longhorn_block_disk_path = "/var/local/longhorn-cusom-disk/custom-blockfile"
longhorn_block_disk_size = "1024" # MB

# Extra parameters in INSTALL_K3S_EXEC variable because of
# K3s picking up the wrong interface when starting master and worker
# https://github.com/alexellis/k3sup/issues/306

provision_all_node_script = <<-SHELL
    VAGRANT_DIR=$(pwd)
    WORKDIR="$(mktemp -d)"
    trap "rm -rf -- '${WORKDIR}'" EXIT
    echo "Change to workdir ${WORKDIR}"
    pushd "${WORKDIR}"

    echo 'Additional disk ...'
    mkfs.ext4 /dev/vdb
    mkdir -p /var/lib/longhorn
    mount /dev/vdb /var/lib/longhorn
    echo '/dev/vdb /var/lib/longhorn ext4 defaults 0 2' >> /etc/fstab
    df -h

    echo 'System configurations'
    sysctl -w vm.nr_hugepages=1024
    echo 'vm.nr_hugepages = 1024' >>/etc/sysctl.conf

    echo 'Install other CLI tools ...'
    apt-get install -y jq
    systemctl restart snapd.seeded.service
    systemctl restart snapd.service
    snap install kubectl --classic
    snap install k9s --devmode

    #curl -sSfL -o ./longhornctl https://github.com/longhorn/cli/releases/download/#{longhorn_version}/longhornctl-linux-amd64
    #chmod +x ./longhornctl
    #mv ./longhornctl /usr/bin/
    SHELL

provision_master_script = <<-SHELL
    echo 'Install K3s ...'

    INSTALL_K3S_ARGS=(
    server
    --token "#{k3s_token}"
    --kubelet-arg=node-status-update-frequency=5s
    #--kubelet-arg=v=4
    --kube-controller-manager-arg=node-monitor-grace-period=15s
    --bind-address=#{master_ip}
    --node-external-ip=#{master_ip}
    --flannel-iface eth1
    )

    export K3S_KUBECONFIG_MODE="644"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="#{k3s_version}" sh -s - "${INSTALL_K3S_ARGS[@]}"
    #curl -sfL https://get.k3s.io | sh -s - "${INSTALL_K3S_ARGS[@]}"
    echo "Sleeping for 5 seconds to wait for k3s to start"
    sleep 5
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    chmod a+r "${KUBECONFIG}"
    cp "${KUBECONFIG}" /vagrant_shared/#{kubeconfig_file}

    echo 'Preparing default Kubectl configurations ...'
    mkdir -p ~vagrant/.kube
    cp /etc/rancher/k3s/k3s.yaml ~vagrant/.kube/config
    chown vagrant:vagrant ~vagrant/.kube/config

    echo 'Install CSI snapshot support ...'
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd | kubectl create -f -
    kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/csi-snapshotter | kubectl create -f -

    echo 'Install Longhorn #{longhorn_version} ...'
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/longhorn.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-iscsi-installation.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-nfs-installation.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-spdk-setup.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-nvme-cli-installation.yaml
    echo 'Longhorn #{longhorn_version} installed. It would take several minutes for pods get ready.'
    SHELL

provision_worker_script = <<-SHELL
    echo 'Install K3s ...'

    INSTALL_K3S_ARGS=(
    agent
    --token "#{k3s_token}"
    --server https://#{master_ip}:6443
    --flannel-iface eth1
    )

    if [[ -n "${NODE_IP}" ]]; then
      INSTALL_K3S_ARGS+=(
        --bind-address=${NODE_IP}
        --node-external-ip=${NODE_IP}
      )
    fi

    export K3S_TOKEN="#{k3s_token}" K3S_KUBECONFIG_MODE="644"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="#{k3s_version}" sh -s - "${INSTALL_K3S_ARGS[@]}"
    #curl -sfL https://get.k3s.io | sh -s - "${INSTALL_K3S_ARGS[@]}"

    echo 'Preparing default Kubectl configurations ...'
    mkdir -p ~vagrant/.kube
    cp /vagrant_shared/#{kubeconfig_file} ~vagrant/.kube/config || ls -l /vagrant_shared/
    chown vagrant:vagrant ~vagrant/.kube/config
    SHELL

provision_longhorn_v2_disk = <<~SHELL
    export KUBECONFIG=~vagrant/.kube/config

    echo 'Enabling v2 data engine ...'
    for i in {600}; do
      if ( kubectl -n longhorn-system patch settings v2-data-engine --type=merge --patch '{"value":"true"}' 2>/dev/null ); then
        echo 'v2 data engine enabled.'
        break
      fi
    done

    echo 'Waiting for Longhorn node created ...'
    while ! ( kubectl -n longhorn-system get lhn ${NODE_NAME} >/dev/null 2>/dev/null ); do
      sleep 1
    done

    echo 'Prepare block disk for Longhorn V2 engine ...'

    mkdir -p /var/local/longhorn-cusom-disk
    dd if=/dev/zero of=#{longhorn_block_disk_path} bs=1M count=#{longhorn_block_disk_size}
    losetup -f #{longhorn_block_disk_path}
    BLOCK_DISK_DEV=$(losetup -j #{longhorn_block_disk_path} | cut -d: -f1)

    PATCH=$(
    cat <<-JSON
    {
      "spec": {
        "disks": {
          "custom-blockfile": {
            "path":"${BLOCK_DISK_DEV}",
            "diskType": "block",
            "allowScheduling": true
          }
        }
      }
    }
    JSON
    )
    for i in {1..120}; do
      if ( kubectl -n longhorn-system patch lhn ${NODE_NAME} --type=merge --patch="${PATCH}" 2>/dev/null ); then
        PATCHED=1
        break
      fi
      sleep 5
    done
    if [[ $PATCHED != 1 ]]; then
      echo "WARNING: cannot append block disk ${BLOCK_DISK_DEV} into Longhorn node ${NODE_NAME}"
    fi
    SHELL

Vagrant.configure("2") do |config|
  config.vm.box = box_image
  config.vm.provision "shell", inline: provision_all_node_script
  config.vm.synced_folder "./shared", "/vagrant_shared", type: "virtiofs"

  config.vm.provider :libvirt do |provider|
    provider.memorybacking :access, :mode => "shared" # needed by virtio-fs share folder
  end

  #config.trigger.after :status, type: :command do |trigger|
  #  trigger.ruby do | env, machine |
  #    puts "Kubernetes KUBECONFIG: #{env.cwd}/shared/#{kubeconfig_file}"
  #  end
  #end

  config.vm.define master_host, primary: true do |master|
    master.trigger.before :up do |trigger|
      trigger.name = "Create libvirt network"
      trigger.info = "Ensuring libvirt network exists"
      trigger.run = {
        inline: "bash create_libvirt_network.sh #{libvirt_network_name} #{libvirt_network_interface} #{libvirt_network_subnet}",
      }
    end
    master.trigger.after :up do |trigger|
      trigger.name = "Kubernetes cluster Information"
      trigger.ruby do | env, machine |
        puts "Kubernetes cluster available with KUBECONFIG=#{env.cwd}/shared/#{kubeconfig_file}"
      end
    end
    master.trigger.after :destroy do |trigger|
      trigger.name = "Clear cluster resource"
      trigger.ruby do | env, machine |
        [kubeconfig_file].each do |fname|
          fpath = "shared/#{fname}"
          puts "Removing #{fpath}"
          File.delete(fpath) if File.exist?(fpath)
        end
      end
    end
    master.vm.network :private_network,
      libvirt__network_name: libvirt_network_name,
      libvirt__dhcp_enabled: false,
      libvirt__mac: "52:54:00:10:16:01",
      ip: master_ip
    master.vm.hostname = master_host
    master.vm.provider :libvirt do |provider|
      provider.memory = master_memory
      provider.cpus = master_cpu
      provider.cpu_mode = 'host-passthrough'
      provider.disk_driver :cache => 'unsafe'
      provider.storage :file, {
        size: '50G',
        device: 'vdb',
        path: "extend-#{master_host}.qcow2",
        allow_existing: true,
      }
      #provider.management_network_keep = true
    end
    master.vm.provision "master", type: "shell", inline: provision_master_script
    master.vm.provision "longhorn_block_disk",
      type: "shell",
      after: "master",
      inline: provision_longhorn_v2_disk,
      env: { NODE_NAME: master_host }
  end

  workers.each do |worker_name, worker_ip|
    config.vm.define worker_name do |worker|
      worker.trigger.before :up do |trigger|
        trigger.name = "Wait master node"
        trigger.info = "Wait for Kubernetes API server"
        trigger.run = {
          inline: "bash wait_k8s.sh shared/#{kubeconfig_file} 600",
        }
      end
      worker.vm.network :private_network,
        libvirt__network_name: libvirt_network_name,
        libvirt__dhcp_enabled: false,
        ip: worker_ip
      worker.vm.hostname = worker_name
      worker.vm.provider :libvirt do |provider|
        provider.memory = worker_memory
        provider.cpus = worker_cpu
        provider.cpu_mode = 'host-passthrough'
        provider.disk_driver :cache => 'unsafe'
        provider.storage :file, {
          size: '50G',
          device: 'vdb',
          path: "extend-#{worker_name}.qcow2",
          allow_existing: true,
        }
        #provider.management_network_keep = true
      end
      worker.vm.provision "node_setup",
        type: "shell",
        after: "master",
        inline: provision_worker_script,
        env: { NODE_IP: worker_ip }
      worker.vm.provision "longhorn_block_disk",
        type: "shell",
        after: "node_setup",
        inline: provision_longhorn_v2_disk,
        env: { NODE_NAME: worker_name }
    end
  end
end
