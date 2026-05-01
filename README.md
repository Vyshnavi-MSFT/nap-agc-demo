# NAP + AGC on AKS — Self-Managing Platform Demo

> Build an AKS cluster that **picks its own VM SKUs** (Node Auto-Provisioning) and **routes by load** (Application Gateway for Containers) — with no node-pool planning and no hand-rolled ingress.

![Architecture](docs/architecture.png)

---

## 🎯 Demo Objective

Show how two AKS features eliminate the two hardest jobs in Kubernetes infrastructure:

1. **NAP (Node Auto-Provisioning)** — reads pending pods, picks the right Azure VM SKU, provisions it, and consolidates idle nodes when demand drops.
2. **AGC (Application Gateway for Containers)** — Azure-managed L7 ingress that auto-discovers pod endpoints and **routes traffic load-aware**: the least-loaded healthy pod gets the most new requests.

**Together** they turn an AKS cluster into a platform that responds to workload intent instead of forcing you to pre-plan infrastructure — and the cost story is real: capacity tracks demand, idle nodes disappear automatically.

The demo runs in **≤ 8 minutes** across three acts (see [DEMO-SCRIPT.md](./DEMO-SCRIPT.md)):

| Act | Customer pain | Live proof |
|---|---|---|
| 1 | "I don't know what node sizes to pick" | Karpenter picks `Standard_D8ls_v5` automatically |
| 2 | "Workloads get stuck when nodes don't match" | Memory pods land on a brand-new `Standard_E16s_v5` |
| 3 | "I'm wasting money on over-provisioned nodes" | Karpenter terminates the idle node automatically |

---

## 🏗️ Architecture

- **AGC lives outside the cluster** in your Azure subscription. The in-cluster ALB Controller programs it via Azure ARM.
- **AGC routes load-aware**: it tracks pod health + load and steers new connections to the least-loaded healthy pod (cool > warm > hot).
- **NAP runs inside the cluster** as Karpenter + the AKS provider. When a pod can't be scheduled, NAP reads its CPU/memory/arch/spot-tolerance and picks the cheapest matching Azure SKU.
- **Cilium dataplane** (eBPF) handles pod networking. Required by NAP.

See [`docs/architecture.png`](docs/architecture.png) for the full diagram.

---

## ✅ Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription | Owner or Contributor on the resource group |
| Azure CLI ≥ `2.65` | `az version` |
| `kubectl` | `az aks install-cli` if missing |
| `aks-preview` extension | `az extension add --name aks-preview --upgrade` |
| Region with NAP availability | `eastus2`, `westus3`, `westeurope` (others may work) |

**Provider features:**

```bash
az feature register --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview
az provider register --namespace Microsoft.ContainerService
```

**NAP constraints to know up front:**

- Requires **Azure CNI Overlay + Cilium** dataplane
- Cannot coexist with the cluster autoscaler
- No Windows node pools, no IPv6, no custom kubelet config
- Managed identity only (no SPNs)

---

## 📁 Repo Layout

```
nap-agc-demo/
├── README.md              ← you are here
├── BLOG.md                ← long-form write-up for LT / FinOps audience
├── DEMO-SCRIPT.md         ← 8-minute live demo script (3 acts, paced)
├── docs/
│   └── architecture.png   ← AGC outside cluster · load-aware routing · NAP sizing
└── manifests/
    ├── nodepool.yaml          ← NAP NodePool (D-family, on-demand + spot)
    ├── gateway.yaml           ← Gateway API Gateway + HTTPRoute (AGC)
    ├── nginx-service.yaml     ← Service that AGC fronts
    ├── deployment-small.yaml  ← Light workload (Act 1)
    └── deployment-large.yaml  ← Memory-heavy workload (Act 2)
```

---

## 🚀 Demo Steps

> Full pacing, narration, and "pause-the-camera" reveals are in [DEMO-SCRIPT.md](./DEMO-SCRIPT.md). The steps below are the executable bones.

### 0. One-time setup (do BEFORE recording)

