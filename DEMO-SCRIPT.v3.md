# Demo Script v3 — AGC + NAP: A Friendly Story About Cost & Calm

> **What changed from v2** (notes for you, the presenter — delete before recording):
>
> 1. **Friendlier opening.** Less "feature pitch", more "have you ever felt this pain?" — names the three NAP scenarios up front so the audience self-identifies.
> 2. **The diagram now narrates itself.** Act 0 walks the diagram left-to-right with one human sentence per region of the picture. The same diagram (`docs/architecture-nap-agc.png`) returns in Act 3 to "close the loop".
> 3. **YAML on screen, big and slow.** Step 1 now has explicit "**zoom your terminal to 18pt+**" + "read these 3 lines aloud" guardrails. The lines are circled in the script so you don't lose them.
> 4. **The Karpenter event pane is sticky, not a reveal.** Pane C (`kubectl get events --field-selector source=karpenter -w`) is visible **the entire demo**, not just during peak moments. It's the "live narrator".
> 5. **The "I never asked for that" beat is now its own block.** PAUSE #1 has a literal stopwatch — `// 3 silent seconds //` — so you remember to let it breathe.
> 6. **Cost story is humanized.** Instead of "$8 per night", we frame it as "the dev who went home and didn't have to think about it". Numbers still in there for the CFO in the room.
> 7. **References a companion deck** (`docs/AGC-NAP-Beginner-Deck.pptx`) for anyone who wants slides instead of (or before) a live demo.

---

## 🎯 The Customer Scenario — and the three flavors of pain NAP solves

Before any CLI, set the table. Read this slowly — this is the moment people decide whether to lean in.

> *"Quick show of hands — has anyone here ever:*
> *…paged a teammate at 2am because pods were pending and nobody knew which VM size to add?*
> *…paid for a node pool that ran all weekend because a job finished Friday at 5pm?*
> *…written 'temporary' YAML for a node pool that's still in production three years later?*
>
> *That's the three jobs NAP does. Let me put names on them:"*

**Three NAP scenarios — frame these out loud:**

| # | Scenario | Who feels this pain | What NAP does |
|---|---|---|---|
| **1** | **Unpredictable workloads** *(traffic spikes, bursty jobs)* | E-commerce, news, ticketing, AI inference | Right-sizes nodes the moment pods land — no pre-buy |
| **2** | **Varying resource needs** *(one app wants CPU, the next wants memory or GPU)* | AI/ML platforms, data teams, multi-tenant SRE | Picks a different VM **family** per workload, automatically |
| **3** | **The "node sprawl + scheduling failure" tax** *(too many node pools, half-empty nodes, "Pending" pods)* | Anyone with > 1 cluster, > 2 teams | Bin-packs across families, reclaims idle nodes, no scheduling dead-ends |

> *"Tonight we'll watch all three happen on a real cluster. Meet **Contoso Retail**."*

**Contoso Retail** runs `shop.contoso.com` on AKS.
At 8pm, marketing sends a flash-sale email to 2 million subscribers. Traffic will spike 5x within minutes, then drain a few hours later.

Their three concerns map 1:1 to the table above:

1. **Sizing** — the new recommendation engine needs ~10 Gi/pod. The current node pool is CPU-tuned. What VM do they add? *(Scenario 2)*
2. **Speed** — when the spike hits, new pods must be running in under a minute, **and** existing pods must not be hammered while new ones come up. *(Scenario 1)*
3. **Cost** — after the sale, the extra capacity sits on the bill until somebody notices. *(Scenario 3)*

> *"And the friendly version of the punchline: nobody at Contoso has to think about any of this tonight. NAP handles the machines. AGC handles the traffic. The on-call engineer goes to dinner."*

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

### Terminal layout — make Pane C the **always-on narrator**

Four panes (Windows Terminal: `Alt+Shift+=` vertical split, `Alt+Shift+-` horizontal split). **Critical: Pane C must be visible from the moment you press Record until the last frame. Do not hide it during reveals — it IS the reveal.**

