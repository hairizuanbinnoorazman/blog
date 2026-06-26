+++
title = "Deploying Agent Sandbox with gVisor and Memory Snapshots on GKE Standard"
description = "A command-by-command guide to running the open-source Agent Sandbox controller on GKE Standard with a dedicated gVisor node pool and GKE Pod Snapshots."
tags = [
    "kubernetes",
    "gke",
    "agent-sandbox",
    "gvisor",
]
date = "2026-06-24"
categories = [
    "google-cloud",
    "devops",
]
+++

Agent Sandbox provides a Kubernetes API for stateful, singleton, Pod-backed workloads. GKE can add a stronger gVisor isolation boundary and Pod Snapshots that preserve process memory and root filesystem changes.

The combination is useful for agent runtimes that need to execute untrusted code, suspend an environment when it is idle, and later resume from its previous state. This post captures the complete GKE Standard deployment path.

## What this deploys

This guide creates a GKE Standard cluster with:

- The open-source Agent Sandbox controller and extension CRDs.
- A dedicated non-E2 node pool using GKE Sandbox (gVisor).
- Workload Identity Federation for GKE.
- GKE Pod Snapshots, including process memory and root filesystem changes.
- Cloud Storage for snapshot data.

The example uses a regional control plane with nodes restricted to one zone to limit test cost.
Choose a multi-zone node topology for production.

> [!IMPORTANT]
> Pod Snapshots require GKE `1.35.3-gke.1234000` or later. Snapshotted workloads
> cannot run on E2 machines, so this guide uses `n2-standard-2` for the gVisor pool.

> [!IMPORTANT]
> Google currently documents installing the open-source Agent Sandbox controller as a temporary
> requirement for snapshot suspend and resume. Do not also enable the managed GKE Agent Sandbox
> add-on in this cluster because both installations own overlapping controllers and CRDs.

## Prerequisites

Install and initialize:

- A current [Google Cloud CLI](https://cloud.google.com/sdk/docs/install).
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/).
- `curl` and `jq`.

The operator needs permission to create GKE clusters, enable APIs, create Cloud Storage buckets,
change IAM policies, and install cluster-scoped Kubernetes resources.

```bash
gcloud version
gcloud auth list
gcloud config get-value project
```

## 1. Configure variables

Bucket names are globally unique. Change `SNAPSHOTS_BUCKET_NAME` if needed.

```bash
export PROJECT_ID="$(gcloud config get-value project)"
export PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" \
  --format='value(projectNumber)')"

export CLUSTER_NAME="agent-sandbox-standard"
export GKE_LOCATION="us-central1"
export NODE_LOCATION="us-central1-a"
export CLUSTER_VERSION="1.35.3-gke.1234000"

export SYSTEM_MACHINE_TYPE="e2-standard-2"
export GVISOR_NODE_POOL="agent-sandbox-gvisor"
export GVISOR_MACHINE_TYPE="n2-standard-2"

export AGENT_SANDBOX_VERSION="v0.4.6"

export SNAPSHOT_NAMESPACE="agent-sandbox-snapshots"
export SNAPSHOT_KSA_NAME="agent-sandbox-snapshot"
export SNAPSHOTS_BUCKET_NAME="${PROJECT_ID}-agent-sandbox-snapshots"
export SNAPSHOT_FOLDER="sandboxes"
```

As of June 21, 2026, `v0.4.6` is the latest Agent Sandbox release. Check before deploying:

```bash
curl --fail --silent --show-error \
  https://api.github.com/repos/kubernetes-sigs/agent-sandbox/releases/latest \
  | jq -r '.tag_name'
```

Confirm that the selected GKE version is offered in the target region:

```bash
gcloud container get-server-config \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}" \
  --format='value(validMasterVersions)'
```

If the exact version is unavailable, select an offered version newer than
`1.35.3-gke.1234000`.

## 2. Enable APIs

```bash
gcloud services enable \
  container.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project="${PROJECT_ID}"
```

## 3. Create the Standard cluster

The default E2 node is for system workloads and the controller. Sandbox workloads will be
scheduled onto the non-E2 gVisor pool created in the next step.