```bash
export RG="nap-agc-demo-rg"
export CLUSTER="nap-agc-demo"
export LOCATION="eastus2"

az group create -n $RG -l $LOCATION

az aks create -n $CLUSTER -g $RG -l $LOCATION \
  --network-plugin azure --network-plugin-mode overlay \
  --network-dataplane cilium \
  --node-provisioning-mode Auto \
  --node-count 1 --generate-ssh-keys

az aks get-credentials -n $CLUSTER -g $RG

# AGC ingress (ALB Controller add-on)
az aks addon enable -n $CLUSTER -g $RG --addon alb-controller

# Sanity
kubectl get pods -n azure-alb-system
az aks show -n $CLUSTER -g $RG --query "nodeProvisioningProfile.mode" -o tsv   # → Auto
```

**Recommended terminal layout** (gives you live "proof" panes):

| Pane | Command |
|---|---|
| Left (main) | your `kubectl apply` / `scale` commands |
| Right-top  | `kubectl get events -A --field-selector source=karpenter -w` |
| Right-bottom | `kubectl get pods -o wide -w` |

### Step 1 — Apply the NodePool (the only NAP config)

```bash
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool                # READY=True, NODES=0
```

**What it does:** declares a `NodePool` CRD (D-family, amd64, on-demand) and an `AKSNodeClass`. Karpenter now watches for pending pods that match.

### Step 2 — Wire AGC ingress

```bash
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml
kubectl get gateway                  # ADDRESS will populate after Step 3
```

**What it does:** creates a Service for the workload, then a Gateway + HTTPRoute. The ALB Controller sees these and provisions the AGC frontend (public IP, TLS) in your Azure subscription.

### Step 3 — Deploy a light workload (Act 1 trigger)

```bash
kubectl apply -f manifests/deployment-small.yaml
```

**What it does:** Deployment requests 2 CPU + 361Mi per pod. No node fits → pods go `Pending` → Karpenter fires.

**Watch (right-top pane):**
```
NominatePod        pod/nginx-xxx  → NodeClaim/default-xxxxx
NodeClaimCreated   nodeclaim/...
Launched           nodeclaim/...  Launched instance: Standard_D8ls_v5
```

### Step 4 — Add a memory-heavy workload (Act 2 trigger)

```bash
kubectl apply -f manifests/deployment-large.yaml
```

**What it does:** 3 replicas × 10Gi each. Existing D-family node can't fit → Karpenter picks an **E-family memory-optimized** SKU.

**Watch:**
```
Launched     nodeclaim/...   Launched instance: Standard_E16s_v5
```

### Step 5 — Scale down → consolidation (Act 3 reveal)

```bash
kubectl apply -f manifests/deployment-small.yaml    # back to light load
```

**What it does:** large pods terminate, the E-node becomes underutilized, Karpenter consolidates it.

**Watch:**
```
Disrupting          nodeclaim/...   via consolidation: replace
Terminating         nodeclaim/...
Deleted             node/...
```

### Step 6 — Hit the AGC endpoint throughout

```bash
kubectl get gateway -o jsonpath='{.items[0].status.addresses[0].value}'
curl http://<AGC-IP>/
```

AGC's address never changes; routing adapts as pods come and go.

---

## 🔍 Validation

After each step, confirm the system reached the expected state:

| After step | Command | Expect |
|---|---|---|
| 1 | `kubectl get nodepool` | `READY=True`, `NODES=0` |
| 2 | `kubectl get gateway` | Gateway `Programmed=True`; ADDRESS pending until pods exist |
| 3 | `kubectl get nodes --show-labels \| grep sku-name` | a `Standard_D*s_v5` node appears |
| 3 | `kubectl get pods -o wide` | small pods `Running` on the new D-node |
| 4 | `kubectl get nodes --show-labels \| grep sku-name` | a second node, `Standard_E*s_v5` |
| 4 | `kubectl get pods -o wide` | large pods `Running` on the E-node, smalls on D-node |
| 5 | `kubectl get nodes` | E-node disappears within ~`consolidateAfter` |
| 5 | `kubectl get events -A --field-selector source=karpenter \| tail` | `Disrupting via consolidation` + `Deleted` |
| any | `curl http://<AGC-IP>/` | nginx welcome page; never 5xx during transitions |

