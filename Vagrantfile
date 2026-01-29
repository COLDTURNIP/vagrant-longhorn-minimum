# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'
require 'yaml'

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
#box_image = "generic/ubuntu2004"

k3s_version = "v1.34.2+k3s1"
#k3s_version = "v1.33.10+k3s1"
#k3s_version = "latest"
#k3s_version = "v1.13.4+k3s1"
longhorn_version = ''
#longhorn_version = 'master'
#longhorn_version = 'v1.10.1'
#longhorn_version = 'v1.9.2'
#longhorn_version = 'v1.8.2'
#longhorn_version = 'v1.7.3'
#longhorn_version = 'v1.6.4'
#longhorn_version = 'v1.5.5'
#longhorn_version = 'v1.4.4'
#longhorn_version = 'v1.3.3'
#longhorn_version = 'v1.2.6'

longhorn_cli_version = longhorn_version
longhorn_cli_image_version = longhorn_version
if longhorn_version == 'master' || longhorn_version == ''
  longhorn_cli_version = 'v1.10.0'
  longhorn_cli_image_version = 'master-head'
end

libvirt_network_name = "vagrant-longhorn"
libvirt_network_interface = "virbr1"
libvirt_network_subnet = "192.168.156"
libvirt_network_firewalld_zone = "trusted"

master_host = "libvirt-ubuntu-k3s-master"
master_ip = "#{libvirt_network_subnet}.20"
master_cpu = "4"
master_memory = "4096"

workers = { "libvirt-ubuntu-k3s-worker1" => "#{libvirt_network_subnet}.21",
            "libvirt-ubuntu-k3s-worker2" => "#{libvirt_network_subnet}.22",
            "libvirt-ubuntu-k3s-worker3" => "#{libvirt_network_subnet}.23",
            #"libvirt-arch-k3s-worker2" => "#{libvirt_network_subnet}.32",
            #"libvirt-arch-k3s-worker3" => "#{libvirt_network_subnet}.33",
           }
worker_cpu = "3"
worker_memory = "3584"

kubeconfig_file = "libvirt-ubuntu-k3s.yaml"
k3s_token = "libvirt-ubuntu-token"

# block disk is needed by Longhorn engine V2
enable_longhorn_v2_engine = "true"
#enable_longhorn_v2_engine = "false"
system_log_disk_device = "/dev/vdd"
longhorn_default_fs_disk_device = "/dev/vdc"
longhorn_default_fs_disk_path = "/var/lib/longhorn/"
longhorn_default_blk_disk_device = "/dev/vdb"
longhorn_worker_node_default_disk_config = [
  {
    "path" => longhorn_default_fs_disk_path,
    "allowScheduling" => true,
    "storageReserved" => 0,
  },
  {
    "name" => "default-v2-disk", 
    "path" => longhorn_default_blk_disk_device,
    "allowScheduling" => true,
    "diskType" => "block",
    "storageReserved" => 0,
  },
]
longhorn_master_node_default_disk_config = [
  {
    "path" => longhorn_default_fs_disk_path,
    "allowScheduling" => false,
    "storageReserved" => 0,
  },
  {
    "name" => "default-v2-disk", 
    "path" => longhorn_default_blk_disk_device,
    "allowScheduling" => false,
    "diskType" => "block",
    "storageReserved" => 0,
  },
]

# Cgroup v1 for legacy K8s support. Rebooting needed.
provision_cgroup_v1 = <<~SHELL
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& systemd.unified_cgroup_hierarchy=false cgroup_enable=memory cgroup_enable=cpuset cgroup_memory=1/' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& systemd.unified_cgroup_hierarchy=false cgroup_enable=memory cgroup_enable=cpuset cgroup_memory=1/' /etc/default/grub
    update-grub
    SHELL

