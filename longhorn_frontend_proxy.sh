#!/bin/bash

EXPORT_PORT=8080

echo "Proxy the Longhorn frontend to http://localhost:${EXPORT_PORT} ..."
KUBECONFIG=shared/k3s.yaml kubectl port-forward -n longhorn-system svc/longhorn-frontend ${EXPORT_PORT}:80
