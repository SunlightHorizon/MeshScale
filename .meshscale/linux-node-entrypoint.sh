#!/usr/bin/env bash
set -euo pipefail

apt-get update >/tmp/meshscale-apt.log 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl docker.io >/tmp/meshscale-apt.log 2>&1

if ! command -v fdbcli >/dev/null 2>&1; then
  ARCH="$(dpkg --print-architecture)"
  if [[ "$ARCH" != "amd64" ]]; then
    echo "FoundationDB Linux package install currently requires an amd64 container. Detected: $ARCH" >&2
    exit 1
  fi
  curl -L --retry 5 --retry-delay 2 \
    -o "/tmp/foundationdb-clients_7.3.69-1_${ARCH}.deb" \
    "https://github.com/apple/foundationdb/releases/download/7.3.69/foundationdb-clients_7.3.69-1_${ARCH}.deb"
  curl -L --retry 5 --retry-delay 2 \
    -o "/tmp/foundationdb-server_7.3.69-1_${ARCH}.deb" \
    "https://github.com/apple/foundationdb/releases/download/7.3.69/foundationdb-server_7.3.69-1_${ARCH}.deb"
  DEBIAN_FRONTEND=noninteractive dpkg -i \
    "/tmp/foundationdb-clients_7.3.69-1_${ARCH}.deb" \
    "/tmp/foundationdb-server_7.3.69-1_${ARCH}.deb" >/tmp/meshscale-fdb-install.log 2>&1
fi

if [[ -z "${MESHCALE_FDB_CLUSTER_FILE:-}" && -z "${FDB_CLUSTER_FILE:-}" && -z "${FOUNDATIONDB_CLUSTER_FILE:-}" ]]; then
  echo "MeshScale Linux node requires MESHCALE_FDB_CLUSTER_FILE (or FDB_CLUSTER_FILE / FOUNDATIONDB_CLUSTER_FILE)." >&2
  exit 1
fi

cd /workspace/MeshScale/meshscale-swift
swift build --build-path .build-linux >/tmp/meshscale-build.log 2>&1
BIN_PATH="$(swift build --build-path .build-linux --show-bin-path)"

"$BIN_PATH/MeshScaleControlPlane" >/tmp/meshscale-cp.log 2>&1 &
MESHCALE_WORKER_ID=worker-b1 \
MESHCALE_WORKER_TYPE=general \
MESHCALE_WORKER_REGION=lab-b \
MESHCALE_ATTACHED_CONTROL_PLANE_ID=cp-b \
"$BIN_PATH/MeshScaleWorker" >/tmp/meshscale-worker.log 2>&1 &

wait -n
