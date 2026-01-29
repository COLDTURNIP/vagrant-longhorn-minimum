#!/bin/bash
set -e

DST_PATH=$1
LONGHORN_VERSION=$2

if [[ -z $DST_PATH ]]; then
  echo "usage: $0 <destination_path> <longhorn_version>"
  echo "example: $0 ./shared/bin v1.8.0"
  exit 1
fi
DST_PATH=$(realpath "${DST_PATH}")
mkdir -p "${DST_PATH}"

WORKDIR="$(mktemp -d)"
trap "rm -rf -- '${WORKDIR}'" EXIT
cd "${WORKDIR}"

function download_longhorn() {
  local longhornctl_name="longhornctl-${LONGHORN_VERSION}"
  if [[ -f $longhornctl_name ]]; then
    return
  fi
  curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/${LONGHORN_VERSION}/longhornctl-linux-amd64
  chmod a+x "longhornctl-${LONGHORN_VERSION}"
  mv "longhornctl-${LONGHORN_VERSION}" "${DST_PATH}"
}

download_longhorn
