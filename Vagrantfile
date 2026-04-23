# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'
require 'yaml'

# ============
# Prerequisite
# ============
#
# Same as Vagrantfile but with dual-stack (IPv4 + IPv6 ULA) support.
# Every node gets an additional IPv6 address on eth1 from the ULA prefix
# fd00:dead:beef::/64.  K3s is configured for dual-stack.
#
# To bring up the cluster:
#
#   vagrant up
#
# To force-destroy and recreate the libvirt network (needed when switching
# from the single-stack Vagrantfile for the first time):
#
#   virsh net-destroy vagrant-longhorn
#   virsh net-undefine vagrant-longhorn
#   vagrant up
#
# The kubeconfig will be at shared/libvirt-ubuntu-k3s.config as usual.
# Verify dual-stack is working after `vagrant up`:
#
#   KUBECONFIG=shared/libvirt-ubuntu-k3s.config kubectl get nodes -o wide
#   # InternalIP should show both 192.168.156.x and fd00:dead:beef::x
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

#k3s_version = "latest"
#k3s_version = "v1.34.2+k3s1"  # incompatible with longhorn-manager master-head (client-go v0.35 WatchListClient issue)
k3s_version = "v1.33.1+k3s1"
#k3s_version = "v1.33.10+k3s1"
#k3s_version = "v1.23.17+k3s1"
#k3s_version = "v1.13.4+k3s1"
# Direct binary URL for the air-gap probe (see provision_worker_script).
# "latest" uses GitHub's redirect endpoint; specific versions encode + as %2B.
k3s_bin_url = k3s_version == "latest" \
  ? "https://github.com/k3s-io/k3s/releases/latest/download/k3s" \
  : "https://github.com/k3s-io/k3s/releases/download/#{k3s_version.gsub('+', '%2B')}/k3s"

#longhorn_version = ''
longhorn_version = 'master'
#longhorn_version = 'v1.11.0'
#longhorn_version = 'v1.10.2'
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
libvirt_network_subnet_ipv4 = "192.168.156"
libvirt_network_firewalld_zone = "trusted"

# IPv6: ULA prefix for the storage network.
# All nodes get fd00:dead:beef::<last-octet-of-ipv4>/64.
# This prefix is routable only within the cluster (Unique Local Address).
libvirt_network_subnet_ipv6 = "fd00:dead:beef"

# Network stack selection. Requires `vagrant destroy -f && vagrant up` to apply.
#   "ipv6"  - IPv6-only node addresses, pod CIDRs, and service CIDRs.
#   "ipv4"  - IPv4-only (original single-stack behaviour).
#   "dual"  - Dual-stack: IPv4-first CIDRs (10.42.0.0/16,fd42::/48).
#             API server binds to IPv4; --node-ip carries both families.
#             pod.Status.podIP will be IPv4.
#   "dual6" - Dual-stack: IPv6-first CIDRs (fd42::/48,10.42.0.0/16).
#             API server binds to IPv4; --node-ip carries both families.
#             pod.Status.podIP will be IPv6 (primary family from first CIDR).
#             Used to test data-engine-ip-family=ipv4 on an IPv6-first cluster.
#network_stack = "ipv6"
#network_stack = "ipv4"
#network_stack = "dual"
network_stack = "dual6"

# Backup target selection. Requires `vagrant destroy -f && vagrant up` to apply.
#   "minio" - S3-compatible object storage (default)
#   "nfs"   - NFS server (use to reproduce NFS-specific issues such as longhorn/longhorn#12896)
#backup_target = "nfs"
backup_target = "minio"

master_host = "libvirt-ubuntu-k3s-master"
master_ip   = "#{libvirt_network_subnet_ipv4}.20"
master_ipv6 = "#{libvirt_network_subnet_ipv6}::20"  # IPv6: master storage IPv6
master_cpu  = "2"
master_memory = "3072"

workers = {
  "libvirt-ubuntu-k3s-worker1" => { ip: "#{libvirt_network_subnet_ipv4}.21", ipv6: "#{libvirt_network_subnet_ipv6}::21" },
  "libvirt-ubuntu-k3s-worker2" => { ip: "#{libvirt_network_subnet_ipv4}.22", ipv6: "#{libvirt_network_subnet_ipv6}::22" },
  "libvirt-ubuntu-k3s-worker3" => { ip: "#{libvirt_network_subnet_ipv4}.23", ipv6: "#{libvirt_network_subnet_ipv6}::23" },
}

