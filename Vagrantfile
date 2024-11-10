# -*- mode: ruby -*-
# vi: set ft=ruby :

# =====
# Usage
# =====
#
# ```
# $ vagrant up --provider=virtualbox
# ```
#
# It will take more than 10 minutes to install reqired modules on each nodes.
#
# ==========
# References
# ==========
# - https://akos.ma/blog/vagrant-k3s-and-virtualbox/
# - https://medium.com/@dharsannanantharaman/create-a-high-availabilty-lightweight-kubernetes-k3s-cluster-using-vagrant-822a1e025855
# - https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning

provider = "virtualbox"
box_image = "generic/ubuntu2204"

longhorn_version = 'v1.7.2'

master_ip = "192.168.56.20"
master_cpu = "2"
master_memory = "2048"

workers = { "k3s-worker1" => "192.168.56.21",
            "k3s-worker2" => "192.168.56.22",
           }
worker_cpu = "1"
worker_memory = "1536"

# Extra parameters in INSTALL_K3S_EXEC variable because of
# K3s picking up the wrong interface when starting master and worker
# https://github.com/alexellis/k3sup/issues/306

provision_master_script = <<-SHELL
    export INSTALL_K3S_EXEC="--bind-address=#{master_ip} --node-external-ip=#{master_ip} --flannel-iface eth1"
    curl -sfL https://get.k3s.io | sh -
    echo "Sleeping for 5 seconds to wait for k3s to start"
    sleep 5
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    cp $KUBECONFIG /vagrant_shared
    cp /var/lib/rancher/k3s/server/token /vagrant_shared

    apt install -y jq
    snap install k9s --devmode

    mkdir tmp
    curl -sSfL -o tmp/longhornctl https://github.com/longhorn/cli/releases/download/#{longhorn_version}/longhornctl-linux-amd64
    chmod +x tmp/longhornctl
    mv tmp/longhornctl /usr/bin/
    rm -r tmp

    echo 'Install Longhorn #{longhorn_version} ...'
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-iscsi-installation.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/prerequisite/longhorn-nfs-installation.yaml
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/#{longhorn_version}/deploy/longhorn.yaml
    echo 'Longhorn #{longhorn_version} installed. It would take several minutes for pods get ready.'
    SHELL

provision_worker_script = <<-SHELL
    export INSTALL_K3S_EXEC="--flannel-iface eth1"
    export K3S_TOKEN_FILE=/vagrant_shared/token
    export K3S_URL=https://#{master_ip}:6443
    curl -sfL https://get.k3s.io | sh -
    SHELL

Vagrant.configure("2") do |config|
  config.vm.box = box_image

  config.vm.define "k3s-master", primary: true do |master|
    master.vm.network "private_network", ip: master_ip
    master.vm.synced_folder "./shared", "/vagrant_shared"
    master.vm.hostname = "k3s-master"
    master.vm.provider provider do |vb|
      vb.name = "k3s-master"
      vb.memory = master_memory
      vb.cpus = master_cpu
    end
    master.vm.provision "shell", inline: provision_master_script
  end

  workers.each do |worker_name, worker_ip|
    config.vm.define worker_name do |worker|
      worker.vm.network "private_network", ip: worker_ip
      worker.vm.synced_folder "./shared", "/vagrant_shared"
      worker.vm.hostname = worker_name
      worker.vm.provider provider do |vb|
      vb.name = worker_name
        vb.memory = worker_memory
        vb.cpus = worker_cpu
      end
      worker.vm.provision "shell", inline: provision_worker_script
    end
  end
end
