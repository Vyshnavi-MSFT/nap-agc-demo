# Demo Script v4 — AGC + NAP, Slide-Synced

> **Companion deck:** `docs/AGC-NAP-Beginner-Deck.pptx` (14 slides)
> **Every section below has a `🖼 SLIDE X` cue.** Advance the deck on that cue, not before.
>
> **Two ideas you only need to remember:**
> 1. **NAP picks the machines** — no more guessing VM sizes.
> 2. **AGC picks the pods** — busy pods don't get pounded.
>
> If you remember those two sentences, the rest of this script makes sense.

---

## 🎬 Pre-flight checklist (before the audience walks in)

| ✅ | Item |
|---|---|
| ☐ | Deck open at **Slide 1**, presenter view on |
| ☐ | Windows Terminal open with **4 panes** (see "Terminal layout" below); font ≥ 18pt in Pane D |
| ☐ | Pane C **already streaming** Karpenter events (don't start it on stage) |
| ☐ | Browser tabs: GitHub repo · Azure Portal pinned to `MC_nap-agc-demo-rg_nap-agc-demo_eastus2` · this script |
| ☐ | Cluster `nap-agc-demo` in `eastus2` is up, NAP=Auto, ALB controller pods Running |
| ☐ | Run `bash scripts/99-cleanup.sh` so you're starting from a clean slate (1 system node, no NodePool, no Gateway) |

---

# 🖼 SLIDE 1 — Title  *(0:00 – 0:20)*

> *"Tonight you're going to watch one AKS cluster handle a flash sale — and not one human is going to size a VM, write a node pool, or click anything in the portal. The cluster figures it out. We sit here and watch."*

**Click → Slide 2.**

---

# 🖼 SLIDE 2 — The three pains  *(0:20 – 1:10)*

> *"Quick show of hands. Has anyone here ever:*
> *— been paged at 2 a.m. because pods were stuck and nobody on call knew which kind of VM to add?*
> *— paid for a cluster that ran all weekend because a job finished Friday at 5 p.m.?*
> *— written 'temporary' YAML for a node pool — and that file is still in production three years later?*
>
> *Don't be shy. Most of us have done all three. Those are tonight's three pains."*

Read each card slowly while you point at it on the slide:

| # | Pain | What we'll see fix it |
|---|---|---|
| 1 | **Unpredictable workloads** — spikes you can't plan for | NAP adds the right machine the moment a pod needs one |
| 2 | **Different apps need different machines** — CPU vs memory vs GPU | NAP picks a different VM **family** per app, automatically |
| 3 | **Idle nodes that bill all night** — "temporary" pools that never go away | NAP removes nodes when nobody's using them |

**Click → Slide 3.**

---

# 🖼 SLIDE 3 — Meet Contoso Retail  *(1:10 – 1:55)*

> *"Picture a small online shop — `shop.contoso.com` — running on AKS. Tonight at 8 p.m., marketing is sending a flash-sale email to **2 million subscribers**. Traffic will jump 5× in minutes, then drain a few hours later.*
>
> *The on-call engineer just sat down to dinner. They will **not** open a laptop tonight.*
>
> *Three worries:*
> *1. **Sizing** — they want to launch a new recommender service that needs a lot of memory. Their cluster today has only CPU-tuned machines.*
> *2. **Speed** — when the spike hits, new pods must come up in under a minute, and the busy pods must not get hammered.*
> *3. **Cost** — after 11 p.m., the extra capacity must not sit on the bill all night.*
>
> *We're going to solve all three live."*

**Click → Slide 4.**

---

# 🖼 SLIDE 4 — What is NAP?  *(1:55 – 2:45)*

Walk the 4 boxes left-to-right with your cursor on the slide:

> *"**NAP — Node Auto Provisioning** — is an AKS add-on with one job: keep your pods running on the cheapest machine that fits, with the least config from you.*
>
> *— **Step 1:** A pod becomes Pending — it has nowhere to land.*
> *— **Step 2:** Karpenter — the open-source brain inside NAP — looks at what the pod is asking for: CPU, memory, GPU, architecture, zone.*
> *— **Step 3:** It checks Azure's **live** price list and capacity, and picks the cheapest VM that fits.*
> *— **Step 4:** It deletes the node when nobody needs it.*
>
> *No node pool to write. No SKU to guess. No 'minimum 3 nodes' running all weekend."*

> 🎤 **Beginner-friendly recap line:** *"Before NAP, you had to guess VM sizes and write node pools by hand. With NAP, you describe the menu — D family, E family, on-demand, spot — and NAP orders for you."*

**Click → Slide 5.**

---

# 🖼 SLIDE 5 — Mixed Autoscaling  *(2:45 – 3:15)*

> *"This is the part most people miss. NAP can mix **many SKUs in one pool** — a D8 here, an E16 there, an AMD v6 next to an Intel v5 — all governed by the same single config.*
>
> *Why does that matter? Bin-packing. NAP picks whichever SKU **fits the next pod best for the lowest price** — even if that means a different SKU each time. Less waste, less complexity, no second pool to maintain."*

**Click → Slide 6.**

---

# 🖼 SLIDE 6 — Common scaling strategies  *(3:15 – 3:55)*

Three columns on the slide. Cover briefly:

| Layer | What it does | When you reach for it |
|---|---|---|
| **HPA · VPA · KEDA** | Scale **pods** up/down (CPU, memory, queue depth, custom events) | Pair *with* NAP — pods scale first, NAP follows with nodes |
| **NAP + Spot VMs** | Use Azure spare capacity at up to 70% off | Batch jobs, dev/test, large stateless compute. NAP evicts gracefully when capacity is reclaimed. |
| **Intel · AMD · ARM64** | Mix architectures in the same cluster | Cost-sensitive workloads, ARM-friendly apps (Java, Go, Node) |

> 🎤 *"Think of this as a layer cake. KEDA tells pods to scale on a queue. HPA and VPA right-size them. NAP underneath finds the cheapest machine — could be Intel, AMD, ARM, on-demand, or spot — that fits the new shape."*

**Click → Slide 7.**

---

# 🖼 SLIDE 7 — Taints, affinity, topology  *(3:55 – 4:25)*

> *"Sometimes you **do** want control — say, GPU workloads only on GPU nodes, or spread across zones for HA. NAP respects all the standard Kubernetes hints: **taints, tolerations, node affinity, topology spread constraints**. You write them once on the pod; NAP picks SKUs that satisfy them."*

Point at the YAML snippet on the slide and read just the `nodeAffinity` block out loud — don't dwell.

**Click → Slide 8.**

---

# 🖼 SLIDE 8 — What is AGC?  *(4:25 – 5:00)*

Tagline at the top of the slide:
> **"Azure-native, out-of-cluster, modern application load balancer for AKS."**

Unpack it word by word:

> *"**Azure-native** — it's a first-party Azure service. No Helm charts, no community controllers. One AKS flag turns it on.*
> ***Out-of-cluster** — the data plane runs in Microsoft's network, not on your nodes. Your nodes don't pay the load-balancer tax.*
> ***Modern** — it speaks the new Kubernetes Gateway API, not legacy Ingress. Path-based routing, header rewrites, traffic splits, all native.*
> ***For AKS** — purpose-built; managed identity, VNet integration, Azure Monitor — all wired up for you."*

**Click → Slide 9.**

---

# 🖼 SLIDE 9 — Load-aware routing (the killer feature)  *(5:00 – 5:45)*

The visual: AGC hexagon → 3 pods (A 0%, B 25%, C 50% GPU). ORCA load reports flow back.

> *"Most load balancers do round-robin. They send request #1 to pod A, #2 to pod B, #3 to pod C — even if pod C is on fire.*
>
> *AGC is different. The pods report their **actual** load back via ORCA — the open standard for backend load reporting. AGC routes new connections to the **calmest** pod every time.*
>
> *That's why for AI/ML, microservices, GPU inference, anything with **uneven** per-request cost, AGC is the right answer. The hot pod doesn't get hotter."*

> 🎤 *"In a flash sale, this is what stops your busiest two pods from tipping over."*

**Click → Slide 10.**

---

# 🖼 SLIDE 10 — Architecture diagram  *(5:45 – 6:30)*

Full-bleed diagram. Point with your cursor as you talk:

> *"Two control loops on top of one AKS cluster.*
> *— **Far left:** Pending pods.*
> *— **Middle (K hexagon):** Karpenter spinning up the right node.*
> *— **Top right:** the cluster after consolidation. Nice and tight.*
> *— **Far right:** AGC — the calm-pod router.*
>
> ***NAP optimizes machines. AGC optimizes traffic. Together your cluster runs itself.***
>
> *Now let's prove it on a real cluster."*

**Click → Slide 11.** Then switch to terminal.

---

## 🪟 Terminal layout — the "always-on narrator"

Four panes (Windows Terminal: `Alt+Shift+=` vertical, `Alt+Shift+-` horizontal). **Pane C must stay visible the entire demo.**

| Pane | Command | What it shows |
|---|---|---|
| **D** *(driver, ~half screen, **18pt+**)* | `cd ~/demo && source scripts/00-env.sh` | Where you type |
| **A** *(top-right)* | `kubectl get nodes -L karpenter.azure.com/sku-name,karpenter.sh/capacity-type -w` | Nodes appearing & SKU NAP picked |
| **B** *(mid-right)* | `kubectl get pods -o wide -w` | Pods going Pending → Running |
| **C** *(bottom-right — never hide)* | `kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' -w` | Karpenter narrating itself |

---

# 🖼 SLIDE 11 — "Three lines of YAML" *(stay on this slide while you do Act 1)*

The slide shows just:
```yaml
karpenter.azure.com/sku-family   In ["D","E"]
karpenter.sh/capacity-type       In ["on-demand","spot"]
consolidationPolicy: WhenEmptyOrUnderutilized
```

This slide is your **anchor for Act 1**. Audience sees these 3 lines while you type.

---

## 🛠 Pre-Demo Setup — "the cluster I already built earlier" *(6:30 – 7:30)*

> *"Before this session, I ran one Azure CLI command to create the cluster. I'm not going to make you watch a 7-minute create. But I want you to see the command — because the magic isn't hidden in a portal click."*

Show this on screen (not from memory — paste it):

```bash
az aks create \
  -n nap-agc-demo  -g nap-agc-demo-rg  -l eastus2 \
  --network-plugin azure --network-plugin-mode overlay \   # ← Azure CNI Overlay
  --network-dataplane cilium \                             # ← Cilium dataplane
  --node-provisioning-mode Auto \                          # ← turns NAP ON
  --enable-gateway-api \                                   # ← Gateway API CRDs
  --enable-application-load-balancer \                     # ← installs AGC controller
  --enable-oidc-issuer --enable-workload-identity \
  --node-count 1 --generate-ssh-keys \
  -o table
```

**The four flags that matter, read slowly:**
1. `--node-provisioning-mode Auto` — NAP on.
2. `--enable-application-load-balancer` — AGC controller add-on.
3. `--enable-gateway-api` — modern Gateway CRDs.
4. `--network-plugin-mode overlay` + `--network-dataplane cilium` — fast pod networking (required for NAP).

> *"That's the whole cluster setup. One command. No Helm. No Karpenter installer. Both NAP and AGC ship in the box."*

### Prove the cluster is healthy *(live commands)*

```bash
# 1. Cluster + NAP mode + dataplane
az aks show -n nap-agc-demo -g nap-agc-demo-rg \
  --query "{name:name, k8s:kubernetesVersion, nap:nodeProvisioningProfile.mode, dataplane:networkProfile.networkDataplane}" \
  -o table
```
> *"NAP=Auto, dataplane=cilium. Healthy."*

```bash
# 2. AGC controller is running
kubectl get pods -n kube-system | grep alb-controller
```
> *"Two `alb-controller` pods, Running. That's the bridge between Gateway YAML and the actual Azure load balancer."*

```bash
# 3. Gateway API is wired up
kubectl get gatewayclass azure-alb-external
```
> *"`Accepted: True`. Ready to demo."*

---

# Act 1 — "What VM should I pick?"  *(7:30 – 11:00)*  — *stay on Slide 11*

### Open

> *"One system node, no workload nodes, no node pool. Today Contoso ships the new shop service."*

```bash
kubectl get nodes
kubectl get nodepool                 # empty — no pool yet
```

### Step 1 — Apply the NodePool

> 🔍 **Stop. Bump your terminal font one notch.** This is the moment.

```bash
cat manifests/nodepool.yaml
```

**Read these 3 lines out loud — slowly. Match them to Slide 11.**

```yaml
karpenter.azure.com/sku-family   In ["D", "E"]
karpenter.sh/capacity-type       In ["on-demand", "spot"]
consolidationPolicy: WhenEmptyOrUnderutilized
```

> *"Three lines. That's the entire NAP configuration.*
>
> *I'm not picking a VM size. I'm not picking a number of nodes. I'm giving Karpenter a **menu**: 'use the D family or E family, mix on-demand and spot, and please clean up nodes when nobody needs them.'*
>
> *Everything else — what size, when to scale, when to remove — is Karpenter's call."*

```bash
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool
```

### Step 2 — Wire up the AGC frontend

```bash
cat  manifests/nginx-service.yaml
kubectl apply -f manifests/nginx-service.yaml

cat  manifests/gateway.yaml
kubectl apply -f manifests/gateway.yaml

kubectl get gateway gateway-01
```

> *"Same idea on the traffic side. I write a Gateway and an HTTPRoute — **standard Kubernetes**, not Azure-specific YAML. The ALB Controller catches that and provisions the Azure load balancer for me."*

While you wait ~30 seconds for `ADDRESS` to populate, switch to the Azure Portal tab pinned to `MC_nap-agc-demo-rg_nap-agc-demo_eastus2` and refresh — the new AGC frontend appears.

> *"There it is — appearing in the portal. I never opened the portal. I never clicked Create."*

> ⚠️ **AGC fallback (if the Gateway ADDRESS is still blank after ~3 min):** the Service Networking RP in `eastus2` occasionally throws an `InternalServerError` on first association. **Don't get stuck on stage.** Say:
> > *"AGC is provisioning the public IP — sometimes Azure regional capacity adds a minute. Let's keep going on the NAP side; we'll come back when the IP appears. The interesting story tonight is what NAP picks."*
>
> Then jump straight to Step 3.

```bash
az network alb list -g MC_nap-agc-demo-rg_nap-agc-demo_eastus2 -o table
```

### Step 3 — Deploy the baseline shop workload

```bash
cat manifests/deployment-small.yaml
kubectl apply -f manifests/deployment-small.yaml      # shop-v1: 2 pods × 2 CPU
```

**Watch what happens — point at each pane:**

- **Pane B:** the two new pods → `Pending` *(no workload nodes yet)*
- **Pane C:** Karpenter wakes up:

```
NominatePod        pod/shop-v1-...     → NodeClaim/default-...
NodeClaimCreated   nodeclaim/...
Launched           Status condition transitioned ... Reason: Launched
Registered ... Initialized ... Ready: True
```

> ⚠️ **Heads-up:** the `Launched` event message **does not include the SKU name** in this Karpenter version. To surface it, run command #4 below.

### Step 4 — Surface the picked SKU and **PAUSE #1**

```bash
kubectl get nodes -L karpenter.azure.com/sku-name,karpenter.sh/capacity-type
```

You'll see something like:

```
NAME                STATUS   AGE   SKU-NAME            CAPACITY-TYPE
aks-default-7ct97   Ready    2m    Standard_D8als_v6   spot
```

### ⏸  PAUSE #1 — "I never asked for that"

**Stop typing. Hands off the keyboard. Don't talk for 3 seconds.**

`// 1… 2… 3… //`

Now point at the `SKU-NAME` cell and read it **out loud, exactly as it appears**:

> **"`Standard_D8als_v6` — `spot`. I never typed that anywhere. Karpenter looked at my pods, saw they want 2 CPUs and a few hundred megs of memory each, checked Azure's **live** price list, and picked the cheapest D-family machine that fits — on **spot capacity**, which is up to 70% off retail.*
>
> *Pain #1 — **'no more guessing machine sizes'** — solved. On screen. Live. Without me touching anything."**

> 🎤 **The SKU you see may differ from mine.** Karpenter picks based on **today's** prices and capacity, in **your** region. You might see `D8s_v5`, `D8ls_v5`, `D8als_v6`, on-demand, or spot. **Read whatever appears — the surprise *is* the story.**

> 🎤 **If it picks on-demand instead of spot:** *"Today it picked on-demand because spot capacity for that SKU is tight in this region right now — and that's the point. Karpenter checks **live** every time."*

### Step 5 — Plant the cost number

```bash
kubectl get pods -o wide
kubectl get gateway gateway-01           # ADDRESS now populated (or still pending — see fallback)
curl http://<AGC-IP>/                    # nginx welcome page
```

> *"One D8-class node, **on spot** — pennies an hour instead of dollars. Hold that number; we'll come back to it when the sale ends."*

---

# 🖼 SLIDE 12 — Cost story  *(advance the slide here, even though we'll narrate the full cost story in Act 3)*

This slide has the "$8 saved · what didn't happen tonight" callout. Leave it up while you flip back to terminal for Act 2.

---

# Act 2 — "The marketing email just dropped"  *(11:00 – 14:30)*

### Set the scene

> *"It is 8 p.m. Two things happen at once. The recommendation engine launches — the new memory-heavy app — and shop traffic spikes 5×. The on-call engineer is on dessert."*

### Step 6 — Apply the recommendation engine

```bash
kubectl apply -f manifests/deployment-large.yaml      # recommender: 3 pods × 4 CPU / 10 GiB RAM
```

**Set up the next reveal (10 seconds):**

> *"In a normal cluster, the platform team gets paged right now. They have to write a memory-optimized node pool, set min/max counts, push a PR, wait for the pipeline. Watch what happens here instead."*

- **Pane B:** new `recommender` pods → `Pending`
- **Pane C:** Karpenter creates a *brand new* NodeClaim
- **Pane A:** new node appears with a **different** SKU

Then run:

```bash
kubectl get nodes -L karpenter.azure.com/sku-name,karpenter.sh/capacity-type
```

You'll see something like:

```
aks-default-7ct97   Ready  ...  Standard_D8als_v6   spot       ← shop-v1 lives here
aks-default-xxxxx   Ready  ...  Standard_E16s_v5    on-demand  ← recommender lives here
```

### ⏸  PAUSE #2a — Different family, no extra config

`// 1… 2… 3… //`

> **"`E16s_v5` — that's **memory-optimized**. A different VM family from the D8 we got a minute ago.*
>
> *Karpenter saw a pod that asked for 10 gigs of memory and quietly switched families. The platform team did **not** write a second node pool. **One YAML file, two completely different machines, zero human in the loop.*** That's pain #2 — solved live."**

### Step 7 — Scale the shop spike

```bash
kubectl scale deployment shop-v1 --replicas=6
```

- **Pane B:** four new shop pods → `Pending → Running`
- **Pane C:** Karpenter places them on whichever node has room — a mix of D and E

```bash
kubectl get pods -o wide              # 6 shop + 3 recommender, mixed across nodes
```

### Step 8 — Prove load-aware routing  *(only if AGC is Programmed; otherwise skip)*

> *"Now AGC's turn. AGC is **not** a round-robin load balancer. The original two shop pods are already busy serving the spike. AGC tracks how busy each pod is and sends new connections to the **calm** pods first."*

```bash
bash scripts/06-load-test.sh           # 60 seconds; prints per-pod request distribution
```

While it runs:

> *"Watch the per-pod numbers when this finishes. The pods on the brand-new node should catch more new connections than the original two."*

When the table prints:

> **"See it? Cool pods grab the spike. Originally-busy pods get fewer new connections — so they don't tip over. Without load-aware routing, all six pods would split the spike equally and the warm ones would saturate first."**

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}\n" http://<AGC-IP>/; done
```

> *"Ten 200s in a row. Customers never saw a single 5xx."*

### ⏸  PAUSE #2b — Combined reveal

> **"Two completely different workloads. Two different machine families. The right machine for each. The spike never reached an over-saturated pod. The on-call engineer is still at dinner."**

---

# Act 3 — "After the sale, where does the cost go?"  *(14:30 – 16:30)*  — *back to Slide 12*

### Set the scene

> *"It's 11 p.m. Sale is over. In a traditional cluster, that big memory machine sits on the bill until morning — because nobody wants to be the engineer who deletes a node at midnight."*

### Step 9 — Scale down

```bash
kubectl scale deployment recommender --replicas=0
kubectl scale deployment shop-v1 --replicas=2
```

- **Pane B:** pods → `Terminating`
- **Pane C** *(your sticky narrator)*:

```
Disrupting          nodeclaim/...   via consolidation: replace
WaitingForDeletion  node/...
Deleted             node/...
```

(1–2 minutes. Fill the silence with the cost framing below.)

### ⏸  PAUSE #3 — The cost story, told like a person

Bring your energy down. This isn't a victory lap — it's relief.

> **"That E16s memory machine just got terminated. About **\$1 an hour** in East US 2. We had it for one hour during the sale.*
>
> *Here's what didn't happen tonight:*
>
> *— Nobody got paged.*
> *— Nobody approved a node-pool PR at 11 p.m.*
> *— Nobody wrote 'temporary' YAML that'd still be in production next quarter.*
> *— No Monday-morning ticket asking 'why did we burn a memory VM all weekend?'*
>
> *And the dollar math: roughly **\$8 saved on a single node, on a single workload, on a single night**. Multiply by every workload, every team, every cluster, every night. That's the budget you suddenly have for the things you actually want to build.*
>
> *Pain #3 — solved. The on-call engineer is asleep."**

**Click → Slide 13.**

---

# 🖼 SLIDE 13 — Demo in 3 acts  *(16:30 – 17:00)*

Use this slide to recap visually:

| Act | Pain | What we showed |
|---|---|---|
| 1 | "What size?" | NAP picked `D8als_v6 spot` from a 3-line config |
| 2 | "We need memory now!" | NAP added `E16s_v5` automatically; AGC routed traffic to calm pods |
| 3 | "Cost after the sale?" | NAP terminated the E16s; ~$8 saved per node per night |

**Click → Slide 14.**

---

# 🖼 SLIDE 14 — Takeaways + 5 NAP wins  *(17:00 – 18:00)*

Read the table top to bottom:

| # | Win | Outcome |
|---|---|---|
| 1 | No more guessing machine sizes | Less planning, fewer mistakes |
| 2 | No more stuck pods | Apps always get placed |
| 3 | Better cost efficiency 💰 | Pay only for what you use |
| 4 | Faster scaling 🚀 | Spikes handled smoothly |
| 5 | Less ops overhead | Less babysitting |

> *"NAP picks the machines. AGC picks the pods. You pick the menu — three lines of YAML — and walk away. Thank you."*

---

## 🧰 Cost-Lever Q&A appendix *(for live questions)*

| Lever | One-liner you can say |
|---|---|
| **Mixed autoscaling** | "One pool, many SKUs. NAP picks whichever fits the next pod best for the lowest price — even if that means a different SKU each time." |
| **HPA / VPA / KEDA + NAP** | "Pods scale first (HPA on CPU, VPA on memory, KEDA on queue depth); NAP follows by adding/removing nodes." |
| **NAP + Spot** | "Use Azure spare capacity at up to 70% off. Great for batch, dev/test, and large stateless compute. NAP handles eviction gracefully." |
| **Intel · AMD · ARM64** | "Mix architectures in one cluster. NAP picks the cheapest that fits — frequently AMD or ARM beats Intel." |
| **Taints · affinity · topology** | "When you want control — GPU-only nodes, zone spread — NAP respects all the standard Kubernetes hints." |

---

## 🧹 Reset between runs

```bash
bash scripts/99-cleanup.sh           # deletes deployments, gateway, nodepool
# wait ~2 min for NAP to remove the workload nodes
kubectl get nodes                    # back to 1 system node
```

---

## ✅ Presenter checklist (last 60 seconds before going live)

- [ ] Pane C is streaming Karpenter events
- [ ] Pane A shows nodes with the `SKU-NAME` and `CAPACITY-TYPE` columns
- [ ] Deck on **Slide 1**
- [ ] Browser tabs in this order: deck · script · GitHub · Azure Portal (MC_ RG)
- [ ] Read the SKU **as it appears on screen**, not from this script (today it's `D8als_v6 spot`)
- [ ] If AGC ADDRESS is blank after 3 min: use the fallback line in Step 2 and skip the load test
- [ ] PAUSE #1 stopwatched: **3 silent seconds** when SKU appears
