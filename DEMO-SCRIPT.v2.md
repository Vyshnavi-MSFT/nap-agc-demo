# Demo Script v2 — AGC Load-Aware Routing + NAP Cost Savings

> **What changed from v1** (read me first, then delete this block before recording):
>
> 1. **New 30-sec "diagram intro" beat** at the very top — establishes the mental model before any CLI runs. Uses `docs/architecture-nap-agc.png`.
> 2. **Baseline $/hour callout in Act 1** so the Act 3 cost-reveal has a denominator.
> 3. **"What would have happened without NAP" contrast beat in Act 2** — borrowed from the YouTube walkthrough; makes the SKU-family reveal land harder.
> 4. **Live `az network alb show` in Act 1 Step 2** — turns AGC from an abstraction into a tangible Azure resource on screen.
> 5. **Explicit pause counters** ("…1…2…3…") so reveals breathe instead of getting steamrolled.
> 6. **Tightened the YAML reads** — only 3 lines per file get spoken, the rest just shows.
> 7. **Reset block now includes the AGC frontend** (Gateway+HTTPRoute) — v1 only reset workloads.
>
> Total runtime unchanged: ~10 min speaking + ~10 min pre-record provisioning.

---

## The Customer Scenario  *(unchanged from v1)*

> **Contoso Retail** runs `shop.contoso.com` on AKS.
> Tonight at 8pm, marketing is sending a flash-sale email to 2 million subscribers. Traffic will spike 5x within minutes, then return to baseline a few hours later.
>
> Their three concerns:
>
> 1. **Sizing:** The recommendation engine they want to launch needs ~10 Gi of memory per pod. Today's node pool is CPU-optimized — they don't know what to put in a new node pool.
> 2. **Speed:** When the spike hits, new pods must be running in under a minute, **and** existing pods must not be hammered while the new ones come up.
> 3. **Cost:** After the sale, the extra capacity sits idle on the bill all night.
>
> We will solve all three live, on the cluster.

---

## Pre-Demo Setup (do BEFORE recording)

```bash
source scripts/00-env.sh
az login
az account set --subscription "$SUBSCRIPTION_ID"

bash scripts/01-prereqs.sh        # ~3 min
bash scripts/02-create-aks.sh     # ~7 min
```

Health check:

```bash
kubectl get nodes                                                              # 1 system node
kubectl get pods -n kube-system | grep alb-controller                          # 2/2 Running
kubectl get gatewayclass azure-alb-external                                    # Accepted: True
az aks show -n $CLUSTER -g $RG --query "nodeProvisioningProfile.mode" -o tsv   # → Auto
```

**Terminal layout (4 panes — Windows Terminal: Alt+Shift+= splits vertically, Alt+Shift+- splits horizontally):**

| Pane | Command | Purpose |
|---|---|---|
| **D** (driver, large font, ~half the screen) | `cd ~/demo && source scripts/00-env.sh` | where you type |
| **A** (top-right) | `kubectl get nodes -o wide -w` | node arrivals/removals |
| **B** (mid-right) | `kubectl get pods -o wide -w` | pod state changes |
| **C** (bottom-right, **the proof pane**) | `kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' -w` | Karpenter narrating itself |

> **Open in your browser before pressing Record:** GitHub repo · Azure Portal pinned to **MC_** node-resource-group (so the AGC frontend animates in live) · this script.

---

## Act 0 — The mental model (0:00 – 0:30)  ***NEW***

Show the diagram (`docs/architecture-nap-agc.png`) full-screen. Talk over it slowly:

> *"Two control loops on top of AKS. **Karpenter** — the K hexagon — watches pending pods and provisions just-in-time capacity in the right SKU family, then bin-packs and removes idle nodes. **AGC** — the blue gateway on the right — fronts those pods with an L7 load balancer that routes new traffic to the freshest, least-busy pods. Compute optimized by Karpenter. Traffic optimized by AGC. That's the whole show. Let's see it on a real cluster."*

Switch to terminal.

---

## Act 1 — "We don't know what VM SKU to pick" (0:30 – 3:30)

### Open (0:30 – 1:00)

> *"Contoso Retail's AKS cluster. One system node, no workload nodes, no node-pool plan. Today they ship the new shop service and tonight they run a flash sale."*

```bash
kubectl get nodes
kubectl get nodepool                # empty
```

### Step 1 — Apply the NodePool (1:00 – 1:45)

```bash
bat manifests/nodepool.yaml         # or: cat
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool
```

**Read aloud only these 3 lines** (let the audience eyes do the rest):

```yaml
karpenter.azure.com/sku-family       In [D, E]      # ← only general-purpose OR memory-optimized
karpenter.sh/capacity-type           In [on-demand, spot]
consolidationPolicy: WhenEmptyOrUnderutilized               # ← idle nodes get reclaimed
```

