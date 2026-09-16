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
KEY_FILE="vagrant-garage-private.key"
CERT_FILE="vagrant-garage-selfsigned.crt"
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
rpc_secret=$(openssl rand -hex 32)

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
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${NAME}-config
  namespace: default
data:
  garage.toml: |
    metadata_dir = "/data/meta"
    data_dir = "/data/data"
    db_engine = "sqlite"
    replication_factor = 1
    rpc_bind_addr = "127.0.0.1:3901"
    rpc_public_addr = "127.0.0.1:3901"
    rpc_secret = "$rpc_secret"

    [s3_api]
    s3_region = "us-east-1"
    api_bind_addr = "127.0.0.1:3900"
    root_domain = ".s3.garage.localhost"
  nginx.conf: |
    events {}
    http {
      server {
        listen 9000 ssl;
        listen [::]:9000 ssl;
        server_name _;

        ssl_certificate /certs/public.crt;
        ssl_certificate_key /certs/private.key;
        ssl_protocols TLSv1.2 TLSv1.3;

        client_max_body_size 0;
        proxy_request_buffering off;
        proxy_buffering off;

        location / {
          proxy_pass http://127.0.0.1:3900;
          proxy_http_version 1.1;
          proxy_set_header Host \$http_host;
          proxy_set_header Connection "";
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  namespace: default
  labels:
    app: garage-${NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: garage-${NAME}
  template:
    metadata:
      labels:
        app: garage-${NAME}
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
      - name: garage-volume
        emptyDir: {}
      - name: garage-config
        configMap:
          name: ${NAME}-config
      - name: garage-certificates
        secret:
          secretName: $secret_name
          items:
          - key: AWS_CERT
            path: public.crt
          - key: AWS_CERT_KEY
            path: private.key
      containers:
      - name: garage
        image: dxflrs/garage:v2.4.1@sha256:9c96caa2612d3411acc5b0e6701fb238dbfba33e533a6d7d3d811a4b12d0d020
        command:
        - /garage
        - server
        args:
        - --single-node
        - --default-bucket
        env:
        - name: GARAGE_CONFIG_FILE
          value: /etc/garage.toml
        - name: GARAGE_DEFAULT_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_ACCESS_KEY_ID
        - name: GARAGE_DEFAULT_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: AWS_SECRET_ACCESS_KEY
        - name: GARAGE_DEFAULT_BUCKET
          value: backupbucket
        ports:
        - containerPort: 3900
        readinessProbe:
          exec:
            command:
            - /garage
            - status
        volumeMounts:
        - name: garage-volume
          mountPath: /data
        - name: garage-config
          mountPath: /etc/garage.toml
          subPath: garage.toml
          readOnly: true
      - name: nginx
        image: nginx:1.31.6-alpine@sha256:17ad11d84df6c69e327c0894125f712ec1f1de627b5e5ed7e12ca2ed8cd5daf8
        ports:
        - containerPort: 9000
        readinessProbe:
          tcpSocket:
            port: 9000
        volumeMounts:
        - name: garage-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        - name: garage-certificates
          mountPath: /certs
          readOnly: true
---
apiVersion: v1
kind: Service
metadata:
  name: $service_name
  namespace: default
spec:
  selector:
    app: garage-${NAME}
  ports:
    - port: 9000
      targetPort: 9000
      protocol: TCP
  sessionAffinity: ClientIP
EOF
# restart the deployment to ensure the secret is loaded.
kubectl -n default rollout restart deploy/${NAME}

cat <<NOTE
Garage backupstore is now serving through Nginx with self-signed TLS as deployment default/${NAME}:

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
