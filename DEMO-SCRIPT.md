# Demo Script — NAP + AGC on AKS (≤ 8 min)

**Tagline:** *"The Three Workload Problems — Solved Live."*

Three acts, one for each customer pain. Each ends with a **PAUSE** moment for the camera to land on the proof.

| Act | Pain | Proof moment | Time |
| --- | --- | --- | --- |
| 1 | "I don't know what node sizes to pick" | Karpenter logs `Launched Standard_D8ls_v5` — you never typed it | 0:00 – 2:30 |
| 2 | "My workloads get stuck when nodes don't match" | Mem-heavy pods evicted/rescheduled on a brand-new `E16s_v5` | 2:30 – 5:00 |
| 3 | "I'm wasting money on over-provisioned nodes" | Karpenter `Deleted NodeClaim` — VM terminated automatically | 5:00 – 7:15 |
| Outro | The bigger story | Architecture recap + AGC silently routing throughout | 7:15 – 7:30 |

---

## 0. Pre-Demo Setup (do BEFORE recording)

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

# Sanity checks
kubectl get pods -n azure-alb-system
az aks show -n $CLUSTER -g $RG --query "nodeProvisioningProfile.mode" -o tsv  # → Auto
```

Have files ready: `nodepool.yaml`, `gateway.yaml`, `nginx-service.yaml`, `deployment-small.yaml`, `deployment-large.yaml` (see `manifests/` folder).

### Terminal layout

| Pane | Command (start before recording) |
| --- | --- |
| **Left (main)** | your `kubectl apply` / `scale` commands |
| **Right-top** | `kubectl get events -A --field-selector source=karpenter -w` |
| **Right-bottom** | `kubectl get pods -o wide -w` |

The right panes are your *proof*. Every left-pane action lights them up live.

---

## ACT 1 — "I don't know what node sizes to pick"  (0:00 – 2:30)

### Step 1 · Set the stage  (0:00 – 0:30)

> "Most teams start here — workloads to run, no idea what VM size to pick. Pick small → workloads fail. Pick big → you overpay. With NAP, you stop guessing."

```bash
kubectl get nodes        # → 1 system node only
kubectl get nodepool     # → No resources found (yet)
```

Point at the right-top pane: *"Karpenter event log. Quiet — nothing pending."*

### Step 2 · Apply NodePool  (0:30 – 1:00)

> "I'm not picking a VM size. I'm telling Karpenter a *family* — D-series — and letting it choose."

```bash
cat nodepool.yaml      # highlight: sku-family=D, consolidationPolicy=WhenUnderutilized
kubectl apply -f nodepool.yaml
kubectl get nodepool   # → READY=True, NODES=0
```

> "Zero nodes. NAP only acts when there's demand."

### Step 3 · Wire AGC  (1:00 – 1:15)

> "Same idea on the ingress side — Application Gateway for Containers. One Gateway, one HTTPRoute."

```bash
kubectl apply -f nginx-service.yaml
kubectl apply -f gateway.yaml
kubectl get gateway    # ADDRESS pending → will resolve
```

### Step 4 · Deploy small workload  (1:15 – 1:45)

> "Pod needs 2 CPU and 361Mi memory. I have no idea what Azure SKU fits. Doesn't matter."

```bash
kubectl apply -f deployment-small.yaml
```

**Right-bottom:** pods go `Pending`.
**Right-top:** Karpenter fires:

```
NominatePod        pod/nginx-xxx  → NodeClaim/default-xxxxx
NodeClaimCreated   nodeclaim/...
Launched           nodeclaim/...  Launched instance: Standard_D8ls_v5
```

### ⏸ PAUSE #1 — The Reveal  (1:45 – 2:00)

Stop. Point at `Launched Standard_D8ls_v5`.

> **"I never typed `D8ls_v5`. Karpenter read my pod spec — 2 CPU, 361Mi — and picked the most cost-efficient D-series VM that fits. Problem 1: solved."**

### Step 5 · Confirm  (2:00 – 2:30)

```bash
kubectl get nodes
kubectl get nodes --show-labels | grep karpenter.azure.com/sku-name
kubectl get pods                # both Running
kubectl get gateway             # AGC ADDRESS now populated
curl http://<AGC-IP>/           # nginx welcome page
```

> "Two pods running. AGC routing live. The VM? NAP picked it."

---

## ACT 2 — "My workloads get stuck when nodes don't match"  (2:30 – 5:00)

### Step 6 · Introduce new demand  (2:30 – 2:50)

> "Workload requirements change — say a memory-heavy feature ships. New pods need 10Gi each, 3 replicas. Current node can't take it."

```bash
kubectl describe node <node-name> | grep -A5 "Allocatable:"   # ~15Gi available
```

> "We need 30Gi. Watch what happens."

### Step 7 · Apply the heavy deployment  (2:50 – 3:10)

```bash
kubectl apply -f deployment-large.yaml
```

**Right-bottom:** new pods `Pending`.
**Right-top:** Karpenter nominates pods to a new NodeClaim.

### Step 8 · Watch the rescheduling live  (3:10 – 4:00)

Watch for:

```
Launched     nodeclaim/...   Launched instance: Standard_E16s_v5
Initialized  node/aks-default-yyy
NodeClaimReady ...
```

⚡ When `E16s_v5` appears:

> **"`E16s_v5` — memory-optimized. Completely different family from before. Karpenter saw the 10Gi request and picked the right machine type automatically."**

Right-bottom: pods transition `Pending → ContainerCreating → Running`.

### Step 9 · Inspect mix-and-match placement  (4:00 – 4:20)

```bash
kubectl get pods -o wide                            # mix of nodes!
kubectl get pod <pod> -o yaml | grep -A3 resources  # 10Gi confirmed
kubectl get nodes --show-labels | grep sku-name     # D8ls_v5 + E16s_v5 side by side
```

### ⏸ PAUSE #2 — The Reveal  (4:20 – 4:40)

> **"Two workloads. Two machine types. Right machine for each — automatically. Pods never got stuck. Problem 2: solved."**

### Step 10 · AGC stayed silent  (4:40 – 5:00)

```bash
curl http://<AGC-IP>/      # still works — no routing change
```

> "AGC's probes detected the new pods and added them to rotation. The networking layer adapted just like the compute layer did."

---

## ACT 3 — "I'm wasting money on over-provisioned nodes"  (5:00 – 7:15)

### Step 11 · Show the waste  (5:00 – 5:20)

```bash
kubectl get nodes                       # 2 workload nodes (D + E)
kubectl describe node <e-node> | grep -A8 "Allocated resources:"  # under-utilized
```

> "In a traditional setup these nodes sit idle, on the bill. Watch consolidation."

### Step 12 · Scale down → consolidation  (5:20 – 6:00)

```bash
kubectl apply -f deployment-small.yaml      # back to light workload
```

**Right-bottom:** heavy pods `Terminating`, small pods `Pending → Running`.
**Right-top:**

```
Disrupting          nodeclaim/...   via consolidation: replace
WaitingForDeletion  node/...
Terminating         nodeclaim/...
Deleted             node/...
```

### ⏸ PAUSE #3 — The Reveal  (6:00 – 6:20)

> **"That E16s_v5 just got terminated — automatically. ~$0.50/hr machine that in a traditional setup would have run all night. Problem 3: solved."**

### Step 13 · Final state  (6:20 – 6:45)

```bash
kubectl get nodes                                       # back to 1 workload node
kubectl get nodes --show-labels | grep sku-name         # right-sized D
kubectl get pods -o wide                                # bin-packed efficiently
```

### Step 14 · Cost narrative  (6:45 – 7:15)

> "Traditional: 3 node pools, paid 24×7. With NAP: one NodePool definition, capacity appears with demand and disappears without it. AGC handles ingress autoscale on its own — no fixed L7 tier either. **Two layers of efficiency. One platform.**"

---

## OUTRO  (7:15 – 7:30)

```bash
kubectl get nodes && kubectl get pods && kubectl get gateway && curl http://<AGC-IP>/
```

> "NAP for compute. AGC for traffic. Together — no node pool planning, no stuck workloads, no idle capacity. Your cluster becomes a **self-managing platform**."

Flash the links:

- [aka.ms/aks/nap](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [aka.ms/agc](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)

---

## Karpenter Log Cheat-Sheet (highlight these on screen)

| Log line | Meaning | When |
| --- | --- | --- |
| `NominatePod` | Karpenter claimed a pending pod | immediately |
| `NodeClaimCreated` | Decision made, spinning up VM | ~5s later |
| `Launched instance: Standard_<SKU>` | **The reveal** — VM type chosen | ~30s |
| `Initialized` | Node ready for pods | ~60–90s |
| `Disrupting via consolidation: replace` | Underutilized node being removed | after scale-down |
| `Deleted NodeClaim` | VM terminated, $$$ saved | consolidation done |

## Reset Between Takes

```bash
kubectl scale deployment nginx-deployment --replicas=0
kubectl delete -f deployment-large.yaml --ignore-not-found
kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' | tail
```