> *"This is the only NAP configuration I will write. I am not picking a VM SKU. I am giving Karpenter a **menu of families** and a cost policy. Zero nodes — NAP only acts on real demand."*

### Step 2 — Wire the AGC frontend (1:45 – 2:30)  *(now tangible)*

```bash
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml
kubectl get gateway gateway-01
```

> *"Same idea on ingress. I write a Gateway and HTTPRoute. The ALB Controller calls Azure ARM and provisions the AGC frontend for me."*

**While waiting ~30 sec for the ADDRESS to populate, switch to the Azure Portal tab pinned to `MC_$RG_$CLUSTER_$LOCATION`.** Hit refresh — the AGC frontend appears. **This is the visual proof that nothing in the portal was clicked.** Then back to terminal:

```bash
az network alb list -g MC_${RG}_${CLUSTER}_${LOCATION} -o table
```

> *"There it is. I never opened the portal. The Gateway YAML created it."*

### Step 3 — Deploy the baseline shop workload (2:30 – 3:00)

```bash
kubectl apply -f manifests/deployment-small.yaml      # shop-v1, 2 pods × 2 CPU
```

**Pane B:** pods → `Pending`.
**Pane C:** Karpenter fires — point at it as it appears:

```
NominatePod        pod/shop-v1-...  → NodeClaim/default-...
NodeClaimCreated   nodeclaim/...
Launched           Launched instance: Standard_D8ls_v5
```

### PAUSE #1 — The Reveal (3:00 – 3:20)

**Stop typing. Three full seconds of silence.** Point at `Launched Standard_D8ls_v5`.

> **"I never typed `D8ls_v5`. Karpenter read my pod spec — 2 CPU, 361 Mi — and picked the cheapest D-series VM that fits both pods. Concern #1: solved."**

### Step 4 — Confirm + plant the cost denominator (3:20 – 3:30)  ***NEW LINE***

```bash
kubectl get nodes
kubectl get pods -o wide
kubectl get gateway gateway-01           # ADDRESS now populated
curl http://<AGC-IP>/                    # nginx welcome page
```

> *"One D8ls node — about **38 cents per hour** in East US. Hold that number; we'll come back to it."*

---

## Act 2 — "The marketing email just dropped" (3:30 – 7:00)

### Set the scene (3:30 – 3:50)

> *"It is 8pm. Two things happen at once: the recommendation engine launches — that's the new memory-heavy service — and `shop-v1` traffic spikes 5x."*

### Step 5 — Apply the recommendation engine (3:50 – 4:20)

```bash
kubectl apply -f manifests/deployment-large.yaml      # recommender, 3 pods × 4 CPU / 10 Gi
```

**Optional contrast beat (NEW, ~10 sec):**

> *"In a traditional cluster, the platform team gets paged right now. They have to define a memory-optimized node pool, set min/max counts, push a PR, wait for the pipeline. With NAP, watch what happens instead."*

**Pane B:** new `recommender` pods `Pending`.
**Pane C:** Karpenter nominates them to a **new** NodeClaim. Watch for:

```
Launched     Launched instance: Standard_E16s_v5
Initialized  node/aks-default-...
```

### PAUSE #2a — The SKU-family reveal (4:20 – 4:35)

> **"`E16s_v5` — memory-optimized. **Different family** from before. Karpenter saw 10 Gi and switched families automatically. The platform team did not write a second node pool."**

### Step 6 — Scale the shop spike (4:35 – 5:00)

```bash
kubectl scale deployment shop-v1 --replicas=6
```

**Pane B:** four new shop pods → `Pending → Running`.
**Pane C:** Karpenter places them on whichever node has room (mix of D and E).

```bash
kubectl get pods -o wide              # 6 shop + 3 recommender, mixed across nodes
```

### Step 7 — Prove load-aware routing (5:00 – 6:15)

> *"AGC isn't a round-robin load balancer. The original two pods are already busy serving the spike. AGC tracks pod load and routes new connections to the **cool** pods first."*

In a separate pane (or run in pane D):

```bash
bash scripts/06-load-test.sh           # 60s of traffic, prints per-pod request distribution
```

While it runs, narrate what the audience will see in the output:

> *"Watch the distribution. The pods on the freshly-provisioned node will catch more new connections than the original two."*

When it prints:

> **"See it? Cool pods get the spike. The originally-busy pods get fewer new connections, so they don't saturate. Without load-aware routing, all six pods would split the spike evenly and the warm ones would tip first. Concern #2: solved."**

