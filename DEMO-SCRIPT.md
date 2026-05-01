# Demo Script — AGC Load-Aware Routing + NAP Cost Savings

A live, scripted demo built around a realistic customer scenario. Total runtime: **~10 minutes** of speaking, plus ~10 minutes of cluster provisioning that you complete **before** recording.

---

## The Customer Scenario

> **Contoso Retail** runs `shop.contoso.com` on AKS.
> Tonight at 8pm, marketing is sending a flash-sale email to 2 million subscribers. The platform team expects traffic to spike 5x within minutes, then return to baseline a few hours later.
>
> Their three concerns:
>
> 1. **Sizing:** The recommendation engine they want to launch needs ~10 Gi of memory per pod. Today's node pool is CPU-optimized — they don't know what to put in a new node pool.
> 2. **Speed:** When the spike hits, new pods must be running in under a minute, **and** existing pods must not be hammered while the new ones come up.
> 3. **Cost:** After the sale, the extra capacity sits idle on the bill all night.
>
> We will solve all three live, on the cluster.

This is the story you tell. Every command below maps to one of these three concerns.

---

## Pre-Demo Setup (do BEFORE recording)

The cluster takes ~10 minutes to come up. Build it in advance so the recording is just the workload story.

```bash
source scripts/00-env.sh
az login
az account set --subscription "$SUBSCRIPTION_ID"

bash scripts/01-prereqs.sh        # ~3 min
bash scripts/02-create-aks.sh     # ~7 min
```

Confirm the cluster is healthy:

```bash
kubectl get nodes                                                          # 1 system node
kubectl get pods -n kube-system | grep alb-controller                      # ALB Controller pods Running
az aks show -n $CLUSTER -g $RG --query "nodeProvisioningProfile.mode" -o tsv  # → Auto
```

**Terminal layout (before pressing Record):**

| Pane | Command |
|---|---|
| Left (main) | this is where you type — large font |
| Right-top | `kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' -w` |
| Right-bottom | `kubectl get pods -o wide -w` |

The right-top pane is your **proof pane**. When the audience sees `Launched instance: Standard_D...` appear there, the demo lands.

---

## Act 1 — "We don't know what VM SKU to pick" (0:00 – 3:00)

### Open (0:00 – 0:30)

> *"This is Contoso Retail's AKS cluster. One system node, no workload nodes, no node-pool plan. Today they ship the new shop service and tonight they run a flash sale. Watch what happens when I just deploy the workload."*

```bash
kubectl get nodes
kubectl get nodepool
```

The output should be: 1 system node, no `NodePool` resources yet.

### Step 1 — Apply the NodePool (0:30 – 1:15)

> *"This is the only NAP configuration I will write. I am not picking a VM SKU. I am giving Karpenter a list of **families** it is allowed to choose from."*

```bash
cat manifests/nodepool.yaml
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool
```

Highlight three things in the YAML on screen:

- `karpenter.azure.com/sku-family In [D, E]` — only general-purpose or memory-optimized.
- `karpenter.sh/capacity-type In [on-demand, spot]` — Karpenter can pick spot when safe.
- `consolidationPolicy: WhenUnderutilized` — empty nodes get reclaimed.

> *"Zero nodes. NAP only acts when there is real demand."*

### Step 2 — Wire the AGC frontend (1:15 – 1:45)

> *"Same idea on ingress. I am not provisioning AGC in the portal. I am writing a Gateway and HTTPRoute and the ALB Controller programs the AGC frontend for me."*

```bash
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml
kubectl get gateway gateway-01
```

> *"Gateway is created. Address is pending — that resolves once pods exist."*

### Step 3 — Deploy the baseline shop workload (1:45 – 2:15)

> *"`shop-v1`. Two pods, 2 CPU each. Standard ecommerce baseline."*

```bash
kubectl apply -f manifests/deployment-small.yaml
```

**Right-bottom pane:** pods go `Pending`.
**Right-top pane:** Karpenter fires:

```
NominatePod        pod/shop-v1-xxx  → NodeClaim/default-xxxxx
NodeClaimCreated   nodeclaim/...
Launched           nodeclaim/...  Launched instance: Standard_D8ls_v5
```

### PAUSE #1 — The Reveal (2:15 – 2:45)

Stop typing. Point at `Launched Standard_D8ls_v5`.

> **"I never typed `D8ls_v5`. Karpenter read my pod spec — 2 CPU, 361 Mi — and picked the cheapest D-series VM that fits both pods. Concern #1: solved."**

### Step 4 — Confirm (2:45 – 3:00)

```bash
kubectl get nodes
kubectl get pods -o wide
kubectl get gateway gateway-01    # ADDRESS now populated
curl http://<AGC-IP>/             # nginx welcome page
```

---

## Act 2 — "The marketing email just dropped" (3:00 – 6:30)

### Set the scene (3:00 – 3:20)

> *"It is 8pm. Marketing just sent the email blast. Two things happen at once: the recommendation engine launches — that's the new memory-heavy service — and `shop-v1` traffic spikes 5x. Watch."*

### Step 5 — Apply the recommendation engine (3:20 – 3:50)

> *"`recommender`. Three pods. Each one wants 4 CPU and 10 Gi memory. Our D8ls node has ~15 Gi total. It does not fit."*

```bash
kubectl apply -f manifests/deployment-large.yaml
```

**Right-bottom pane:** new `recommender` pods go `Pending`.
**Right-top pane:** Karpenter nominates them to a **new** NodeClaim.

Watch for:

```
Launched     nodeclaim/...   Launched instance: Standard_E16s_v5
Initialized  node/aks-default-yyy
NodeClaimReady ...
```

When `E16s_v5` appears:

