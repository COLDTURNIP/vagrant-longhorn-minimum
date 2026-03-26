#!/bin/bash
set -e

export LIBVIRT_DEFAULT_URI="qemu+unix:///system?socket=/var/run/libvirt/libvirt-sock"

NETWORK_NAME=$1
NETWORK_INTERFACE=$2
SUBNET_IPV4=$3
SUBNET_IPV6=$4
NETWORK_STACK=${5:-ipv4}

if [[ -z "$NETWORK_NAME" || -z "$SUBNET_IPV4" ]]; then
  echo "usage: $0 <network_name> <interface> <subnet_ipv4> <subnet_ipv6> [network_stack]"
  echo "  network_stack: ipv4 (default), ipv6, dual, dual6"
  echo "example: $0 vagrant-longhorn virbr1 192.168.156 fd00:dead:beef dual6"
  exit 1
fi

case "$NETWORK_STACK" in
  ipv6|dual|dual6)
    if [[ -z "$SUBNET_IPV6" ]]; then
      echo "error: subnet_ipv6 is required for network_stack=${NETWORK_STACK}"
      exit 1
    fi
    ;;
  ipv4) ;;
  *)
    echo "error: unknown network_stack '${NETWORK_STACK}'. Use: ipv4, ipv6, dual, dual6"
    exit 1
    ;;
esac

WORKDIR="$(mktemp -d)"
trap "rm -rf -- '${WORKDIR}'" EXIT

NETWORK_DEFINE_FILE="${WORKDIR}/libvirt_network.xml"

case "$NETWORK_STACK" in
  ipv4)
    cat >"${NETWORK_DEFINE_FILE}" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <bridge name="${NETWORK_INTERFACE}" zone="trusted" stp="on" delay="0"/>
  <forward mode="nat"/>
  <ip address="${SUBNET_IPV4}.1" netmask="255.255.255.0"/>
</network>
EOF
    ;;
  ipv6)
    cat >"${NETWORK_DEFINE_FILE}" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <bridge name="${NETWORK_INTERFACE}" zone="trusted" stp="on" delay="0"/>
  <forward mode="nat"/>
  <ip family="ipv6" address="${SUBNET_IPV6}::1" prefix="64"/>
</network>
EOF
    ;;
  dual|dual6)
    cat >"${NETWORK_DEFINE_FILE}" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <bridge name="${NETWORK_INTERFACE}" zone="trusted" stp="on" delay="0"/>
  <forward mode="nat"/>
  <ip address="${SUBNET_IPV4}.1" netmask="255.255.255.0"/>
  <ip family="ipv6" address="${SUBNET_IPV6}::1" prefix="64"/>
</network>
EOF
    ;;
esac

if ! virsh net-info "${NETWORK_NAME}" >/dev/null 2>&1; then
  virsh net-define "${NETWORK_DEFINE_FILE}"
  virsh net-autostart "${NETWORK_NAME}"
  virsh net-start "${NETWORK_NAME}"
  echo "Network ${NETWORK_NAME} created and activated (stack: ${NETWORK_STACK})"
else
  echo "Network ${NETWORK_NAME} already exists; not modifying"
fi