```bash
gcloud container clusters create "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}" \
  --node-locations="${NODE_LOCATION}" \
  --cluster-version="${CLUSTER_VERSION}" \
  --enable-pod-snapshots \
  --enable-ip-alias \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --workload-metadata=GKE_METADATA \
  --machine-type="${SYSTEM_MACHINE_TYPE}" \
  --num-nodes=1
```

## 4. Create the gVisor node pool

```bash
gcloud container node-pools create "${GVISOR_NODE_POOL}" \
  --project="${PROJECT_ID}" \
  --cluster="${CLUSTER_NAME}" \
  --location="${GKE_LOCATION}" \
  --node-locations="${NODE_LOCATION}" \
  --node-version="${CLUSTER_VERSION}" \
  --machine-type="${GVISOR_MACHINE_TYPE}" \
  --image-type=cos_containerd \
  --sandbox=type=gvisor \
  --workload-metadata=GKE_METADATA \
  --num-nodes=1
```

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}"
```

Verify the required features:

```bash
gcloud container clusters describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}" \
  --format='yaml(currentMasterVersion,workloadIdentityConfig,podSnapshotConfig)'

kubectl get nodes -L cloud.google.com/gke-nodepool,sandbox.gke.io/runtime
kubectl get runtimeclass gvisor
kubectl api-resources | grep -i podsnapshot
```

## 5. Install Agent Sandbox

Install the core and extension components from the same release:

```bash
kubectl apply \
  -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${AGENT_SANDBOX_VERSION}/manifest.yaml" \
  -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${AGENT_SANDBOX_VERSION}/extensions.yaml"
```

```bash
kubectl rollout status deployment/agent-sandbox-controller \
  --namespace=agent-sandbox-system \
  --timeout=5m

kubectl get pods --namespace=agent-sandbox-system
kubectl get crd \
  sandboxes.agents.x-k8s.io \
  sandboxtemplates.extensions.agents.x-k8s.io \
  sandboxwarmpools.extensions.agents.x-k8s.io \
  sandboxclaims.extensions.agents.x-k8s.io
```

## 6. Create snapshot storage

The bucket must use uniform bucket-level access and hierarchical namespaces, have soft delete
disabled, and be in the same region as the cluster.

```bash
gcloud storage buckets create "gs://${SNAPSHOTS_BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}" \
  --uniform-bucket-level-access \
  --enable-hierarchical-namespace \
  --soft-delete-duration=0d

gcloud storage managed-folders create \
  "gs://${SNAPSHOTS_BUCKET_NAME}/${SNAPSHOT_FOLDER}/"
```

## 7. Configure identity and IAM

```bash
kubectl create namespace "${SNAPSHOT_NAMESPACE}"
kubectl create serviceaccount "${SNAPSHOT_KSA_NAME}" \
  --namespace="${SNAPSHOT_NAMESPACE}"

export SNAPSHOT_KSA_PRINCIPAL="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/${SNAPSHOT_NAMESPACE}/sa/${SNAPSHOT_KSA_NAME}"
```

Grant the sandbox identity access to the bucket:

```bash
gcloud storage buckets add-iam-policy-binding \
  "gs://${SNAPSHOTS_BUCKET_NAME}" \
  --member="${SNAPSHOT_KSA_PRINCIPAL}" \
  --role="roles/storage.bucketViewer"

gcloud storage buckets add-iam-policy-binding \
  "gs://${SNAPSHOTS_BUCKET_NAME}" \
  --member="${SNAPSHOT_KSA_PRINCIPAL}" \
  --role="roles/storage.objectUser"
```

Grant the GKE service agent permission to manage snapshot objects:

```bash
gcloud storage buckets add-iam-policy-binding \
  "gs://${SNAPSHOTS_BUCKET_NAME}" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@container-engine-robot.iam.gserviceaccount.com" \
  --role="roles/storage.objectUser"
```

IAM changes can take several minutes to propagate.

## 8. Configure Pod Snapshots

Create the cluster-scoped storage configuration:

```bash
kubectl apply -f - <<EOF
apiVersion: podsnapshot.gke.io/v1
kind: PodSnapshotStorageConfig
metadata:
  name: agent-sandbox-gcs