> **"`E16s_v5` — memory-optimized. Completely different family from before. Karpenter saw the 10 Gi request and picked the right machine type automatically. The platform team did not write a second node pool."**

### Step 6 — Scale the shop spike (3:50 – 4:30)

```bash
kubectl scale deployment shop-v1 --replicas=6
```

**Right-bottom pane:** four new `shop-v1` pods go `Pending → Running`.
**Right-top pane:** Karpenter places the new pods on the existing D-node where they fit, and on the E-node where they fit alongside the recommender.

```bash
kubectl get pods -o wide                # six lights + three heavies, mix of nodes
```

### PAUSE #2 — Two reveals at once (4:30 – 5:00)

> **"Two workloads. Two machine families. Right machine for each, automatically. That's NAP. But there is a second thing happening that you cannot see in `kubectl`."**

### Step 7 — Prove load-aware routing (5:00 – 6:00)

> *"AGC is not a round-robin load balancer. When new pods come up, the existing pods are already busy serving the spike. AGC tracks pod load and routes new connections to the **cool** pods first. Let me prove it."*

In a separate terminal (or pane):

```bash
bash scripts/06-load-test.sh
```

The script runs a load-generator pod inside the cluster that hits the AGC endpoint for 60 seconds, then prints the response distribution by `POD_IP`. The output should show the cool pods (the ones on the newly-provisioned node) receiving more requests than the already-busy pods.

> **"See the distribution? The pods on the new node are catching the spike. The original two pods, which were already serving traffic, get fewer new connections. Without load-aware routing, all six pods would split the spike evenly and the busy ones would saturate first. Concern #2: solved."**

### Step 8 — Sanity check the user experience (6:00 – 6:30)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://<AGC-IP>/
# repeat a few times
```

> *"Two hundreds throughout. The customer never saw a 5xx. AGC's probes added the new pods to rotation as soon as they passed health checks."*

---

## Act 3 — "After the sale, where does the cost go?" (6:30 – 9:00)

### Set the scene (6:30 – 6:50)

> *"It is 11pm. The sale is over. Recommendation traffic is gone. In a traditional setup, that E16s node sits on the bill all night. Watch what NAP does."*

### Step 9 — Scale down the heavy workload (6:50 – 7:20)

```bash
kubectl scale deployment recommender --replicas=0
kubectl scale deployment shop-v1 --replicas=2     # back to baseline
```

**Right-bottom pane:** recommender pods `Terminating`, extra shop pods `Terminating`.
**Right-top pane:**

```
Disrupting          nodeclaim/...   via consolidation: replace
WaitingForDeletion  node/...
Terminating         nodeclaim/...
Deleted             node/...
```

This may take 1–2 minutes depending on `consolidateAfter`.

### PAUSE #3 — The Reveal (7:20 – 7:45)

Point at `Deleted node`.

> **"That E16s_v5 just got terminated automatically. Roughly fifty cents per hour. In a traditional setup that machine would have run all night — call it $4 saved on a single node, on a single workload. Multiply by every workload, every team, every cluster. Concern #3: solved."**

### Step 10 — Confirm the steady state (7:45 – 8:15)

```bash
kubectl get nodes                       # back to one workload node (D-family)
kubectl get pods -o wide                # bin-packed efficiently on the D-node
curl http://<AGC-IP>/                   # AGC still works, no manual reconfig
```

### Closing (8:15 – 9:00)

> *"Let me recap what we did NOT do tonight:*
>
> *— We did not pre-create node pools for two workload shapes.*
> *— We did not provision an AGC frontend in the Azure Portal.*
> *— We did not write any autoscale logic.*
> *— We did not manually drain or terminate any node.*
>
> *What we did do:*
>
> *— We wrote one NodePool YAML and let Karpenter pick the VM SKUs.*
> *— We wrote one Gateway YAML and let the ALB Controller program AGC.*
> *— We deployed pods and watched the cluster respond to demand.*
>
> *NAP for compute. AGC for traffic. Together, your AKS cluster becomes a self-managing platform."*

Flash the references on screen:

- [aka.ms/aks/nap](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [aka.ms/agc](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)

---

## Karpenter Event Cheat-Sheet (highlight these on the proof pane)

| Event | Meaning | When |
|---|---|---|
| `NominatePod` | Karpenter claimed a pending pod | immediately |
| `NodeClaimCreated` | Decision made, spinning up VM | within ~5 s |
| `Launched instance: Standard_<SKU>` | **The reveal** — VM type chosen | within ~30 s |
| `Initialized` | Node is `Ready`, pods can bind | within ~60–90 s |
| `Disrupting via consolidation: replace` | Under-utilized node being removed | after scale-down |
| `Deleted NodeClaim` | VM terminated, billing stops | consolidation done |

---

## Reset Between Takes

```bash
kubectl scale deployment recommender --replicas=0 --ignore-not-found
kubectl scale deployment shop-v1 --replicas=2
# wait ~3 min for consolidation
kubectl get nodes                       # back to a single D-node
kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' | tail
```

To restart from a fully empty cluster without re-creating it:

```bash
kubectl delete -f manifests/deployment-large.yaml --ignore-not-found
kubectl delete -f manifests/deployment-small.yaml --ignore-not-found
# wait for consolidation, then redeploy from Step 3 above
```

---

## What to Cut if You Only Have 5 Minutes

If you are constrained to a 5-minute slot, drop Act 3 and end after Step 7 (load-aware routing reveal). The full story still lands:

- Act 1 proves NAP picks the right SKU.
- Act 2 proves NAP + AGC work together for the spike.
- The cost story can be a closing sentence rather than a live reveal.

If you only have **3 minutes**, run just Act 1: apply NodePool → apply baseline workload → point at `Launched instance`. That is enough to make the "self-managing platform" point.
