# HiveMQ Platform CRDs Chart

This repository packages the HiveMQ Platform Operator CustomResourceDefinitions (CRDs) as a standalone Helm chart. The CRDs are synchronized from the upstream [`hivemq/helm-charts`](https://github.com/hivemq/helm-charts) project.

## Contents

- `hivemq-platform-crds/`: Helm chart containing the CRDs.
- `sync-crds.sh`: Helper script that downloads a tagged HiveMQ Platform Operator chart, copies its CRDs into this chart, and updates `Chart.yaml`.

## Prerequisites

- Bash, `curl`, and `tar`
- Internet access to reach GitHub releases

## Syncing CRDs

```bash
./sync-crds.sh 0.2.18
```

Replace `0.2.18` with the desired HiveMQ Platform Operator chart version (matching the upstream `hivemq-platform-operator-<version>` git tag).

The script will:

1. Download the upstream chart archive for the requested version.
2. Copy all CRD files into `hivemq-platform-crds/crds/`.
3. Update `hivemq-platform-crds/Chart.yaml` to match the chosen version.