# K3s addresses and flags derived from network_stack. Do not edit these directly.
master_bind_ip        = (network_stack == "ipv6" || network_stack == "dual6") ? master_ipv6 : master_ip
master_node_ip        = case network_stack
                         when "dual"  then "#{master_ip},#{master_ipv6}"
                         when "dual6" then "#{master_ipv6},#{master_ip}"
                         else              master_bind_ip
                         end
master_server_url     = (network_stack == "ipv6" || network_stack == "dual6") ? "https://[#{master_ipv6}]:6443" : "https://#{master_ip}:6443"
k3s_cluster_cidr      = case network_stack
                         when "ipv6"  then "fd42::/48"
                         when "dual"  then "10.42.0.0/16,fd42::/48"
                         when "dual6" then "fd42::/48,10.42.0.0/16"
                         else              "10.42.0.0/16"
                         end
# NOTE: kube-apiserver requires (1) cluster-cidr and service-cidr primary family match,
# and (2) the primary family must match the advertise-address family.
# For "dual6": bind/advertise on IPv6 (fd00:dead:beef::20), both CIDRs IPv6-first.
# This makes pod.Status.podIP=IPv6; kubeconfig API server URL uses IPv6.
k3s_service_cidr      = case network_stack
                         when "ipv6"  then "fd43::/112"
                         when "dual"  then "10.43.0.0/16,fd43::/112"
                         when "dual6" then "fd43::/112,10.43.0.0/16"
                         else              "10.43.0.0/16"
                         end
k3s_flannel_ipv6_masq = (network_stack == "ipv6" || network_stack == "dual" || network_stack == "dual6") ? "--flannel-ipv6-masq" : "#--flannel-ipv6-masq (ipv4 mode)"

worker_cpu = "3"
worker_memory = "3584"

kubeconfig_file = "libvirt-ubuntu-k3s.config"
k3s_token = "libvirt-ubuntu-token"

# block disk is needed by Longhorn engine V2
enable_longhorn_v2_engine = "true"
#enable_longhorn_v2_engine = "false"
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

# Single source of truth for Longhorn default settings.
# Keys: kebab-case (native Longhorn format).
# Values: YAML value strings as they appear after the colon (e.g. "\"true\"", "'{\\"v2\\": \\"false\\"}'").
# Used to generate both the embedded ConfigMap and longhorn-values.yaml.
longhorn_default_settings = {
  "create-default-disk-labeled-nodes"            => %q("true"),
  "v2-data-engine"                               => "\"#{enable_longhorn_v2_engine}\"",
  "data-engine-hugepage-enabled"                 => %q('{"v2": "false"}'),
  "data-engine-interrupt-mode-enabled"           => %q('{"v2": "true"}'),
  "deleting-confirmation-flag"                   => %q("true"),
  "storage-reserved-percentage-for-default-disk" => %q("0"),
  "allow-collecting-longhorn-usage-metrics"      => %q("false"),
  "backup-target"                                => backup_target == "nfs" \
    ? %q("nfs://longhorn-test-nfs-svc.default:/opt/backupstore") \
    : %q("s3://backupbucket@us-east-1/"),
}
longhorn_default_settings["backup-target-credential-secret"] = %q("longhorn-backup-target-secret") if backup_target != "nfs"

kebab_to_camel = ->(key) {
  parts = key.split('-')
  parts[0] + parts[1..].map { |p| p.capitalize }.join
}

# 4-space-indented lines for the default-setting.yaml block scalar (backup-* excluded).
longhorn_configmap_setting_lines = longhorn_default_settings
  .reject { |k, _| k.start_with?("backup-") }
  .map    { |k, v| "    #{k}: #{v}" }
  .join("\n")

# 4-space-indented lines for the default-resource.yaml block scalar (backup-* only, quoted keys).
longhorn_configmap_resource_lines = longhorn_default_settings
  .select { |k, _| k.start_with?("backup-") }
  .map    { |k, v| "    \"#{k}\": #{v}" }
  .join("\n")

