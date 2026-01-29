#!/bin/bash

statefulset_name="web-state-rwo-$(date '+%Y%m%d%H%M%S')"
volume_size_mb=${1:-10}
write_size_mb=${2:-10}

echo "statefulset_name='$statefulset_name'"
echo "volume_size_mb=$volume_size_mb"
echo "write_size_mb=$write_size_mb"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${statefulset_name}
spec:
  selector:
    matchLabels:
      app: nginx-state-rwo # has to match .spec.template.metadata.labels
  serviceName: "nginx-state-rwo"
  replicas: 1 # by default is 1
  template:
    metadata:
      labels:
        app: nginx-state-rwo # has to match .spec.selector.matchLabels
    spec:
      restartPolicy: Always
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx-state-rwo
        image: nginx:stable
        ports:
        - containerPort: 80
          name: web-state-rwo
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
#      accessModes:
#        - ReadWriteOnce
#        - ReadWriteMany
      storageClassName: "longhorn"
      resources:
        requests:
          storage: ${volume_size_mb}Mi
EOF
echo "to cleanup ${statefulset_name}:"
echo "kubectl delete statefulsets/${statefulset_name} pvc/www-${statefulset_name}-0"
kubectl rollout status "statefulset/${statefulset_name}"
kubectl exec -it "${statefulset_name}-0" -- /bin/bash -c "dd if=/dev/urandom of='/usr/share/nginx/html/${write_size_mb}m' bs=1M count=$write_size_mb oflag=direct status=progress && md5sum /usr/share/nginx/html/${write_size_mb}m"
kubectl exec -it "${statefulset_name}-0" -- /bin/bash -c "sync"