| Pane | Command | Purpose | Visibility |
|---|---|---|---|
| **D** *(driver, ~half the screen, **18pt+ font**)* | `cd ~/demo && source scripts/00-env.sh` | Where you type | always |
| **A** *(top-right)* | `kubectl get nodes -o wide -w` | Node arrivals/removals | always |
| **B** *(mid-right)* | `kubectl get pods -o wide -w` | Pod state changes | always |
| **C** *(bottom-right — **the proof pane, never hide this**)* | `kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' -w` | Karpenter narrating itself, in real time | **ALWAYS — entire demo** |

> 📌 **Font check before recording:** in Pane D, run `cat manifests/nodepool.yaml`. If you can read it from across the room, you're set. If not, bump font size again. The audience needs to see "how little config drives all this magic" — and they can only see that if the YAML is **legible**.

> **Open in your browser before pressing Record:**
> - GitHub repo (the new architecture diagram is at the top of the README)
> - Azure Portal pinned to the **MC_** node-resource-group
> - This script
> - The companion deck `docs/AGC-NAP-Beginner-Deck.pptx` (for the "want slides instead?" follow-up)

---

## Act 0 — Walk the diagram (0:00 – 0:45)  *(updated)*

Show `docs/architecture-nap-agc.png` full-screen. Point with your cursor as you go — left to right, one human sentence per region:

> *"This is the whole show on one slide. Three columns, two control loops.*
>
> *— **Far left**: pods that want to run. Some land on existing capacity, some can't fit anywhere — those are the **unscheduled** ones.*
>
> *— **Middle**: the K hexagon — that's **Karpenter**, the brain inside NAP. It looks at unscheduled pods and spins up a node in the **right size and family** to fit them. No pre-bought capacity, no guessing.*
>
> *— **Top right**: the cluster after Karpenter has done its job. Pods bin-packed neatly at 77% utilization. Idle slots get reclaimed.*
>
> *— **Far right**: **Application Gateway for Containers** — AGC. It watches pod load and sends new traffic to the **cool** pods (the green bar at 9%) instead of pounding the **hot** ones (the orange bar at 77%).*
>
> *NAP optimizes the machines. AGC optimizes the traffic. Together your AKS cluster runs itself. Let's prove it."*

Switch to terminal. **Pane C is already streaming** — that's intentional. The audience should see Karpenter "talking" before you've even typed anything.

---

## Act 1 — "We don't know what VM SKU to pick" (0:45 – 3:45)

### Open (0:45 – 1:15)

> *"Contoso Retail's AKS cluster. One system node, no workload nodes, no node-pool plan. Today they ship the new shop service and tonight they run a flash sale."*

```bash
kubectl get nodes
kubectl get nodepool                # empty
```

### Step 1 — Apply the NodePool (1:15 – 2:15)  *(YAML on screen, BIG)*

> 🔍 **Presenter cue:** Before running `cat`, **double the font size in Pane D one more notch**. The YAML must be readable to someone in the back row. This is the moment that makes the whole demo land — *"all of this from one tiny config"*.

```bash
bat manifests/nodepool.yaml         # or: cat
```

**Read these 3 lines aloud — say them slowly. Let the rest of the YAML scroll past silently.**

```yaml
karpenter.azure.com/sku-family       In ["D", "E"]      # ← only general-purpose OR memory-optimized
karpenter.sh/capacity-type           In ["on-demand", "spot"]
consolidationPolicy: WhenUnderutilized                     # ← idle nodes get reclaimed
```

> *"Three lines. That's it. I am not picking a VM SKU. I am giving Karpenter a **menu of families** and a cost policy. Everything else — what size, when to scale, when to remove — is a Karpenter decision. And I have **zero nodes** right now. NAP only acts on real demand."*

```bash
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool
```

### Step 2 — Wire the AGC frontend (2:15 – 3:00)

```bash
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml
kubectl get gateway gateway-01
```

> *"Same idea on ingress. I write a Gateway and HTTPRoute. The ALB Controller calls Azure ARM and provisions the AGC frontend for me."*