# Extra parameters in INSTALL_K3S_EXEC variable because of
# K3s picking up the wrong interface when starting master and worker
# https://github.com/alexellis/k3sup/issues/306
provision_all_node_script = <<~SHELL
    VAGRANT_DIR=$(pwd)
    WORKDIR="$(mktemp -d)"
    trap "rm -rf -- '${WORKDIR}'" EXIT
    echo "Change to workdir ${WORKDIR}"
    pushd "${WORKDIR}"

    echo 'System disk ...'
    mkfs.ext4 #{system_log_disk_device}
    mkdir -p /mnt/temp_log
    mount #{system_log_disk_device} /mnt/temp_log
    rsync -aHAX /var/log/ /mnt/temp_log/
    UUID=$(blkid -s UUID -o value #{system_log_disk_device})
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID /var/log ext4 defaults 0 2" >> /etc/fstab
    fi
    umount /mnt/temp_log && rm -r /mnt/temp_log
    mount -a
    systemctl restart rsyslog

    echo 'Additional disk ...'
    mkfs.ext4 #{longhorn_default_fs_disk_device}
    mkdir -p #{longhorn_default_fs_disk_path}
    UUID=$(blkid -s UUID -o value #{longhorn_default_fs_disk_device})
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID #{longhorn_default_fs_disk_path} ext4 defaults 0 2" >> /etc/fstab
    fi
    # Longhorn SPDK engine does not allow partition or filesystem on given disk
    wipefs -a #{longhorn_default_blk_disk_device}
    sgdisk --zap-all #{longhorn_default_blk_disk_device}

    mount -a
    df -h

    echo 'System configurations'
    #sysctl -w vm.nr_hugepages=1024
    #echo 'vm.nr_hugepages = 1024' >>/etc/sysctl.conf
    cat >/etc/logrotate.d/rsyslog <<LOGROTATE_CONFIG
    /var/log/syslog
    {
      daily
      size 10G
      rotate 5
      missingok
      notifempty
      compress
      delaycompress
      sharedscripts
      postrotate
              /usr/lib/rsyslog/rsyslog-rotate
      endscript
    }

    /var/log/mail.log
    /var/log/kern.log
    /var/log/auth.log
    /var/log/user.log
    /var/log/cron.log
    {
      daily
      size 200M
      rotate 5
      missingok
      notifempty
      compress
      delaycompress
      sharedscripts
      postrotate
              /usr/lib/rsyslog/rsyslog-rotate
      endscript
    }
    LOGROTATE_CONFIG

    echo 'Disable multipath ...'
    systemctl stop multipath-tools.service multipathd.socket
    systemctl disable multipath-tools.service multipathd.socket

    echo 'Install other CLI tools ...'
    apt-get install -y jq
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl && mv kubectl /usr/local/bin/
    #systemctl restart snapd.seeded.service
    #systemctl restart snapd.service
    #snap install kubectl --classic
    #snap install k9s --devmode

    echo 'Install Longhorn CLI tool #{longhorn_cli_version} ...'
    curl -sSfL -o ./longhornctl https://github.com/longhorn/cli/releases/download/#{longhorn_cli_version}/longhornctl-linux-amd64
    chmod +x ./longhornctl
    mv ./longhornctl /usr/bin/

    echo 'Prepare disks for Longhorn ...'
    [[ -d #{longhorn_default_fs_disk_path} ]] && echo '  - default filesystem disk ready'
    [[ -b #{longhorn_default_blk_disk_device} ]] && echo '  - default block disk ready'
    SHELL

provision_master_script = <<~SHELL
    K3S_AUDIT_POLICY_FILE='/etc/k3s/audit-policy.yaml'

    echo 'Configuring K3s audit policy ...'
    mkdir -p $(dirname $K3S_AUDIT_POLICY_FILE)
    cat >"$K3S_AUDIT_POLICY_FILE" <<YAML
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
      - level: RequestResponse
        resources:
          - group: "storage.k8s.io"
            verbs: ["create", "update", "delete", "patch", "deletecollection"]
            resources: ["volumeattachments"]
    YAML
    cat $K3S_AUDIT_POLICY_FILE

    echo 'Install K3s ...'

    INSTALL_K3S_ARGS=(
    -v 9
    --token "#{k3s_token}"
    --kubelet-arg=node-status-update-frequency=5s
    --kubelet-arg=hairpin-mode=promiscuous-bridge
    #--kubelet-arg=v=9
    --kube-controller-manager-arg=node-monitor-grace-period=15s
    --kube-controller-manager-arg=node-monitor-period=5s
    --kube-apiserver-arg=default-not-ready-toleration-seconds=30
    --kube-apiserver-arg=default-unreachable-toleration-seconds=30
    --kube-apiserver-arg=audit-log-path=-
    --kube-apiserver-arg=audit-policy-file="$K3S_AUDIT_POLICY_FILE"
    --bind-address=#{master_ip}
    --node-external-ip=#{master_ip}
    --node-taint='node-role.kubernetes.io/control-plane:NoSchedule'
    --flannel-iface eth1
    #--disable-helm-controller
    )

    export K3S_KUBECONFIG_MODE="644"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="#{k3s_version}" INSTALL_K3S_EXEC="server" sh -s - "${INSTALL_K3S_ARGS[@]}"
    #curl -sfL https://get.k3s.io | sh -s - "${INSTALL_K3S_ARGS[@]}"

    echo 'Waiting K3s ready ...'
    while [[ ! -f /etc/rancher/k3s/k3s.yaml ]]; do sleep 1; done

    echo 'Exporting kubeconfig file ...'
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    chmod a+r "${KUBECONFIG}"
    cp -f "${KUBECONFIG}" /vagrant_shared/#{kubeconfig_file}
    ls -l /vagrant_shared

    echo 'Preparing default Kubectl configurations ...'
    mkdir -p ~vagrant/.kube
    cp /etc/rancher/k3s/k3s.yaml ~vagrant/.kube/config
    chown vagrant:vagrant ~vagrant/.kube/config

    echo 'Post initialiing K3s ...'
    kubectl -n kube-system patch deployment coredns -p '{"spec": {"template": {"spec": {"nodeSelector": {"node-role.kubernetes.io/control-plane": "true"}}}}}'

    echo 'Install CSI snapshot support ...'
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd | kubectl create -f -
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller | kubectl -n kube-system apply -f -
    kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/csi-snapshotter | kubectl create -f -
    kubectl -n kube-system patch deployment snapshot-controller \
      --type='json' \
      -p='[
        {
          "op": "add",
          "path": "/spec/template/spec/tolerations",
          "value": [
            {
              "key": "node-role.kubernetes.io/control-plane",
              "operator": "Exists",
              "effect": "NoSchedule"
            }
          ]
        }
      ]'

    echo "Configuring Longhorn default disks on ${NODE_NAME} ..."
    kubectl label node "$NODE_NAME" node.longhorn.io/create-default-disk=config
    kubectl annotate node "$NODE_NAME" node.longhorn.io/default-disks-config='#{longhorn_master_node_default_disk_config.to_json}'

    #echo "Install Longhorn prerequisite dependencies ..."
    #longhornctl --image longhornio/longhorn-cli:#{longhorn_cli_image_version} install preflight --enable-spdk

    if [[ -n "${longhorn_version}" ]]; then
      echo "Install Longhorn #{longhorn_version} on ${NODE_NAME} ..."
      kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/longhorn.yaml
      echo 'Longhorn #{longhorn_version} installed. It would take several minutes for pods get ready.'

      echo "Setup Longhorn customized default configurations ..."
      kubectl create namespace longhorn-system 2>/dev/null || true
      kubectl apply -f - <<YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      labels:
        kubernetes.io/metadata.name: longhorn-system
        name: longhorn-system
      name: longhorn-system
    spec:
      finalizers:
      - kubernetes
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: longhorn-default-setting
      namespace: longhorn-system
    data:
      default-setting.yaml: |-
        "create-default-disk-labeled-nodes": "true",
        "v2-data-engine": "#{enable_longhorn_v2_engine}",
        "data-engine-hugepage-enabled": '{"v2": "false"}',
        "data-engine-interrupt-mode-enabled": '{"v2": "true"}',
        "deleting-confirmation-flag": "true",
        "storage-reserved-percentage-for-default-disk": "0",
        "allow-collecting-longhorn-usage-metrics": "false",
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: longhorn-default-resource
      namespace: longhorn-system
    data:
      default-resource.yaml: |
        "backup-target": "s3://backupbucket@us-east-1/"
        "backup-target-credential-secret": "longhorn-backup-target-secret"
    YAML

    fi

    SHELL

provision_worker_script = <<~SHELL
    echo 'Install K3s ...'

    INSTALL_K3S_ARGS=(
    --token "#{k3s_token}"
    --kubelet-arg=node-status-update-frequency=5s
    --kubelet-arg=hairpin-mode=promiscuous-bridge
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
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="#{k3s_version}" INSTALL_K3S_EXEC="agent" sh -s - "${INSTALL_K3S_ARGS[@]}"

    echo 'Preparing default Kubectl configurations ...'
    mkdir -p ~vagrant/.kube
    cp /vagrant_shared/#{kubeconfig_file} ~vagrant/.kube/config || ls -l /vagrant_shared/
    chown vagrant:vagrant ~vagrant/.kube/config
    export KUBECONFIG=~vagrant/.kube/config

    echo "Waiting for node ${NODE_NAME} joining the Kubernetes cluster ..."
    kubectl wait --for=condition=Ready node/${NODE_NAME} --timeout=600s

    echo "Configuring Longhorn default disks on ${NODE_NAME} ..."
    kubectl label node "$NODE_NAME" node.longhorn.io/create-default-disk=config
    kubectl annotate node "$NODE_NAME" node.longhorn.io/default-disks-config='#{longhorn_worker_node_default_disk_config.to_json}'
    SHELL

Vagrant.configure("2") do |config|
  config.vm.box = box_image
  #config.vm.provision "shell", inline: provision_cgroup_v1, reboot: true
  config.vm.provision "shell", inline: provision_all_node_script
  config.vm.synced_folder "./shared", "/vagrant_shared", type: "virtiofs"

  config.vm.provider :libvirt do |provider|
    provider.memorybacking :access, :mode => "shared" # needed by virtio-fs share folder
  end

  config.trigger.after :status do |trigger|
    trigger.ruby do | env, machine |
      puts "Kubernetes KUBECONFIG: #{env.cwd}/shared/#{kubeconfig_file}"
    end
  end

  #config.trigger.after :up do |trigger|
  #  trigger.name = "Longhorn prerequisite installation"
  #  trigger.run_remote = {
  #    inline: <<~SHELL
  #    export KUBECONFIG=~vagrant/.kube/config
  #    longhornctl --image longhornio/longhorn-cli:#{longhorn_cli_image_version} install preflight --enable-spdk
  #    sysctl -w vm.nr_hugepages=0
  #    echo 'vm.nr_hugepages = 0' >>/etc/sysctl.conf
  #    SHELL
  #  }
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
    master.vm.disk :disk, size: "100GB", primary: true
    master.vm.provider :libvirt do |provider|
      provider.memory = master_memory
      provider.cpus = master_cpu
      provider.cpu_mode = 'host-passthrough'
      provider.disk_driver :cache => 'unsafe'
      provider.storage :file, {
        size: '100G',
        device: 'vdd',
      }
      provider.storage :file, {
        size: '200G',
        device: 'vdc',
        path: "extend1-#{master_host}.qcow2",
      }
      provider.storage :file, {
        size: '200G',
        device: 'vdb',
        path: "extend2-#{master_host}.qcow2",
      }
      #provider.management_network_keep = true
    end
    master.vm.provision "master",
      type: "shell",
      inline: provision_master_script,
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
      worker.vm.disk :disk, size: "100GB", primary: true
      worker.vm.provider :libvirt do |provider|
        provider.memory = worker_memory
        provider.cpus = worker_cpu
        provider.cpu_mode = 'host-passthrough'
        provider.disk_driver :cache => 'unsafe'
        provider.storage :file, {
          size: '100G',
          device: 'vdd',
        }
        provider.storage :file, {
          size: '200G',
          device: 'vdc',
          path: "extend1-#{worker_name}.qcow2",
        }
        provider.storage :file, {
          size: '200G',
          device: 'vdb',
          path: "extend2-#{worker_name}.qcow2",
        }
        #provider.management_network_keep = true
      end
      worker.vm.provision "node_setup",
        type: "shell",
        after: "master",
        inline: provision_worker_script,
        env: { NODE_IP: worker_ip, NODE_NAME: worker_name }
    end
  end
end
