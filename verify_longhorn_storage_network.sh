#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KUBECONFIG=${KUBECONFIG:-${SCRIPT_DIR}/shared/libvirt-ubuntu-k3s.config}
LONGHORN_NAMESPACE=longhorn-system
DEMO_NAMESPACE=longhorn-storage-network-demo
STORAGE_CLASS=longhorn-storage-network-demo
STORAGE_NETWORK=${STORAGE_NETWORK:-longhorn-system/vagrant-storage-network}
KEEP_RESOURCES=${KEEP_RESOURCES:-false}

export KUBECONFIG

cleanup() {
    if [ "$KEEP_RESOURCES" = "true" ]; then
        echo "Keeping demo resources in ${DEMO_NAMESPACE}"
        return
    fi
    kubectl delete namespace "$DEMO_NAMESPACE" --ignore-not-found --wait=false >/dev/null
    kubectl delete storageclass "$STORAGE_CLASS" --ignore-not-found >/dev/null
}
trap cleanup EXIT HUP INT TERM

for command_name in kubectl jq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${command_name}" >&2
        exit 1
    fi
done

if [ ! -r "$KUBECONFIG" ]; then
    echo "ERROR: kubeconfig not found: ${KUBECONFIG}" >&2
    exit 1
fi

kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl -n "$LONGHORN_NAMESPACE" rollout status daemonset/longhorn-manager --timeout=600s

SETTING_DEADLINE=$(( $(date +%s) + 600 ))
while [ "$(kubectl -n "$LONGHORN_NAMESPACE" get setting storage-network -o jsonpath='{.value}' 2>/dev/null || true)" != "$STORAGE_NETWORK" ]; do
    if [ "$(date +%s)" -ge "$SETTING_DEADLINE" ]; then
        echo "ERROR: Longhorn storage-network did not become ${STORAGE_NETWORK}" >&2
        exit 1
    fi
    sleep 5
done

kubectl -n "$LONGHORN_NAMESPACE" wait \
    --for=condition=Ready pod \
    -l longhorn.io/component=instance-manager \
    --timeout=600s

INSTANCE_MANAGER_JSON=$(kubectl -n "$LONGHORN_NAMESPACE" get pod \
    -l longhorn.io/component=instance-manager -o json)
INSTANCE_MANAGER_COUNT=$(printf '%s' "$INSTANCE_MANAGER_JSON" | jq '.items | length')
if [ "$INSTANCE_MANAGER_COUNT" -lt 3 ]; then
    echo "ERROR: expected at least three instance-manager pods, found ${INSTANCE_MANAGER_COUNT}" >&2
    exit 1
fi

printf '%s' "$INSTANCE_MANAGER_JSON" | jq -e --arg network "$STORAGE_NETWORK" '
    all(.items[];
        (.metadata.annotations["k8s.v1.cni.cncf.io/network-status"] | fromjson) as $networks |
        any($networks[];
            .name == $network and
            .interface == "lhnet1" and
            (.ips | length) > 0
        )
    )
' >/dev/null

echo "Instance-manager lhnet1 attachments:"
printf '%s' "$INSTANCE_MANAGER_JSON" | jq -r --arg network "$STORAGE_NETWORK" '
    .items[] |
    .metadata.name as $pod |
    (.metadata.annotations["k8s.v1.cni.cncf.io/network-status"] | fromjson)[] |
    select(.name == $network and .interface == "lhnet1") |
    "  \($pod): \(.ips | join(","))"
'

kubectl create namespace "$DEMO_NAMESPACE" >/dev/null 2>&1 || true
kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS}
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  dataEngine: v1
  numberOfReplicas: "3"
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: ${DEMO_NAMESPACE}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${STORAGE_CLASS}
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: ${DEMO_NAMESPACE}
spec:
  containers:
  - name: writer
    image: docker.io/rancher/mirrored-library-busybox:1.36.1
    command:
    - sh
    - -c
    - |
      dd if=/dev/zero of=/data/payload.bin bs=1M count=8
      printf 'longhorn-multus-live-example\n' >/data/result.txt
      sync
      cat /data/result.txt
      sleep 3600
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data
YAML

kubectl -n "$DEMO_NAMESPACE" wait --for=condition=Ready pod/writer --timeout=600s
RESULT=$(kubectl -n "$DEMO_NAMESPACE" exec writer -- cat /data/result.txt)
if [ "$RESULT" != "longhorn-multus-live-example" ]; then
    echo "ERROR: unexpected data read from Longhorn volume: ${RESULT}" >&2
    exit 1
fi

VOLUME_NAME=$(kubectl -n "$DEMO_NAMESPACE" get pvc data -o jsonpath='{.spec.volumeName}')
ENDPOINT_DEADLINE=$(( $(date +%s) + 300 ))
while :; do
    REPLICA_JSON=$(kubectl -n "$LONGHORN_NAMESPACE" get replicas.longhorn.io -o json)
    REPLICA_COUNT=$(printf '%s' "$REPLICA_JSON" | jq --arg volume "$VOLUME_NAME" \
        '[.items[] | select(.spec.volumeName == $volume and .status.storageIP != "")] | length')
    ENGINE_JSON=$(kubectl -n "$LONGHORN_NAMESPACE" get engines.longhorn.io -o json)
    ENGINE_ADDRESS_COUNT=$(printf '%s' "$ENGINE_JSON" | jq --arg volume "$VOLUME_NAME" \
        '[.items[] | select(.spec.volumeName == $volume) | .spec.replicaAddressMap | length] | first // 0')
    if [ "$REPLICA_COUNT" -eq 3 ] && [ "$ENGINE_ADDRESS_COUNT" -eq 3 ]; then
        break
    fi
    if [ "$(date +%s)" -ge "$ENDPOINT_DEADLINE" ]; then
        echo "ERROR: Longhorn did not publish three storage-network replica endpoints" >&2
        exit 1
    fi
    sleep 5
done

printf '%s' "$REPLICA_JSON" | jq -e --arg volume "$VOLUME_NAME" '
    def is_storage_ip:
        if startswith("192.168.156.") then
            (split(".")[-1] | tonumber) >= 128
        else
            startswith("fd00:dead:beef:")
        end;
    all(
        .items[] | select(.spec.volumeName == $volume);
        .status.storageIP | is_storage_ip
    )
' >/dev/null

echo "Replica storage endpoints for ${VOLUME_NAME}:"
printf '%s' "$REPLICA_JSON" | jq -r --arg volume "$VOLUME_NAME" '
    .items[] |
    select(.spec.volumeName == $volume) |
    "  \(.metadata.name): \(.status.storageIP):\(.status.port)"
'
echo "Engine replica address map:"
printf '%s' "$ENGINE_JSON" | jq -r --arg volume "$VOLUME_NAME" '
    .items[] |
    select(.spec.volumeName == $volume) |
    .spec.replicaAddressMap
'
echo "PASS: wrote and read a replicated Longhorn volume through lhnet1 storage endpoints"