# All node IPs for the Minio TLS cert SAN so the cert is valid for access from any node.
minio_san_ips = [master_ip] + workers.values.map { |w| w[:ip] }
if network_stack =~ /ipv6|dual/
  minio_san_ips += [master_ipv6] + workers.values.map { |w| w[:ipv6] }
end

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
    ROLE="${NODE_ROLE:-worker}"
    VAGRANT_DIR=$(pwd)
    WORKDIR="$(mktemp -d)"
    trap "rm -rf -- '${WORKDIR}'" EXIT
    echo "Change to workdir ${WORKDIR}"
    pushd "${WORKDIR}"

    echo "Provision node role $NODE_ROLE"

    echo 'System disk ...'
    if [ "$ROLE" == "master" ]; then
      SYSTEM_LOG_DISK_DEVICE="/dev/vdb"
    else
      SYSTEM_LOG_DISK_DEVICE="/dev/vdd"
    fi
    mkfs.ext4 "$SYSTEM_LOG_DISK_DEVICE"
    mkdir -p /mnt/temp_log
    mount "$SYSTEM_LOG_DISK_DEVICE" /mnt/temp_log
    rsync -aHAX /var/log/ /mnt/temp_log/
    UUID=$(blkid -s UUID -o value "$SYSTEM_LOG_DISK_DEVICE")
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID /var/log ext4 defaults 0 2" >> /etc/fstab
    fi
    umount /mnt/temp_log && rm -r /mnt/temp_log
    mount -a
    systemctl restart rsyslog

    if [ "${ROLE}" != "master" ]; then
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
    fi
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

    # IPv6: Assign static ULA address to the storage interface (eth1).
    # We write a netplan fragment so the address survives reboots.
    # The file only declares the IPv6 address; Vagrant manages the IPv4 side.
    # NOTE: printf is used instead of a heredoc to avoid a zero-indented
    # closing delimiter (e.g. NETPLAN) that would cause Ruby <<~SHELL to
    # strip 0 chars from all lines, breaking the LOGROTATE_CONFIG heredoc.
    if [[ -n "${NODE_IPV6}" ]]; then
      echo "IPv6: assigning ${NODE_IPV6}/64 to eth1"
      printf 'network:\n  version: 2\n  ethernets:\n    eth1:\n      addresses:\n        - "%s/64"\n' \
        "${NODE_IPV6}" >/etc/netplan/60-eth1-ipv6.yaml
      chmod 600 /etc/netplan/60-eth1-ipv6.yaml
      netplan apply
      echo "IPv6: current eth1 addresses:"
      ip -6 addr show eth1
    fi

    if [ "${ROLE}" != "master" ]; then
      echo 'Prepare disks for Longhorn ...'
      [[ -d #{longhorn_default_fs_disk_path} ]] && echo '  - default filesystem disk ready'
      [[ -b #{longhorn_default_blk_disk_device} ]] && echo '  - default block disk ready'
    else
      echo 'Skipping Longhorn data disk preparation on master'
    fi

    # kernel modules for SPDK
    echo nvme_tcp | sudo tee /etc/modules-load.d/nvme_tcp.conf
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
    --bind-address=#{master_bind_ip}
    --node-external-ip=#{master_node_ip}
    --node-taint='node-role.kubernetes.io/control-plane:NoSchedule'
    --node-taint='node-role.kubernetes.io/master=true:NoExecute'
    --flannel-iface eth1
    #--disable-helm-controller
    --cluster-cidr=#{k3s_cluster_cidr}
    --service-cidr=#{k3s_service_cidr}
    --node-ip=#{master_node_ip}
    #{k3s_flannel_ipv6_masq}
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
    K8S_READY_TIMEOUT=$(( $(date +%s) + 300 ))
    while [ "$(date +%s)" -lt "$K8S_READY_TIMEOUT" ] &&
      ! kubectl -n kube-system get deployment coredns 2>/dev/null &&
      kubectl get node "$NODE_NAME" 2>/dev/null; do
      sleep 1
    done
    kubectl label node "$NODE_NAME" node-role.kubernetes.io/master=true --overwrite
    kubectl -n kube-system patch deployment coredns \
      --type='merge' \
      -p '
    {
      "spec": {
        "template": {
          "spec": {
            "nodeSelector": {
              "node-role.kubernetes.io/control-plane": "true"
            },
            "tolerations": [
              {
                "key": "node-role.kubernetes.io/control-plane",
                "operator": "Exists",
                "effect": "NoSchedule"
              },
              {
                "key": "node-role.kubernetes.io/master",
                "operator": "Exists",
                "effect": "NoExecute"
              }
            ]
          }
        }
      }
    }'

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
            }, {
              "key": "node-role.kubernetes.io/master",
              "operator": "Exists",
              "effect": "NoExecute"
            }
          ]
        }
      ]'

    echo "Skipping Longhorn default disk config on master ${NODE_NAME}"

    #echo "Install Longhorn prerequisite dependencies ..."
    #longhornctl --image longhornio/longhorn-cli:#{longhorn_cli_image_version} install preflight --enable-spdk

    if [[ -n "#{longhorn_version}" ]]; then
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
    #{longhorn_configmap_setting_lines}
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: longhorn-default-resource
      namespace: longhorn-system
    data:
      default-resource.yaml: |
    #{longhorn_configmap_resource_lines}
    YAML

    fi

    if [[ "#{backup_target}" == "nfs" ]]; then
      echo "Deploy NFS backup store ..."
      (cd /tmp && KUBECONFIG=/etc/rancher/k3s/k3s.yaml bash /vagrant/deploy_nfs.sh)
      kubectl -n default rollout status deploy/longhorn-test-nfs --timeout=180s
      echo "NFS backup store ready: nfs://longhorn-test-nfs-svc.default:/opt/backupstore"
    else
      echo "Deploy Minio backup store ..."
      kubectl create namespace longhorn-system 2>/dev/null || true
      (cd /tmp && MINIO_SAN_IPS="#{minio_san_ips.join(',')}" KUBECONFIG=/etc/rancher/k3s/k3s.yaml bash /vagrant/deploy_minio.sh)
      kubectl -n default rollout status deploy/longhorn-backup-target --timeout=180s
      echo "Minio backup store ready: s3://backupbucket@us-east-1/ secret=longhorn-backup-target-secret"
    fi

    SHELL

