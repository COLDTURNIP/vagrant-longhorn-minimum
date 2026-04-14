#!/bin/bash
#set -x

NAME=${1:-longhorn-test-nfs}
SVC_NAME="${NAME}-svc"
EXPORT_PATH="/opt/backupstore"
EXPORT_ID="14"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  namespace: default
  labels:
    app: ${NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${NAME}
  template:
    metadata:
      labels:
        app: ${NAME}
    spec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: "true"
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
        operator: Exists
      - effect: NoExecute
        key: node-role.kubernetes.io/master
        operator: Exists
      volumes:
      - name: nfs-volume
        emptyDir: {}
      - name: ganesha-data
        emptyDir: {}
      containers:
      - name: ${NAME}-container
        image: longhornio/nfs-backupstore:latest
        imagePullPolicy: Always
        env:
        - name: EXPORT_ID
          value: "${EXPORT_ID}"
        - name: EXPORT_PATH
          value: "${EXPORT_PATH}"
        - name: PSEUDO_PATH
          value: "${EXPORT_PATH}"
        - name: NFS_DISK_IMAGE_SIZE_MB
          value: "4096"
        command: ["bash", "-c", "chmod 700 ${EXPORT_PATH} && /opt/start_nfs.sh | tee /var/log/ganesha.log"]
        securityContext:
          privileged: true
          capabilities:
            add: ["SYS_ADMIN", "DAC_READ_SEARCH"]
        volumeMounts:
        - name: nfs-volume
          mountPath: "${EXPORT_PATH}"
        - name: ganesha-data
          mountPath: /usr/local/var/lib/nfs/ganesha
        livenessProbe:
          exec:
            command: ["bash", "-c", "grep \"No export entries found\" /var/log/ganesha.log > /dev/null 2>&1 ; [ \$? -ne 0 ]"]
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 4
---
apiVersion: v1
kind: Service
metadata:
  name: ${SVC_NAME}
  namespace: default
spec:
  selector:
    app: ${NAME}
  clusterIP: None
  ports:
  - name: notnecessary
    port: 1234
    targetPort: 1234
EOF

kubectl -n default rollout status deploy/${NAME} --timeout=180s

BACKUP_URL="nfs://${SVC_NAME}.default:${EXPORT_PATH}"

cat <<NOTE
NFS backupstore is now serving as deployment default/${NAME}:

  Backup Target: ${BACKUP_URL}
  No credential secret is required for NFS.

NOTE