**Karpenter log cheat-sheet:**

| Log line | Meaning |
|---|---|
| `NominatePod` | Karpenter claimed a pending pod |
| `NodeClaimCreated` | Decision made, spinning up VM |
| `Launched instance: Standard_<SKU>` | **The reveal** — VM type chosen |
| `Initialized` | Node ready for pods |
| `Disrupting via consolidation: replace` | Underutilized node being removed |
| `Deleted NodeClaim` | VM terminated, $$$ saved |

---

## 🛠️ Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `az aks create` fails on `--node-provisioning-mode` | Preview feature not registered | Run the `az feature register` command in [Prerequisites](#-prerequisites), then `az provider register --namespace Microsoft.ContainerService` |
| `az aks create` fails on `--network-dataplane cilium` | `aks-preview` extension stale | `az extension update --name aks-preview` |
| `kubectl get nodepool` returns `No resources found` | NodePool CRDs not installed | NAP wasn't enabled — verify `az aks show ... --query nodeProvisioningProfile.mode` returns `Auto` |
| Pods stuck `Pending`, no Karpenter event fires | Pod requirements outside NodePool's `requirements:` (arch, sku-family, capacity-type) | Edit `manifests/nodepool.yaml` to widen the `requirements` block |
| Karpenter event: `no instance type satisfied resources` | Pod request exceeds any VM in the allowed family | Add another `sku-family` (e.g. `E`, `F`) to the NodePool |
| Gateway `ADDRESS` stays empty | ALB Controller add-on disabled or pods not Ready | `kubectl get pods -n azure-alb-system`; re-run `az aks addon enable ... --addon alb-controller` |
| `curl <AGC-IP>` returns 502 | Backend pods not Ready or wrong port in Service | `kubectl get endpoints <service>`; check Service `port` matches container port |
| Consolidation never fires | `consolidationPolicy` not `WhenUnderutilized`, or `disruption.budgets` blocks it | Check `kubectl get nodepool default -o yaml`; lower `consolidateAfter` |
| Spot node terminated mid-demo | Azure spot eviction (expected behavior) | Re-apply the deployment; pods reschedule to on-demand |
| `kubectl` complains about CRDs missing (`karpenter.sh/v1`) | NAP enabled with older API version | `kubectl api-resources \| grep karpenter` to confirm version, update YAML `apiVersion` |

---

## 🧹 Cleanup

```bash
# 1. Remove workloads (lets NAP consolidate everything to zero)
kubectl delete -f manifests/deployment-large.yaml --ignore-not-found
kubectl delete -f manifests/deployment-small.yaml --ignore-not-found
kubectl delete -f manifests/gateway.yaml --ignore-not-found
kubectl delete -f manifests/nginx-service.yaml --ignore-not-found
kubectl delete -f manifests/nodepool.yaml --ignore-not-found

# 2. Tear down the cluster + AGC + everything
az group delete -n $RG --yes --no-wait
```

> The resource group delete is the safest, fastest cleanup — it removes the AKS cluster, the AGC frontend, the managed identity, the public IP, and any disks NAP provisioned.

---

## 📚 References (ms.learn)

- [Node Auto-Provisioning overview](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [Configure NAP NodePools](https://learn.microsoft.com/azure/aks/node-autoprovision#configure-nodepools)
- [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)
- [AGC quickstart with ALB Controller](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller)
- [Gateway API on AKS (HTTPRoute)](https://learn.microsoft.com/azure/application-gateway/for-containers/how-to-traffic-splitting-gateway-api)
- [Azure CNI Overlay with Cilium dataplane](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Karpenter (open source)](https://karpenter.sh)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io)

---

## 📖 Further reading

- [BLOG.md](./BLOG.md) — long-form write-up: the two walls, how each piece works, the cost story, 7 professional insights from building this demo.
- [DEMO-SCRIPT.md](./DEMO-SCRIPT.md) — minute-by-minute live demo script with narration, terminal layout, and pause moments.