provision_worker_script = <<~SHELL
    echo 'Install K3s ...'

    INSTALL_K3S_ARGS=(
    --token "#{k3s_token}"
    --kubelet-arg=node-status-update-frequency=5s
    --kubelet-arg=hairpin-mode=promiscuous-bridge
    --server #{master_server_url}
    --flannel-iface eth1
    )

    # Download the k3s binary directly (air-gap method) to probe for flag support
    # before finalising INSTALL_K3S_ARGS, without triggering a full installation.
    curl -sfL "#{k3s_bin_url}" -o /usr/local/bin/k3s
    chmod +x /usr/local/bin/k3s

    # --bind-address was added to k3s agent after v1.23; probe the installed binary so
    # the flag is only included on versions that actually support it (IPv6/dual-stack).
    if [[ -n "${NODE_BIND_IP}" ]]; then
      INSTALL_K3S_ARGS+=(
        --node-external-ip=${NODE_NODE_IP:-${NODE_BIND_IP}}
        --node-ip=${NODE_NODE_IP:-${NODE_BIND_IP}}
      )
      if k3s agent --help 2>&1 | grep -q -- '--bind-address'; then
        INSTALL_K3S_ARGS+=(--bind-address=${NODE_BIND_IP})
      fi
    fi

    export K3S_TOKEN="#{k3s_token}" K3S_KUBECONFIG_MODE="644"
    # Binary already in place from the air-gap download; INSTALL_K3S_SKIP_DOWNLOAD tells
    # the installer to skip the download and use the existing binary at /usr/local/bin/k3s.
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="#{k3s_version}" INSTALL_K3S_EXEC="agent" INSTALL_K3S_SKIP_DOWNLOAD=true sh -s - "${INSTALL_K3S_ARGS[@]}"

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

def cwd_path(env, *parts);    File.join(env.cwd.to_s, *parts);           end
def shared_path(env, *parts); File.join(env.cwd.to_s, "shared", *parts); end

