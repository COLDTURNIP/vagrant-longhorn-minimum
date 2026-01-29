#!/bin/bash

set -x

NAMESPACE="longhorn-system"

# Get all CRDs with both v1beta1 and v1beta2 versions
crds=$(kubectl get crd -n $NAMESPACE | grep longhorn | cut -d' ' -f1)

for crd in $crds; do
  echo "Checking CRD: $crd"
  
  # Get all CRs for this CRD
  crs=$(kubectl get $crd -n $NAMESPACE -o name)
  
  for cr in $crs; do
    echo "  Checking CR: $cr"
    
    # Attempt to convert CR from v1beta1 to v1beta2
    if ! kubectl get $cr -n $NAMESPACE -o yaml | kubectl convert -f - --output-version v1beta2 > /dev/null 2>&1; then
      echo "    Conversion failed for $cr"
      exit 1
    else
      echo "    Conversion successful for $cr"
    fi
  done
done
