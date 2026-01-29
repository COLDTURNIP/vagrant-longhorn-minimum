#!/bin/bash

# CRD Version Comparison Script with jq
# Usage: ./crd_jq_compare.sh <CRD_NAME> <VERSION>
# Example: ./crd_jq_compare.sh certificates.cert-manager.io v1

CRD_NAME=$1
VERSION=$2

if [[ -z "$CRD_NAME" || -z "$VERSION" ]]; then
    echo "Usage: $0 <CRD_NAME> <VERSION>"
    exit 1
fi

# Get CRD definition and convert to JSON
CRD_JSON=$(kubectl get crd "$CRD_NAME" -o json | jq)

# Validate version exists
if ! jq -e ".spec.versions[] | select(.name == \"$VERSION\")" <<< "$CRD_JSON" > /dev/null; then
    echo "Version $VERSION not found in CRD $CRD_NAME"
    exit 1
fi

# Recursive property extraction function
process_schema() {
    jq -r --arg prefix "$1" '
    def get_type: 
        if .type then .type 
        elif .properties then "object"
        else "unknown" end;
        
    def process_props($path):
        .properties | to_entries[] | 
        if (.value | has("properties")) then
            { path: ($path + .key), type: "object" }, 
            (.value | process_props($path + .key + "."))
        else
            { path: ($path + .key), type: (.value | get_type) }
        end;
    
    process_props($prefix + ".") | "\(.path)\t\(.type)"
    '
}

# Generate report
echo "CRD Version Comparison Report for $CRD_NAME ($VERSION)"
echo "======================================================="
printf "%-40s | %-20s\n" "Property Path" "Type"
echo "-------------------------------------------------------"

# Process spec and status
jq -r ".spec.versions[] | select(.name == \"$VERSION\") | .schema.openAPIV3Schema" <<< "$CRD_JSON" | 
{
    # Process spec
    echo "[Spec Fields]"
    process_schema "spec" | grep '^spec\.' |
    awk -F'\t' '{printf "%-40s | %-20s\n", $1, $2}'
}
jq -r ".spec.versions[] | select(.name == \"$VERSION\") | .schema.openAPIV3Schema" <<< "$CRD_JSON" | 
{
    # Process status
    echo "[Status Fields]"
    process_schema "status" | grep '^status\.' |
    awk -F'\t' '{printf "%-40s | %-20s\n", $1, $2}'
}
