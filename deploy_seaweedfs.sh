#!/bin/bash
#set -x

VAGRANT_CMD=${VAGRANT_CMD:-vagrant}
NAME=${1:-longhorn-backup-target}

host_ips=()
san_ip=''
if [[ -n "${S3_SAN_IPS}" ]]; then
  # IPs provided directly (e.g., called from inside a Vagrant provisioner).
  IFS=',' read -ra host_ips <<< "${S3_SAN_IPS}"
  for ip in "${host_ips[@]}"; do
    san_ip="${san_ip},IP:${ip}"
  done
else
  hosts=( $( ${VAGRANT_CMD} status --machine-readable | cut -d',' -f2 2>/dev/null | sort | uniq ) )
  if [[ $hosts == '' ]]; then
    echo 'Error: no Vagrant instance detected. Check the vagrantfile and the instance provisioning.'
    exit 1
  fi
  for host in ${hosts[@]} ; do
    host_ip=$(${VAGRANT_CMD} ssh $host -- "hostname -I | cut -d' ' -f2" 2>/dev/null | tr -d '\r')
    echo "host ${host} IP: '${host_ip}'"
    host_ips+=($host_ip)
    san_ip="${san_ip},IP:${host_ip}"
  done
fi

# Variables
SERVICE=${NAME}-service
DOMAIN="${SERVICE}.default"
DAYS=1000
KEY_FILE="vagrant-seaweedfs-private.key"
CERT_FILE="vagrant-seaweedfs-selfsigned.crt"
SAN="DNS:${DOMAIN},DNS:localhost${san_ip}"

# Generate a private key
openssl genrsa -out $KEY_FILE 2048

# Generate a self-signed certificate with SAN
echo "Generating self-signed certificate with SAN=${SAN}"
openssl req -new -x509 -key $KEY_FILE -out $CERT_FILE -days $DAYS -subj "/CN=$DOMAIN" -addext "subjectAltName=$SAN"

echo "Private Key: $(realpath $KEY_FILE)"
echo "Certificate: $(realpath $CERT_FILE)"

# Kubernetes secrets
secret_name="${NAME}-secret"
service_name="${NAME}-service"
encoded_cert=$(printf "%s" "$(<$CERT_FILE)" | base64 -w 0)
encoded_key=$(printf "%s" "$(<$KEY_FILE)" | base64 -w 0)
s3_domain="${DOMAIN}"
s3_host=${host_ips[0]}
s3_port=9000
s3_endpoint="https://${s3_domain}:${s3_port}"
s3_external_endpoint="https://${s3_host}:${s3_port}"
encoded_s3_endpoint=$(echo -n $s3_endpoint | base64)
encoded_s3_external_endpoint=$(echo -n $s3_external_endpoint | base64)

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: default
type: Opaque
data:
  AWS_ACCESS_KEY_ID: bG9uZ2hvcm4tdGVzdC1hY2Nlc3Mta2V5 # longhorn-test-access-key
  AWS_SECRET_ACCESS_KEY: bG9uZ2hvcm4tdGVzdC1zZWNyZXQta2V5 # longhorn-test-secret-key
  AWS_ENDPOINTS: $encoded_s3_endpoint # $s3_endpoint
  AWS_CERT: $encoded_cert
  AWS_CERT_KEY: $encoded_key
---
# same secret for longhorn-system namespace
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: longhorn-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: bG9uZ2hvcm4tdGVzdC1hY2Nlc3Mta2V5 # longhorn-test-access-key
  AWS_SECRET_ACCESS_KEY: bG9uZ2hvcm4tdGVzdC1zZWNyZXQta2V5 # longhorn-test-secret-key
  AWS_ENDPOINTS: $encoded_s3_endpoint # $s3_endpoint
  AWS_CERT: $encoded_cert
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  namespace: default
  labels:
    app: seaweedfs-${NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: seaweedfs-${NAME}
  template:
    metadata:
      labels:
        app: seaweedfs-${NAME}
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
      - name: seaweedfs-volume
        emptyDir: {}
      - name: seaweedfs-certificates
        secret:
          secretName: $secret_name
          items:
          - key: AWS_CERT
            path: public.crt
          - key: AWS_CERT_KEY
            path: private.key
      containers:
      - name: seaweedfs
        image: chrislusf/seaweedfs:4.47@sha256:ce9e796f1fe6f06968f4c04bdaf8f678dad9c8acdfef3d244133d71bfa6bf882
        args:
        - mini
        - -dir=/data
        - -webdav=false
        - -admin.ui=false
        - -s3.port=9000
        - -s3.cert.file=/certs/public.crt
        - -s3.key.file=/certs/private.key
        - -s3.port.iceberg=0
        - -s3.port.lance=0
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_ACCESS_KEY_ID
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_SECRET_ACCESS_KEY
        - name: S3_BUCKET
          value: backupbucket
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: seaweedfs-volume
          mountPath: "/data"
        - name: seaweedfs-certificates
          mountPath: "/certs"
          readOnly: true
---
apiVersion: v1
kind: Service
metadata:
  name: $service_name
  namespace: default
spec:
  selector:
    app: seaweedfs-${NAME}
  ports:
    - port: 9000
      targetPort: 9000
      protocol: TCP
  sessionAffinity: ClientIP
EOF
# restart the deployment to ensure the secret is loaded.
kubectl -n default rollout restart deploy/${NAME}

cat <<NOTE
SeaweedFS backupstore is now serving as deployment default/${NAME}:

  Backup Target: s3://backupbucket@us-east-1/
  Backup Target Credential Secret: $secret_name

To connect the backupstore by a remote cluster, forward the port from the original cluster:

kubectl port-forward services/$service_name 9000:9000 -n default

And the following resources are needed:

kubectl apply -f - <<K8SRESOURCE
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: default
type: Opaque
data:
  AWS_ACCESS_KEY_ID: bG9uZ2hvcm4tdGVzdC1hY2Nlc3Mta2V5 # longhorn-test-access-key
  AWS_SECRET_ACCESS_KEY: bG9uZ2hvcm4tdGVzdC1zZWNyZXQta2V5 # longhorn-test-secret-key
  AWS_ENDPOINTS: $encoded_s3_external_endpoint # $s3_external_endpoint
  AWS_CERT: $encoded_cert
  AWS_CERT_KEY: $encoded_key
---
# same secret for longhorn-system namespace
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: longhorn-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: bG9uZ2hvcm4tdGVzdC1hY2Nlc3Mta2V5 # longhorn-test-access-key
  AWS_SECRET_ACCESS_KEY: bG9uZ2hvcm4tdGVzdC1zZWNyZXQta2V5 # longhorn-test-secret-key
  AWS_ENDPOINTS: $encoded_s3_external_endpoint # $s3_external_endpoint
  AWS_CERT: $encoded_cert
K8SRESOURCE
NOTE