spec:
  snapshotStorageConfig:
    gcs:
      bucket: "${SNAPSHOTS_BUCKET_NAME}"
      path: "${SNAPSHOT_FOLDER}"
      tokenSource: podKSA
EOF
```

Create the namespaced manual snapshot policy:

```bash
kubectl apply -f - <<EOF
apiVersion: podsnapshot.gke.io/v1
kind: PodSnapshotPolicy
metadata:
  name: agent-sandbox-manual
  namespace: "${SNAPSHOT_NAMESPACE}"
spec:
  storageConfigName: agent-sandbox-gcs
  selector:
    matchLabels:
      app: agent-sandbox-snapshot-workload
  triggerConfig:
    type: manual
    postCheckpoint: resume
  retentionConfig:
    lastAccessTimeout: 7d
  snapshotGroupingRules:
    groupByLabelValue:
      labels:
      - agents.x-k8s.io/sandbox-name-hash
      groupRetentionPolicy:
        maxSnapshotCountPerGroup: 3
EOF
```

```bash
kubectl wait --for=condition=Ready \
  podsnapshotstorageconfig/agent-sandbox-gcs \
  --timeout=5m

kubectl wait --for=condition=Ready \
  podsnapshotpolicy/agent-sandbox-manual \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --timeout=5m
```

## 9. Deploy a snapshot-capable sandbox

```bash
kubectl apply -f - <<EOF
apiVersion: extensions.agents.x-k8s.io/v1beta1
kind: SandboxTemplate
metadata:
  name: snapshot-python
  namespace: "${SNAPSHOT_NAMESPACE}"
spec:
  podTemplate:
    metadata:
      labels:
        app: agent-sandbox-snapshot-workload
    spec:
      serviceAccountName: "${SNAPSHOT_KSA_NAME}"
      automountServiceAccountToken: false
      runtimeClassName: gvisor
      nodeSelector:
        sandbox.gke.io/runtime: gvisor
      tolerations:
      - key: sandbox.gke.io/runtime
        operator: Equal
        value: gvisor
        effect: NoSchedule
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
      containers:
      - name: counter
        image: python:3.10-slim
        command: [python3, -c]
        args:
        - |
          import time
          count = 0
          while True:
              print(f"Count: {count}", flush=True)
              count += 1
              time.sleep(1)
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: "1"
            memory: 512Mi
      restartPolicy: OnFailure
---
apiVersion: extensions.agents.x-k8s.io/v1beta1
kind: SandboxWarmPool
metadata:
  name: snapshot-python
  namespace: "${SNAPSHOT_NAMESPACE}"
spec:
  replicas: 1
  sandboxTemplateRef:
    name: snapshot-python
EOF
```

```bash
kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 \
  sandboxwarmpool/snapshot-python \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --timeout=10m
```

Claim a sandbox:

```bash
kubectl apply -f - <<EOF
apiVersion: extensions.agents.x-k8s.io/v1beta1
kind: SandboxClaim
metadata:
  name: snapshot-demo
  namespace: "${SNAPSHOT_NAMESPACE}"
spec:
  warmPoolRef:
    name: snapshot-python
  lifecycle:
    shutdownPolicy: Delete
EOF

kubectl wait --for=condition=Ready \
  sandboxclaim/snapshot-demo \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --timeout=10m

export SANDBOX_NAME="$(kubectl get sandboxclaim snapshot-demo \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  -o jsonpath='{.status.sandbox.name}')"

kubectl wait --for=condition=Ready \
  "sandbox/${SANDBOX_NAME}" \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --timeout=10m

export SANDBOX_SELECTOR="$(kubectl get sandbox "${SANDBOX_NAME}" \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  -o jsonpath='{.status.selector}')"

export POD_NAME="$(kubectl get pods \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --selector="${SANDBOX_SELECTOR}" \
  -o jsonpath='{.items[0].metadata.name}')"
```

Verify scheduling and gVisor:

```bash
kubectl get sandboxclaim,sandbox,pod \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  -o wide

kubectl get pod "${POD_NAME}" \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  -o jsonpath='{.spec.runtimeClassName}{"\n"}'

