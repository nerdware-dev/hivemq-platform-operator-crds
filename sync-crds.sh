#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <chart-version>" >&2
  exit 1
fi

VERSION="$1"
REPO_URL="https://github.com/hivemq/helm-charts"
TAG="hivemq-platform-operator-${VERSION}"
ARCHIVE_URL="${REPO_URL}/archive/refs/tags/${TAG}.tar.gz"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/hivemq-platform-crds"
CRDS_DIR="${CHART_DIR}/crds"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Fetching HiveMQ Platform Operator CRDs for version ${VERSION}..." >&2
curl -fsSL "${ARCHIVE_URL}" -o "${TMP_DIR}/chart.tar.gz"

tar -xzf "${TMP_DIR}/chart.tar.gz" -C "${TMP_DIR}"

UPSTREAM_CRDS_DIR="${TMP_DIR}/helm-charts-${TAG}/charts/hivemq-platform-operator/crds"
if [[ ! -d "${UPSTREAM_CRDS_DIR}" ]]; then
  echo "Unable to locate CRDs in the upstream chart at ${UPSTREAM_CRDS_DIR}." >&2
  exit 1
fi

mkdir -p "${CRDS_DIR}"

find "${CRDS_DIR}" -type f -name '*.y*ml' -delete

CRD_FILES=()
while IFS= read -r -d '' file; do
  CRD_FILES+=("$file")
done < <(find "${UPSTREAM_CRDS_DIR}" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

if [[ ${#CRD_FILES[@]} -eq 0 ]]; then
  echo "No CRD files (*.yaml|*.yml) found in ${UPSTREAM_CRDS_DIR}." >&2
  exit 1
fi

cp "${CRD_FILES[@]}" "${CRDS_DIR}/"

if [[ ! -f "${CHART_DIR}/Chart.yaml" ]]; then
  cat <<EOF > "${CHART_DIR}/Chart.yaml"
apiVersion: v2
name: hivemq-platform-crds
description: HiveMQ Platform Operator CRDs packaged as a standalone chart.
type: application
version: ${VERSION}
appVersion: ${VERSION}
EOF
else
  UPDATED_CHART="${TMP_DIR}/Chart.yaml"
  awk -v ver="${VERSION}" '
    BEGIN { version_done = 0; app_version_done = 0 }
    /^version:[[:space:]]/ { print "version: " ver; version_done = 1; next }
    /^appVersion:[[:space:]]/ { print "appVersion: " ver; app_version_done = 1; next }
    { print }
    END {
      if (version_done == 0) print "version: " ver;
      if (app_version_done == 0) print "appVersion: " ver;
    }
  ' "${CHART_DIR}/Chart.yaml" > "${UPDATED_CHART}"
  mv "${UPDATED_CHART}" "${CHART_DIR}/Chart.yaml"
fi

echo "Copied CRDs into ${CRDS_DIR} and set chart version to ${VERSION}." >&2
