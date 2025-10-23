#!/usr/bin/env bash
set -euo pipefail

CRD_FILES=()
TMP_DIR=""

usage() {
  echo "Usage: $0 <chart-version>" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' is not available in PATH." >&2
    exit 1
  fi
}

download_chart_archive() {
  local url="$1"
  local destination="$2"

  echo "Fetching HiveMQ Platform Operator CRDs from ${url}..." >&2
  curl -fsSL "${url}" -o "${destination}"
}

extract_archive() {
  local archive_path="$1"
  local destination="$2"
  tar -xzf "${archive_path}" -C "${destination}"
}

discover_crds() {
  local upstream_crds_dir="$1"

  if [[ ! -d "${upstream_crds_dir}" ]]; then
    echo "Unable to locate CRDs in the upstream chart at ${upstream_crds_dir}." >&2
    exit 1
  fi

  shopt -s nullglob
  CRD_FILES=("${upstream_crds_dir}"/*.yaml "${upstream_crds_dir}"/*.yml)
  shopt -u nullglob

  if (( ${#CRD_FILES[@]} == 0 )); then
    echo "No CRD files (*.yaml|*.yml) found in ${upstream_crds_dir}." >&2
    exit 1
  fi
}

copy_crds() {
  local destination_dir="$1"

  mkdir -p "${destination_dir}"
  find "${destination_dir}" -type f -name '*.y*ml' -delete
  cp "${CRD_FILES[@]}" "${destination_dir}/"
}

update_chart_metadata() {
  local chart_yaml="$1"
  local version="$2"
  local tmp_dir="$3"

  if [[ ! -f "${chart_yaml}" ]]; then
    cat <<EOF > "${chart_yaml}"
apiVersion: v2
name: hivemq-platform-crds
description: HiveMQ Platform Operator CRDs packaged as a standalone chart.
type: application
version: ${version}
appVersion: ${version}
EOF
    return
  fi

  local updated_chart="${tmp_dir}/Chart.yaml"
  awk -v ver="${version}" '
    BEGIN { version_done = 0; app_version_done = 0 }
    /^version:[[:space:]]/ { print "version: " ver; version_done = 1; next }
    /^appVersion:[[:space:]]/ { print "appVersion: " ver; app_version_done = 1; next }
    { print }
    END {
      if (version_done == 0) print "version: " ver;
      if (app_version_done == 0) print "appVersion: " ver;
    }
  ' "${chart_yaml}" > "${updated_chart}"
  mv "${updated_chart}" "${chart_yaml}"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  require_cmd curl
  require_cmd tar

  local version="$1"
  local repo_url="https://github.com/hivemq/helm-charts"
  local tag="hivemq-platform-operator-${version}"
  local archive_url="${repo_url}/archive/refs/tags/${tag}.tar.gz"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local chart_dir="${script_dir}/hivemq-platform-crds"
  local crds_dir="${chart_dir}/templates/crds"

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT

  local archive_path="${TMP_DIR}/chart.tar.gz"
  download_chart_archive "${archive_url}" "${archive_path}"
  extract_archive "${archive_path}" "${TMP_DIR}"

  local upstream_crds_dir="${TMP_DIR}/helm-charts-${tag}/charts/hivemq-platform-operator/crds"
  discover_crds "${upstream_crds_dir}"
  copy_crds "${crds_dir}"
  update_chart_metadata "${chart_dir}/Chart.yaml" "${version}" "${TMP_DIR}"

  echo "Copied CRDs into ${crds_dir} and set chart version to ${version}." >&2
}

main "$@"