kubectl logs "pod/${POD_NAME}" \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --tail=10
```

## 10. Create a memory snapshot

```bash
kubectl apply -f - <<EOF
apiVersion: podsnapshot.gke.io/v1
kind: PodSnapshotManualTrigger
metadata:
  name: snapshot-demo-1
  namespace: "${SNAPSHOT_NAMESPACE}"
spec:
  targetPod: "${POD_NAME}"
EOF
```

```bash
kubectl wait --for=condition=Triggered \
  podsnapshotmanualtrigger/snapshot-demo-1 \
  --namespace="${SNAPSHOT_NAMESPACE}" \
  --timeout=10m

kubectl describe podsnapshotmanualtrigger/snapshot-demo-1 \
  --namespace="${SNAPSHOT_NAMESPACE}"

kubectl get podsnapshots --namespace="${SNAPSHOT_NAMESPACE}"
gcloud storage ls "gs://${SNAPSHOTS_BUCKET_NAME}/${SNAPSHOT_FOLDER}/**"
```

A completed trigger confirms that GKE captured and uploaded the Pod's process memory and root
filesystem state.

For application-controlled suspend, resume, and restore, use
`k8s_agent_sandbox.gke_extensions.snapshots.PodSnapshotSandboxClient`. That client also requires
the Sandbox Router.

## Optional connectivity

Gateway API is not required by the controller or snapshot feature. For sandbox HTTP endpoints:

- Use the Sandbox Router with port forwarding for development.
- Use an internal endpoint for in-cluster clients.
- Enable GKE Gateway API and authentication before exposing production traffic.

Do not expose an unauthenticated router to the public internet.

## Cleanup

```bash
kubectl delete sandboxclaim --all --namespace="${SNAPSHOT_NAMESPACE}"
kubectl delete sandboxwarmpool,sandboxtemplate --all \
  --namespace="${SNAPSHOT_NAMESPACE}"
kubectl delete podsnapshotmanualtrigger,podsnapshotpolicy --all \
  --namespace="${SNAPSHOT_NAMESPACE}"
kubectl delete podsnapshotstorageconfig agent-sandbox-gcs
kubectl delete namespace "${SNAPSHOT_NAMESPACE}"

gcloud container clusters delete "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${GKE_LOCATION}" \
  --quiet
```

Delete the snapshot data only if it is no longer needed:

```bash
gcloud storage rm --recursive "gs://${SNAPSHOTS_BUCKET_NAME}/**"
gcloud storage buckets delete "gs://${SNAPSHOTS_BUCKET_NAME}"
```

## Command validation

The `gcloud` command forms in this guide were checked without creating resources against Google
Cloud SDK `573.0.0`. Each command shape was passed to `gcloud` with `--help`, exercising local
argument parsing and confirming that its flags are recognized.

Validated flags include:

- `gcloud container clusters create --enable-pod-snapshots`
- `--workload-pool` and `--workload-metadata=GKE_METADATA`
- `gcloud container node-pools create --sandbox=type=gvisor`
- `gcloud storage buckets create --enable-hierarchical-namespace`
- `gcloud storage managed-folders create`
- Workload Identity Federation principals in Cloud Storage IAM bindings

No Google Cloud resource was created during validation. Local parsing cannot verify permissions,
quota, regional version or machine availability, organization policies, or bucket-name
availability.

## References

- [GKE Pod Snapshots](https://cloud.google.com/kubernetes-engine/docs/how-to/pod-snapshots)
- [Agent Sandbox Pod Snapshots](https://cloud.google.com/kubernetes-engine/docs/how-to/agent-sandbox-pod-snapshots)
- [Enable Agent Sandbox on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/how-install-agent-sandbox)
- [GKE Sandbox and gVisor](https://cloud.google.com/kubernetes-engine/docs/how-to/sandbox-pods)
- [Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Cloud Storage hierarchical namespace](https://cloud.google.com/storage/docs/hns-overview)
- [Agent Sandbox releases](https://github.com/kubernetes-sigs/agent-sandbox/releases)
- [Agent Sandbox installation](https://github.com/kubernetes-sigs/agent-sandbox#installation)
- [Agent Sandbox snapshot client](https://github.com/kubernetes-sigs/agent-sandbox/tree/main/clients/python/agentic-sandbox-client/k8s_agent_sandbox/gke_extensions/snapshots)
