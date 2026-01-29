#!/bin/bash

usage() {
    echo "usage: $0 {attach|detach} <NODE_NAME>"
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

SUBCMD="$1"
NODE_NAME="$2"
VAGRANT_CMD='vagrant'
#VAGRANT_CMD='vagrant-libvirt'
VM_NAME="vagrant_${NODE_NAME}"
IFACE_TYPE='network'
IFACE_SOURCE='vagrant-longhorn'
IFACE_MODEL='virtio'

vm_state=$(virsh domstate "$VM_NAME")
if [[ $? != 0 || $vm_state != 'running' ]]; then
  echo "Error: libvirt instance ${VM_NAME} is not running."
  exit 2
fi

# output example:
#
# Interface   Type      Source             Model    MAC
#----------------------------------------------------------------------
# vnet2       network   vagrant-libvirt    virtio   52:54:00:2d:31:3d
# vnet3       network   vagrant-longhorn   virtio   52:54:00:df:a7:60
iface_info=$(virsh domiflist "$VM_NAME" | grep "$IFACE_SOURCE" | xargs)
read IFACE_NAME CUR_IFACE_TYPE CUR_IFACE_SOURCE CUR_IFACE_MODEL IFACE_MAC <<<"$iface_info"

# Lagacy method: detach the Libvirt network interface
# The guest OS need to re-initialize the network after re-attached.
#
# if [[ $CUR_IFACE_TYPE != $IFACE_TYPE || $CUR_IFACE_SOURCE != $IFACE_SOURCE || $CUR_IFACE_MODEL != $IFACE_MODEL ]]; then
#   IFACE_NAME=''
# fi
#
# case "$SUBCMD" in
#   detach)
#     if [[ -z $IFACE_NAME ]]; then
#         echo "Error: cannot find ${IFACE_SOURCE} interface on ${NODE_NAME}"
#         exit 2
#     fi
#     echo "Detaching ${IFACE_SOURCE} interface ${IFACE_NAME} from libvirt instance ${VM_NAME} ..."
#     virsh detach-interface "$VM_NAME" --type "$IFACE_TYPE" --mac "$IFACE_MAC" --live
#     virsh domiflist "$VM_NAME"
#     ;;
#   attach)
#     if [[ -n "$IFACE_NAME" ]]; then
#         echo "Warning: ${IFACE_SOURCE} interface ${IFACE_NAME} is already attached to libvirt instance ${VM_NAME}"
#         exit 2
#     fi
#     echo "Attaching ${IFACE_SOURCE} interface to node $VM_NAME ..."
#     virsh attach-interface "$VM_NAME" --type "$IFACE_TYPE" --source "$IFACE_SOURCE" --model "$IFACE_MODEL" --live
#     virsh domiflist "$VM_NAME"
#     ;;
#   *)
#     usage
#     ;;
# esac


# New method: disable network interface in guest OS

if [[ -z $IFACE_MAC ]]; then
  echo "Error: cannot find the MAC address for for VM network ${IFACE_SOURCE}"
  exit 2
fi
GUEST_IFACE=$("$VAGRANT_CMD" ssh "$NODE_NAME" -- ip -o link | awk -F': ' "/${IFACE_MAC}/ {print \$2}")
if [[ -z $GUEST_IFACE ]]; then
  GUEST_IFACE=$("$VAGRANT_CMD" ssh "$NODE_NAME" -- ip link | grep -B1 "$IFACE_MAC" | head -1 | awk -F: '{print $2}' | tr -d ' ')
fi
if [[ -z $GUEST_IFACE ]]; then
  echo "Error: cannot find the network interface for VM network ${IFACE_SOURCE} on node ${NODE_NAME}"
  exit 2
fi

GUEST_IFACE_STATUS=$("$VAGRANT_CMD" ssh "$NODE_NAME" -- ip link show "$GUEST_IFACE" | grep -o "state [A-Z]*" | awk '{print $2}')

case "$SUBCMD" in
  detach)
    if [[ $GUEST_IFACE_STATUS == 'DOWN' ]]; then
      echo "Warning: the network interface ${GUEST_IFACE} is already ${GUEST_IFACE_STATUS}, skip detaching."
      exit 0
    fi
    echo "Disabling network interface ${GUEST_IFACE} in libvirt instance ${NODE_NAME} ..."
    "$VAGRANT_CMD" ssh "$NODE_NAME" -- sudo ip link set "$GUEST_IFACE" down
    ;;
  attach)
    if [[ $GUEST_IFACE_STATUS == 'UP' ]]; then
      echo "Warning: the network interface ${GUEST_IFACE} is already ${GUEST_IFACE_STATUS}, skip attaching."
      exit 0
    fi
    echo "Enabling network interface ${GUEST_IFACE} in libvirt instance ${NODE_NAME} ..."
    "$VAGRANT_CMD" ssh "$NODE_NAME" -- sudo ip link set "$GUEST_IFACE" up
    ;;
  *)
    usage
    ;;
esac
