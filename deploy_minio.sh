#!/bin/bash
#set -x

VAGRANT_CMD=${VAGRANT_CMD:-vagrant}
NAME=${1:-longhorn-backup-target}

hosts=( $( ${VAGRANT_CMD} status --machine-readable | cut -d',' -f2 2>/dev/null | sort | uniq ) )
if [[ $hosts == '' ]]; then
  echo 'Error: no Vagrant instance detected. Check the vagrantfile and the instance provisioning.'
  exit 1
fi

host_ips=()
san_ip=''
for host in ${hosts[@]} ; do
  host_ip=$(${VAGRANT_CMD} ssh $host -- "hostname -I | cut -d' ' -f2" 2>/dev/null | tr -d '\r')
  echo "host ${host} IP: '${host_ip}'"
  host_ips+=($host_ip)
  san_ip="${san_ip},IP:${host_ip}"
done

# Variables
SERVICE=${NAME}-service
DOMAIN="${SERVICE}.default"
DAYS=1000
KEY_FILE="vagrant-minio-private.key"
CERT_FILE="vagrant-minio-selfsigned.crt"
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
minio_domain="${DOMAIN}"
minio_host=${host_ips[0]}
minio_port=9000
minio_endpoint="https://${minio_domain}:${minio_port}"
minio_external_endpoint="https://${minio_host}:${minio_port}"
encoded_minio_endpoint=$(echo -n $minio_endpoint | base64)
encoded_minio_external_endpoint=$(echo -n $minio_external_endpoint | base64)

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
  AWS_ENDPOINTS: $encoded_minio_endpoint # $minio_endpoint
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
  AWS_ENDPOINTS: $encoded_minio_endpoint # $minio_endpoint
  AWS_CERT: $encoded_cert
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  namespace: default
  labels:
    app: minio-${NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio-${NAME}
  template:
    metadata:
      labels:
        app: minio-${NAME}
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
      - name: minio-volume
        emptyDir: {}
      - name: minio-certificates
        secret:
          secretName: $secret_name
          items:
          - key: AWS_CERT
            path: public.crt
          - key: AWS_CERT_KEY
            path: private.key
      containers:
      - name: minio
        image: minio/minio:RELEASE.2022-02-01T18-00-14Z
        command: ["sh", "-c", "mkdir -p /storage/backupbucket && mkdir -p /root/.minio/certs && ln -s /root/certs/private.key /root/.minio/certs/private.key && ln -s /root/certs/public.crt /root/.minio/certs/public.crt && exec minio server /storage"]
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_ACCESS_KEY_ID
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_SECRET_ACCESS_KEY
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: minio-volume
          mountPath: "/storage"
        - name: minio-certificates
          mountPath: "/root/certs"
          readOnly: true
---
apiVersion: v1
kind: Service
metadata:
  name: $service_name
  namespace: default
spec:
  selector:
    app: minio-${NAME}
  ports:
    - port: 9000
      targetPort: 9000
      protocol: TCP
  sessionAffinity: ClientIP
EOF
# restart the deployment to ensure the secret is loaded.
kubectl -n default rollout restart deploy/${NAME}

cat <<NOTE
Minio backupstore is now serving as deployment default/${NAME}:

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
  AWS_ENDPOINTS: $encoded_minio_external_endpoint # $minio_external_endpoint
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
  AWS_ENDPOINTS: $encoded_minio_external_endpoint # $minio_external_endpoint
  AWS_CERT: $encoded_cert
K8SRESOURCE
NOTE
