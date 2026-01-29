#!/bin/bash
set -e

export LIBVIRT_DEFAULT_URI="qemu+unix:///system?socket=/var/run/libvirt/libvirt-sock"

NETWORK_NAME=$1
NETWORK_INTERFACE=$2
SUBNET=$3

if [[ -z $NETWORK_NAME || -z $SUBNET ]]; then
  echo "usage: $0 <network_name> <network_interface> <subnet>"
  echo "example: $0 vagrant-longhorn virsh1 192.168.156"
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap "rm -rf -- '${WORKDIR}'" EXIT

NETWORK_DEFINE_FILE="${WORKDIR}/libvirt_network.xml"
cat >"${NETWORK_DEFINE_FILE}" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <bridge name="${NETWORK_INTERFACE}" zone="trusted" stp="on" delay="0"/>
  <forward mode="nat"/>
  <ip address="${SUBNET}.1" netmask="255.255.255.0" />
</network>
EOF

if ! virsh net-info "${NETWORK_NAME}" >/dev/null 2>&1; then
  virsh net-define "${NETWORK_DEFINE_FILE}"
  virsh net-autostart "${NETWORK_NAME}"
  virsh net-start "${NETWORK_NAME}"
  echo "Network "${NETWORK_NAME}" created and activated"
else
  echo "Network "${NETWORK_NAME}" already exists"
fi