Vagrant.configure("2") do |config|
  config.vm.box = box_image
  #config.vm.provision "shell", inline: provision_cgroup_v1, reboot: true
  config.vm.synced_folder "./shared", "/vagrant_shared", type: "virtiofs"

  config.vm.provider :libvirt do |provider|
    provider.memorybacking :access, :mode => "shared" # needed by virtio-fs share folder
  end

  config.trigger.after :status do |trigger|
    trigger.ruby do | env, machine |
      puts "Kubernetes KUBECONFIG: #{shared_path(env, kubeconfig_file)}"
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
      trigger.name = "Generate longhorn-values.yaml"
      trigger.ruby do |env, machine|
        lines = ["defaultSettings:"]
        longhorn_default_settings.each do |k, v|
          camel = k.split('-').each_with_index.map { |p, i| i == 0 ? p : p.capitalize }.join
          lines << "  #{camel}: #{v}"
        end
        lines << "longhornUI:"
        lines << "  tolerations:"
        lines << "  - effect: NoSchedule"
        lines << "    key: node-role.kubernetes.io/control-plane"
        lines << "    operator: Exists"
        out = shared_path(env, "longhorn-values.yaml")
        File.write(out, lines.join("\n") + "\n")
        puts "Generated #{out}"
      end
    end
    master.trigger.before :up do |trigger|
      trigger.name = "Create libvirt network"
      trigger.info = "Ensuring libvirt network exists"
      trigger.ruby do |env, machine|
        script = cwd_path(env, "create_libvirt_network.sh")
        system("bash", script, libvirt_network_name, libvirt_network_interface,
               libvirt_network_subnet_ipv4, libvirt_network_subnet_ipv6, network_stack)
      end
    end
    master.trigger.after :up do |trigger|
      trigger.name = "Kubernetes cluster Information"
      trigger.ruby do | env, machine |
        puts "Kubernetes cluster available with KUBECONFIG=#{shared_path(env, kubeconfig_file)}"
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
        device: 'vdb',
      }
      #provider.management_network_keep = true
    end
    master.vm.provision "master_node_setup",
      type: "shell",
      inline: provision_all_node_script,
      env: { NODE_NAME: master_host, NODE_ROLE: "master",
             NODE_IPV6: (network_stack == "ipv6" || network_stack == "dual" || network_stack == "dual6") ? master_ipv6 : "" }
    master.vm.provision "master",
      type: "shell",
      inline: provision_master_script,
      env: { NODE_NAME: master_host, NODE_ROLE: "master" }
  end

  workers.each do |worker_name, worker_addrs|
    worker_ip   = worker_addrs[:ip]
    worker_ipv6 = worker_addrs[:ipv6]
    config.vm.define worker_name do |worker|
      worker.trigger.before :up do |trigger|
        trigger.name = "Wait master node"
        trigger.info = "Wait for Kubernetes API server"
        trigger.ruby do |env, machine|
          script = cwd_path(env, "wait_k8s.sh")
          kubeconfig = shared_path(env, kubeconfig_file)
          system("bash", script, kubeconfig, "600")
        end
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
      worker_bind_ip = (network_stack == "ipv6" || network_stack == "dual6") ? worker_ipv6 : worker_ip
      worker_node_ip = case network_stack
                       when "dual"  then "#{worker_ip},#{worker_ipv6}"
                       when "dual6" then "#{worker_ipv6},#{worker_ip}"
                       else              worker_bind_ip
                       end
      worker.vm.provision "worker_node_setup",
        type: "shell",
        inline: provision_all_node_script,
        env: { NODE_IP: worker_ip, NODE_NAME: worker_name, NODE_ROLE: "worker",
               NODE_IPV6:    (network_stack == "ipv6" || network_stack == "dual" || network_stack == "dual6") ? worker_ipv6 : "",
               NODE_BIND_IP: worker_bind_ip }
      worker.vm.provision "worker",
        type: "shell",
        after: "master",
        inline: provision_worker_script,
        env: { NODE_IP: worker_ip, NODE_NAME: worker_name, NODE_ROLE: "worker",
               NODE_IPV6:    (network_stack == "ipv6" || network_stack == "dual" || network_stack == "dual6") ? worker_ipv6 : "",
               NODE_BIND_IP: worker_bind_ip,
               NODE_NODE_IP: worker_node_ip }
    end
  end
end