While waiting ~30s for ADDRESS to populate, switch to the Azure Portal tab pinned to `MC_$RG_$CLUSTER_$LOCATION`. Hit refresh — the AGC frontend appears. **This is the visual proof that nothing in the portal was clicked.** Then back to terminal:

```bash
az network alb list -g MC_${RG}_${CLUSTER}_${LOCATION} -o table
```

> *"There it is. I never opened the portal. The Gateway YAML created it."*

### Step 3 — Deploy the baseline shop workload (3:00 – 3:25)

```bash
kubectl apply -f manifests/deployment-small.yaml      # shop-v1, 2 pods × 2 CPU
```

**Pane B** → pods go `Pending`.
**Pane C** *(remember — visible the entire time)* → Karpenter starts narrating. Point at it as it appears:

```
NominatePod        pod/shop-v1-...     → NodeClaim/default-...
NodeClaimCreated   nodeclaim/...
Launched           Launched instance: Standard_D8ls_v5
```

### ⏸  PAUSE #1 — "I never asked for that" (3:25 – 3:35)  *(stopwatched)*

**Stop typing. Hands off the keyboard. Look at the screen, not the audience.**

`// 1… 2… 3… //`  *(three full silent seconds — count them in your head)*

Now point at `Launched Standard_D8ls_v5`:

> **"I never typed `D8ls_v5`. Karpenter read my pod spec — 2 CPU, 361 Mi — and picked the cheapest D-series VM that fits both pods. Concern #1: solved."**

### Step 4 — Confirm + plant the cost denominator (3:35 – 3:45)

```bash
kubectl get nodes
kubectl get pods -o wide
kubectl get gateway gateway-01           # ADDRESS now populated
curl http://<AGC-IP>/                    # nginx welcome page
```

> *"One D8ls node — about **38 cents per hour** in East US. Hold that number; we'll come back to it when the sale ends."*

---

## Act 2 — "The marketing email just dropped" (3:45 – 7:15)

### Set the scene (3:45 – 4:05)

> *"It is 8pm. Two things happen at once: the recommendation engine launches — that's the new memory-heavy service — and `shop-v1` traffic spikes 5x. The on-call engineer is at dinner. They have not opened a laptop."*

### Step 5 — Apply the recommendation engine (4:05 – 4:35)

```bash
kubectl apply -f manifests/deployment-large.yaml      # recommender, 3 pods × 4 CPU / 10 Gi
```

**The contrast beat (10 sec) — sets up the next reveal:**

> *"In a traditional cluster, the platform team gets paged right now. They have to define a memory-optimized node pool, set min/max counts, push a PR, wait for the pipeline. Watch what happens instead."*

**Pane B:** new `recommender` pods → `Pending`.
**Pane C:** Karpenter nominates them to a *new* NodeClaim. Watch for:

```
Launched     Launched instance: Standard_E16s_v5
Initialized  node/aks-default-...
```

### ⏸  PAUSE #2a — The SKU-family reveal (4:35 – 4:50)

`// 1… 2… 3… //`

> **"`E16s_v5` — memory-optimized. **Different family** from before. Karpenter saw 10 Gi per pod and switched families automatically. The platform team did not write a second node pool. That's NAP scenario #2 happening live."**

### Step 6 — Scale the shop spike (4:50 – 5:15)

```bash
kubectl scale deployment shop-v1 --replicas=6
```

**Pane B:** four new shop pods → `Pending → Running`.
**Pane C:** Karpenter places them on whichever node has room (mix of D and E).

```bash
kubectl get pods -o wide              # 6 shop + 3 recommender, mixed across nodes
```

### Step 7 — Prove load-aware routing (5:15 – 6:30)

> *"Now AGC's turn. AGC isn't a round-robin load balancer. The original two pods are already busy serving the spike. AGC tracks pod load and routes new connections to the **cool** pods first — the same green-bar pods you saw on the diagram."*

```bash
bash scripts/06-load-test.sh           # 60s of traffic, prints per-pod request distribution
```

While it runs:

> *"Watch the distribution. The pods on the freshly-provisioned node will catch more new connections than the original two."*

When it prints:

