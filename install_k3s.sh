#!/usr/bin/bash

# Input Parameters
K8S_VERSION=${K8S_VERSION:-'v1.30.10'}
K8S_TOKEN_PATH=${K8S_TOKEN_PATH:-'/vagrant_shared/arch-token'}
K8S_KUBECONFIG_PATH=${K8S_KUBECONFIG_PATH:-'/vagrant_shared/arch-k3s.yaml'}
K8S_ROLE=${K8S_ROLE:-'worker'}
K8S_MASTER_IP=${K8S_MASTER_IP:-''}

if [[ $K8S_ROLE != 'worker' && $K8S_ROLE != 'master' ]]; then
  echo "Invalid K8S_ROLE: '${K8S_ROLE}'"
  exit 1
fi
if [[ -z $K8S_MASTER_IP ]]; then
  echo "Invalid K8S_MASTER_IP: not set"
  exit 1
fi

# Constants
K3S_VERSION="${K8S_VERSION}+k3s1"
K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s"
SERVICE_FILE="/etc/systemd/system/k3s.service"

# Add K3S
echo "Downloading K3s..."
curl -Lo /tmp/k3s "$K3S_URL"
chmod +x /tmp/k3s
mv /tmp/k3s /usr/local/bin/

if [[ $K8S_ROLE == 'master' ]]; then
  echo 'Setup master node...'
  K3S_TOKEN=''
  K3S_ARGS=(
    --bind-address=${K8S_NODE_IP}
    --node-external-ip=${K8S_NODE_IP}
    --flannel-iface eth0
  )
else
  echo 'Setup worker node...'
  K3S_TOKEN=$(cat "${K8S_TOKEN_PATH}")
  K3S_ARGS=(
    --bind-address=${K8S_MASTER_IP}
    --token=${K3S_TOKEN}
    --flannel-iface eth0
  )
fi

# Create a Systemd Service for the K3s Server
echo "Creating master node systemd service file..."

# Token not provided; K3s will generate one automatically
tee "${SERVICE_FILE}" <<EOF
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/k3s server ${K3S_ARGS[@]}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and Start K3s Server
echo "Reloading systemd and starting K3s server..."
systemctl daemon-reload
systemctl start k3s
systemctl enable k3s

# Verify the Installation
echo "Verifying the installation..."
systemctl status k3s

# Wait for K3s to initialize and create necessary files
echo "Waiting for K3s to initialize..."
for i in {1..20}; do
  if [[ ! -f /var/lib/rancher/k3s/server/node-token ]]; then
    echo "node-token not found, retrying in 10 seconds..."
    sleep 10
  else
    break
  fi
done
echo "K3s node token:"
cat /var/lib/rancher/k3s/server/node-token
if [[ $K8S_ROLE == 'master' ]]; then
  cp /var/lib/rancher/k3s/server/node-token "${K8S_TOKEN_PATH}"
fi

# Set up kubeconfig
echo "Setting up kubeconfig..."
if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
  mkdir -p ~vagrant/.kube
  cp /etc/rancher/k3s/k3s.yaml ~vagrant/.kube/config
  chown vagrant:vagrant ~vagrant/.kube/config
  export KUBECONFIG=~vagrant/.kube/config

  cp /etc/rancher/k3s/k3s.yaml "${K8S_KUBECONFIG_PATH}"
  chmod a+r "${K8S_KUBECONFIG_PATH}"

  echo "Kubeconfig set up successfully."
else
  echo "k3s.yaml not found, please check K3s installation."
  exit 1
fi
