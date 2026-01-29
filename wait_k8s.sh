#!/bin/bash

KUBECONFIG=$1
TIMEOUT=${2:-300} # seconds

if [[ -z $KUBECONFIG ]]; then
  echo "usage: $0 <kubeconfig> [<timeout_sec>]"
  echo "example: $0 ~/.kube/config 300"
  exit 1
fi

KUBECONFIG=$(realpath "${KUBECONFIG}")

echo "Waiting for Kubernetes cluster using config ${KUBECONFIG}"
START=$(date +%s)
while [[ $(($(date +%s) - START)) -lt $TIMEOUT ]]; do
  if [[ ! -f $KUBECONFIG ]]; then
    continue
  elif ! OUTPUT=$(KUBECONFIG="${KUBECONFIG}" kubectl cluster-info 2>/dev/null); then
    echo "${OUTPUT}"
    echo "KUBECONFIG ready."
    exit 0
  fi
  sleep 1
done

if [[ ! -f $KUBECONFIG ]]; then
  echo "KUBECONFIG file not exist."
else
  echo "Kubernetes cluster not ready."
fi
exit 1