> **"See it? Cool pods get the spike. The originally-busy pods get fewer new connections, so they don't saturate. Without load-aware routing, all six pods would split the spike evenly and the warm ones would tip first. Concern #2: solved."**

### Step 8 — User-experience sanity check (6:30 – 7:00)

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}\n" http://<AGC-IP>/; done
```

> *"Ten 200s in a row. Customers never saw a 5xx. AGC's health probes added the new pods to rotation the moment they passed."*

### ⏸  PAUSE #2b — The combined reveal (7:00 – 7:15)

> **"Two workloads. Two machine families. Right machine for each. And the spike never reached an over-saturated pod. That's NAP and AGC composing — neither one needed me to write a second config file. The on-call engineer is still at dinner."**

---

## Act 3 — "After the sale, where does the cost go?" (7:15 – 9:15)

### Set the scene (7:15 – 7:30)

> *"It is 11pm. The sale is over. In a traditional cluster, that E16s sits on the bill until morning, because nobody wants to be the engineer who deletes a node at midnight. Watch what NAP does instead."*

### Step 9 — Scale down (7:30 – 8:00)

```bash
kubectl scale deployment recommender --replicas=0
kubectl scale deployment shop-v1 --replicas=2
```

**Pane B:** pods `Terminating`.
**Pane C** *(still your sticky narrator)*:

```
Disrupting            nodeclaim/...   via consolidation: replace
WaitingForDeletion    node/...
Deleted               node/...
```

(1–2 min depending on `consolidateAfter`. Fill the silence with the cost framing below.)

### ⏸  PAUSE #3 — The cost reveal, told like a story (8:00 – 8:45)  *(humanized)*

Point at `Deleted node`. Bring the energy down — this isn't a victory lap, it's relief.

> **"That E16s_v5 just got terminated. About **\$1.00 per hour** in East US. We had it for one hour during the sale.*
>
> *Here's what didn't happen tonight:*
>
> *— Nobody got paged.*
> *— Nobody approved a node-pool PR at 11pm.*
> *— Nobody wrote a 'temporary' YAML that would still be in production next quarter.*
> *— Nobody on the finance team will open a ticket on Monday asking 'why did we burn a memory-optimized VM all weekend?'*
>
> *And the math: roughly **\$8 saved on a single node, on a single workload, on a single night**. Multiply by every workload, every team, every cluster, every night. That's the budget you suddenly have for the things you actually want to build.*
>
> *Concern #3: solved. The on-call engineer is asleep."**

### Step 10 — Steady state (8:45 – 9:00)

```bash
kubectl get nodes                       # back to one D-family workload node
kubectl get pods -o wide                # bin-packed
curl http://<AGC-IP>/                   # AGC still works, no manual reconfig
```

### Closing — bring the diagram back (9:00 – 9:30)

Re-show `docs/architecture-nap-agc.png`.

> *"Same diagram I started with. Now you've watched it happen on real metal. Recap what we did NOT do tonight:*
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
> *NAP for compute. AGC for traffic. Together, your AKS cluster becomes a self-managing platform — and your team gets their evenings back."*

References on screen:

- [aka.ms/aks/nap](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [aka.ms/agc](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)
- Companion deck: `docs/AGC-NAP-Beginner-Deck.pptx`

---

## Karpenter Event Cheat-Sheet

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

## Time-Constrained Variants

- **5 min:** drop Act 3, end after Step 7. Cost story becomes one closing sentence.
- **3 min:** Act 1 only — apply NodePool → apply baseline → point at `Launched`. The "self-managing" point still lands.

---

## Presenter checklist (the night before)

- [ ] Pane D font ≥ 18pt — confirmed by reading YAML from across the room
- [ ] Pane C running and visible the whole demo (not minimized)
- [ ] PAUSE #1 stopwatched: 3 silent seconds when `Standard_D8...` appears
- [ ] Diagram open in a tab for Act 0 and Closing
- [ ] Companion deck (`docs/AGC-NAP-Beginner-Deck.pptx`) handy
- [ ] Three NAP scenarios memorized so the opening lands without reading