### Step 8 — User-experience sanity check (6:15 – 6:45)

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}\n" http://<AGC-IP>/; done
```

> *"Ten 200s in a row. Customers never saw a 5xx. AGC's health probes added the new pods to rotation the moment they passed."*

### PAUSE #2b — The combined reveal (6:45 – 7:00)

> **"Two workloads. Two machine families. Right machine for each. And the spike never reached an over-saturated pod. That's NAP and AGC composing — neither one needed me to write a second config file."**

---

## Act 3 — "After the sale, where does the cost go?" (7:00 – 9:00)

### Set the scene (7:00 – 7:15)

> *"It is 11pm. The sale is over. In a traditional cluster, that E16s sits on the bill until morning. Watch what NAP does."*

### Step 9 — Scale down (7:15 – 7:45)

```bash
kubectl scale deployment recommender --replicas=0
kubectl scale deployment shop-v1 --replicas=2
```

**Pane B:** pods `Terminating`.
**Pane C:**

```
Disrupting            nodeclaim/...   via consolidation: replace
WaitingForDeletion    node/...
Deleted               node/...
```

(1–2 min depending on `consolidateAfter`. Fill the silence with the cost framing below.)

### PAUSE #3 — The cost reveal (7:45 – 8:15)  ***denominator now lands***

Point at `Deleted node`.

> **"That E16s_v5 just got terminated. About **\$1.00 per hour** in East US. We had it for one hour during the sale. If this had been a manually-managed pool, it'd run all night — call it 8 idle hours, $8 saved on a single node, on a single workload, on a single night. Multiply by every workload, every team, every cluster, every night. Concern #3: solved."**

### Step 10 — Steady state (8:15 – 8:40)

```bash
kubectl get nodes                       # back to one D-family workload node
kubectl get pods -o wide                # bin-packed
curl http://<AGC-IP>/                   # AGC still works, no manual reconfig
```

### Closing (8:40 – 9:30)

> *"Recap what we did NOT do tonight:*
>
> *— Did not pre-create node pools for two workload shapes.*
> *— Did not provision an AGC frontend in the Azure Portal.*
> *— Did not write any HPA, CA, or autoscale logic.*
> *— Did not manually drain or terminate any node.*
>
> *What we did do:*
>
> *— One NodePool YAML. Karpenter picked the SKUs.*
> *— One Gateway YAML. The ALB Controller programmed AGC.*
> *— Deployed pods. The cluster did the rest.*
>
> *NAP for compute. AGC for traffic. Together, your AKS cluster becomes a self-managing platform."*

References on screen:

- [aka.ms/aks/nap](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [aka.ms/agc](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)

---

## Karpenter Event Cheat-Sheet *(unchanged)*

| Event | Meaning | When |
|---|---|---|
| `NominatePod` | Karpenter claimed a pending pod | immediately |
| `NodeClaimCreated` | Decision made, spinning up VM | within ~5 s |
| `Launched instance: Standard_<SKU>` | **The reveal** — VM type chosen | within ~30 s |
| `Initialized` | Node is `Ready`, pods can bind | within ~60–90 s |
| `Disrupting via consolidation: replace` | Under-utilized node being removed | after scale-down |
| `Deleted NodeClaim` | VM terminated, billing stops | consolidation done |

---

## Reset Between Takes  ***now also resets AGC***

```bash
kubectl scale deployment recommender --replicas=0 --ignore-not-found
kubectl scale deployment shop-v1 --replicas=2
# wait ~3 min for Karpenter consolidation, then:
kubectl get nodes                       # back to a single D-node
```

To restart from a fully empty cluster (workloads **and** AGC frontend):

```bash
kubectl delete -f manifests/deployment-large.yaml --ignore-not-found
kubectl delete -f manifests/deployment-small.yaml --ignore-not-found
kubectl delete -f manifests/gateway.yaml          --ignore-not-found
kubectl delete -f manifests/nginx-service.yaml    --ignore-not-found
# wait for consolidation + AGC frontend teardown (~2 min in MC_ RG)
# then redeploy from Act 1 Step 1
```

---

## Time-Constrained Variants  *(unchanged)*

- **5 min:** drop Act 3, end after Step 7. Cost story becomes a closing sentence.
- **3 min:** Act 1 only — apply NodePool → apply baseline → point at `Launched`. The "self-managing" point still lands.

---

## Improvement summary (vs. the YouTube walkthrough at WYRRQUDa6TQ)

| Where their demo wins | Where yours wins |
|---|---|
| They show the NodePool YAML on screen with ~3 highlighted lines (now mirrored in v2 Step 1) | You frame everything as a **customer story**, not a feature walkthrough |
| They use a live Karpenter event watch as the proof pane (already in your layout) | You demo **two distinct workloads** to prove SKU-family switching, not just a bigger node |
| They narrate the SKU choice the moment it appears (now codified as PAUSE #1) | You demo **AGC + load-aware routing** — they show none of this |
| | You demo **consolidation / cost reclaim** with a $/hour denominator — they show none of this |
| | Your closing "what we did NOT do" is sharper than their "thanks for watching" |
