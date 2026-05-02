# Demo Script v3 — AGC + NAP, Told Like a Story

> **Who this is for:** anyone who has heard "Kubernetes" and "AKS" but has never run this demo. You can read this top to bottom and present it.
>
> **Two ideas you only need to remember:**
>
> 1. **NAP** = "AKS quietly creates the right machines for your apps." No more guessing VM sizes.
> 2. **AGC** = "An Azure load balancer that's smart about which pod gets the next request." It avoids dog-piling on busy pods.
>
> If you remember those two sentences, the rest of this script makes sense.

---

## 🎯 The opening story (read this aloud — slowly)

> *"Quick show of hands. Has anyone here ever:*
> *…been paged at 2am because pods were stuck and nobody on call knew which kind of VM to add?*
> *…paid for a cluster that ran all weekend because a job finished Friday at 5pm?*
> *…written 'temporary' YAML for a node pool — and that file is still in production three years later?*
>
> *Don't be shy. Most of us have done all three.*
>
> *Tonight you're going to watch a real AKS cluster handle a real flash sale — and not one human is going to do any of those three things. The cluster figures it out. We just sit here and watch."*

### The three pains, named

| # | Pain | What it feels like | What NAP does about it |
|---|---|---|---|
| **1** | **Unpredictable workloads** | Traffic spikes you can't plan for | Adds the right machines the moment pods need them |
| **2** | **Different apps need different machines** | One app wants CPU, the next wants memory, the next wants GPU | Picks a different VM **family** per app — automatically |
| **3** | **Idle nodes that bill all night** | "Temporary" pools that never go away | Removes nodes when nobody is using them |

### Meet **Contoso Retail**

> *"Picture a small online shop — `shop.contoso.com` — running on AKS. Tonight at 8pm, marketing is sending a flash-sale email to **2 million subscribers**. Traffic will jump 5× in minutes, then drain a few hours later.*
>
> *The on-call engineer just sat down to dinner. They will not open a laptop tonight.*
>
> *Contoso has three worries:*
>
> *1. **Sizing.** They want to launch a new recommendation engine that needs lots of memory. Their cluster today only has CPU-tuned machines. What machine should they add? — that's pain #2.*
> *2. **Speed.** When the spike hits, new pods must come up in under a minute, and the busy pods must not get hammered. — that's pain #1.*
> *3. **Cost.** After the sale ends at 11pm, the extra capacity must not sit on the bill all night. — that's pain #3.*
>
> *We're going to solve all three live. The on-call engineer is staying at dinner."*

---

## 🛠 What we're using (the "before we start" slide in plain English)

You don't have to memorize these. Just nod when each appears.

| Word | What it actually means |
|---|---|
| **AKS** | Azure's managed Kubernetes — the place pods run |
| **Pod** | One copy of your app running in a container |
| **Node** | The actual VM the pod runs on |
| **NodePool** | A group of nodes that share settings (size, OS, etc.) |
| **NAP** *(Node Auto Provisioning)* | An AKS add-on that creates the right node automatically when a pod needs one |
| **Karpenter** | The open-source brain inside NAP that decides "spin up a `Standard_D8...`" |
| **AGC** *(Application Gateway for Containers)* | An Azure load balancer that knows how busy each pod is, and sends new traffic to the calm ones |
| **Gateway / HTTPRoute** | Standard Kubernetes YAML — the modern replacement for the older `Ingress` |
| **Cilium** | The high-performance networking layer underneath the cluster |

---

## 📦 Pre-Demo Setup — "the cluster I already built earlier"

> *"Before this session, I ran one Azure CLI command to create the cluster. I'm not going to make you watch a 7-minute create. But I want you to **see the command** — because the magic isn't hidden in a portal click. It's right here on one screen."*

**Show this command full-screen. Read the four highlighted flags out loud.**

```bash
az aks create \
  -n nap-agc-demo  -g nap-agc-demo-rg  -l eastus2 \
  --network-plugin azure  --network-plugin-mode overlay \   # ← Azure CNI Overlay
  --network-dataplane cilium \                              # ← Cilium dataplane
  --node-provisioning-mode Auto \                           # ← turns NAP ON
  --enable-gateway-api \                                    # ← Gateway API CRDs
  --enable-application-load-balancer \                      # ← installs the AGC controller
  --enable-oidc-issuer  --enable-workload-identity \
  --node-count 1 \
  --generate-ssh-keys \
  -o table
```

**The four lines that matter (read them slowly):**

1. `--node-provisioning-mode Auto` — this is the one. NAP is now on for the cluster.
2. `--enable-application-load-balancer` — this installs the AGC controller as a managed add-on.
3. `--enable-gateway-api` — turns on the modern Kubernetes Gateway resources we'll write later.
4. `--network-plugin-mode overlay` + `--network-dataplane cilium` — fast, scalable pod networking. Required for NAP today.

> *"That's the whole cluster setup. One command. No portal clicks. No Helm charts to install for AGC. No separate Karpenter installation for NAP. Both are built into AKS."*

### Prove the cluster is already up and ready

**Run these three commands live so the audience sees real output (not a screenshot):**

```bash
# 1. Cluster exists and NAP is in Auto mode
az aks show -n nap-agc-demo -g nap-agc-demo-rg \
  --query "{name:name, k8s:kubernetesVersion, nap:nodeProvisioningProfile.mode, dataplane:networkProfile.networkDataplane}" \
  -o table
```

> *"There — `nap` is `Auto`, dataplane is `cilium`. Cluster is healthy."*

```bash
# 2. The AGC controller add-on is running
kubectl get pods -n kube-system | grep alb-controller
```

> *"Two `alb-controller` pods, both Running. That's the AGC controller — it's the bridge between Kubernetes Gateway YAML and the actual Azure load balancer."*

```bash
# 3. Gateway API is wired up
kubectl get gatewayclass azure-alb-external
```

> *"`Accepted: True` — the cluster knows how to handle Gateway resources. We're ready to demo."*

---

## 🪟 Terminal layout — the "always-on narrator"

Four panes (Windows Terminal: `Alt+Shift+=` vertical, `Alt+Shift+-` horizontal). **Critical: Pane C must stay visible the entire demo.** It's how the audience watches Karpenter "think out loud".

| Pane | Command | What it shows | Visibility |
|---|---|---|---|
| **D** *(driver, ~half the screen, **18pt+ font**)* | `cd ~/demo && source scripts/00-env.sh` | Where you type | always |
| **A** *(top-right)* | `kubectl get nodes -o wide -w` | Nodes appearing & disappearing | always |
| **B** *(mid-right)* | `kubectl get pods -o wide -w` | Pods going `Pending → Running` | always |
| **C** *(bottom-right — **never hide this**)* | `kubectl get events -A --field-selector source=karpenter --sort-by='.lastTimestamp' -w` | **Karpenter narrating itself, in real time** | **ALWAYS** |

> 📌 **Font check:** in Pane D, run `cat manifests/nodepool.yaml`. If you can't read it from across the room, bump the font size again. The single moment that makes this demo land is the audience seeing how little YAML drives all the magic — they have to be able to **read it**.

> **Open in your browser before recording:**
> - GitHub repo (`Vyshnavi-MSFT/nap-agc-demo`) — README has the architecture diagram
> - Azure Portal pinned to **`MC_nap-agc-demo-rg_nap-agc-demo_eastus2`** (the node resource group)
> - This script
> - The companion deck `docs/AGC-NAP-Beginner-Deck.pptx`

---

## Act 0 — Walk the architecture diagram (0:00 – 0:45)

Show `docs/architecture-nap-agc.png` full-screen. Point with your cursor as you talk:

> *"Two control loops on top of one AKS cluster. Read it left to right.*
>
> *— **Far left:** pods that want to run. Some land on existing capacity. Some can't fit anywhere — those are the **Pending** pods.*
>
> *— **Middle:** the K hexagon — that's **Karpenter**, the brain inside NAP. It looks at Pending pods and spins up a new node in the right size, in the right family, at the right price. No pre-bought capacity. No guessing.*
>
> *— **Top right:** the cluster after Karpenter has done its job. Pods bin-packed neatly. Idle nodes get reclaimed.*
>
> *— **Far right:** **Application Gateway for Containers** — AGC. It sees how busy each pod is, and sends new traffic to the cool pods (the green bar at 9%) instead of pounding the hot ones at 77%.*
>
> *NAP optimizes the **machines**. AGC optimizes the **traffic**. Together your AKS cluster runs itself. Let's prove it."*

Switch to terminal. **Pane C is already streaming** — the audience has been watching Karpenter quietly, even before you typed anything.

---

## Act 1 — "What VM should I pick?" (0:45 – 3:45)

### Open (0:45 – 1:15)

> *"Here's Contoso's cluster. One system node, no workload nodes, no node-pool plan. Today they're shipping the new shop service."*

```bash
kubectl get nodes
kubectl get nodepool                 # empty — no pool yet
```

### Step 1 — Apply the NodePool (1:15 – 2:15)  *(YAML on screen, BIG)*

> 🔍 **Stop. Bump your terminal font one more notch.** This is the moment that makes the whole demo land — *"all of this from one tiny config file."*

```bash
bat manifests/nodepool.yaml          # or: cat
```

**Read these 3 lines aloud — slowly. Let the rest of the YAML scroll past silently.**

```yaml
karpenter.azure.com/sku-family       In ["D", "E"]      # only general-purpose OR memory-optimized
karpenter.sh/capacity-type           In ["on-demand", "spot"]
consolidationPolicy: WhenEmptyOrUnderutilized                   # idle nodes get reclaimed
```

> *"Three lines. That's the entire NAP configuration.*
>
> *I'm not picking a VM size. I'm not picking a number of nodes. I'm giving Karpenter a **menu**: 'use the D family or the E family, mix on-demand and spot, and please clean up nodes when nobody needs them.'*
>
> *Everything else — what size, when to scale, when to remove — is Karpenter's call. And right now there are **zero workload nodes**. NAP only acts on real demand."*

```bash
kubectl apply -f manifests/nodepool.yaml
kubectl get nodepool
```

### Step 2 — Wire up the AGC frontend (2:15 – 3:00)

```bash
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/gateway.yaml
kubectl get gateway gateway-01
```

> *"Same idea on the traffic side. I write a Gateway and an HTTPRoute — **standard Kubernetes**, not Azure-specific YAML. The ALB Controller catches that and calls Azure for me to provision the actual load balancer."*

While you wait ~30 seconds for the `ADDRESS` to populate, **switch to the Azure Portal tab pinned to `MC_nap-agc-demo-rg_nap-agc-demo_eastus2` and hit refresh**. The new AGC frontend appears in the resource list.

> *"There it is — appearing in the portal. I never opened the portal. I never clicked Create. The Gateway YAML did it."*

Back to terminal:

```bash
az network alb list -g MC_nap-agc-demo-rg_nap-agc-demo_eastus2 -o table
```

### Step 3 — Deploy the baseline shop workload (3:00 – 3:25)

```bash
kubectl apply -f manifests/deployment-small.yaml      # shop-v1: 2 pods × 2 CPU
```

**Watch what happens — point at each pane:**

- **Pane B:** the two new pods → `Pending` *(they have nowhere to land — there are no workload nodes yet)*
- **Pane C:** Karpenter wakes up and starts narrating:

```
NominatePod        pod/shop-v1-...     → NodeClaim/default-...
NodeClaimCreated   nodeclaim/...
Launched           Launched instance: Standard_D8als_v6   (capacity-type: spot)
```

> 💡 **Heads-up for the live run:** the exact SKU and capacity type **change every demo** — that's the point. You might see `D8s_v5`, `D8ls_v5`, `D8als_v6`, `D4s_v5`, on-demand or spot. Read out **whatever appears** — the surprise *is* the story.

### ⏸  PAUSE #1 — "I never asked for that" (3:25 – 3:35)

**Stop typing. Hands off the keyboard. Don't talk for 3 seconds.**

`// 1… 2… 3… //`

Now point at the `Launched` line and read the SKU **out loud** exactly as it appears:

> **"`Standard_D8als_v6` — *spot*. I never typed that anywhere. Karpenter looked at my two pods, saw they want 2 CPUs and a few hundred megs of memory each, checked Azure's live price list, and picked the cheapest AMD machine in the D family that fits both of them — on **spot capacity**, which is up to 70% off retail.*
>
> *I asked for 'D or E family' and 'on-demand or spot'. NAP did the rest. Pain #1 — **'no more guessing machine sizes'** — solved. On screen. Live. Without me touching anything."**

> 🎤 **If it picks on-demand instead:** *"Today it picked on-demand because spot capacity for that SKU is tight in this region right now — and that's the point. Karpenter checks **live** capacity and price every time. I never have to think about it."*

### Step 4 — Confirm + plant the cost number (3:35 – 3:45)

```bash
kubectl get nodes -L karpenter.azure.com/sku-name,karpenter.sh/capacity-type
kubectl get pods -o wide
kubectl get gateway gateway-01           # ADDRESS now populated
curl http://<AGC-IP>/                    # nginx welcome page
```

You'll see something like:

```
NAME                STATUS   AGE   SKU-NAME            CAPACITY-TYPE
aks-default-7ct97   Ready    2m    Standard_D8als_v6   spot
```

> *"One D8-class node, **on spot** — pennies an hour instead of dollars. Hold that number; we'll come back to it when the sale ends."*

---

## Act 2 — "The marketing email just dropped" (3:45 – 7:15)

### Set the scene (3:45 – 4:05)

> *"It is 8pm. Two things happen at once. The recommendation engine launches — that's the new memory-heavy app — and shop traffic spikes 5×. The on-call engineer is on dessert."*

### Step 5 — Apply the recommendation engine (4:05 – 4:35)

```bash
kubectl apply -f manifests/deployment-large.yaml      # recommender: 3 pods × 4 CPU / 10 Gi RAM
```

**Set up the next reveal (10 seconds):**

> *"In a normal cluster, the platform team gets paged right now. They have to write a memory-optimized node pool, set min/max counts, push a PR, wait for the pipeline. Watch what happens here instead."*

- **Pane B:** new `recommender` pods → `Pending`
- **Pane C:** Karpenter creates a *brand new* NodeClaim. Watch for:

```
Launched     Launched instance: Standard_E16s_v5
Initialized  node/aks-default-...
```

### ⏸  PAUSE #2a — Different family, no extra config (4:35 – 4:50)

`// 1… 2… 3… //`

> **"`E16s_v5` — that's **memory-optimized**. A different VM family from the D8ls we got a minute ago.*
>
> *Karpenter saw a pod that asked for 10 gigs of memory and quietly switched families. The platform team did **not** write a second node pool. **One YAML file, two completely different machines, zero human in the loop.*** That's pain #2 — solved live."**

### Step 6 — Scale the shop spike (4:50 – 5:15)

```bash
kubectl scale deployment shop-v1 --replicas=6
```

- **Pane B:** four new shop pods → `Pending → Running`
- **Pane C:** Karpenter places them on whichever node has room — a mix of D and E

```bash
kubectl get pods -o wide              # 6 shop + 3 recommender, mixed across nodes
```

### Step 7 — Prove load-aware routing (5:15 – 6:30)

> *"Now AGC's turn. AGC is **not** a round-robin load balancer. The original two shop pods are already busy serving the spike. AGC tracks how busy each pod is and sends new connections to the **cool** pods first — the same green-bar pods you saw on the diagram."*

Run the load test (in a separate pane or in pane D):

```bash
bash scripts/06-load-test.sh           # 60 seconds of traffic; prints per-pod request distribution
```

While it runs, narrate what's coming:

> *"Watch the per-pod numbers when this finishes. The pods on the brand-new node should catch more new connections than the original two."*

When it prints:

> **"See it? Cool pods grab the spike. Originally-busy pods get fewer new connections — so they don't tip over.*
>
> *Without load-aware routing, all six pods would split the spike equally and the warm ones would saturate first. **Pain — 'apps stay healthy during a spike' — solved.**"**

### Step 8 — User-experience sanity check (6:30 – 7:00)

```bash
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code}\n" http://<AGC-IP>/; done
```

> *"Ten 200s in a row. Customers never saw a single 5xx. AGC's health checks added the new pods to rotation the moment they passed."*

### ⏸  PAUSE #2b — The combined reveal (7:00 – 7:15)

> **"Two completely different workloads. Two completely different machine families. The right machine for each. The spike never reached an over-saturated pod. And neither NAP nor AGC needed me to write a second config file. The on-call engineer is still at dinner."**

---

## Act 3 — "After the sale, where does the cost go?" (7:15 – 9:15)

### Set the scene (7:15 – 7:30)

> *"It's 11pm. Sale is over. In a traditional cluster, that big memory machine sits on the bill until someone notices in the morning — because nobody wants to be the engineer who deletes a node at midnight. Watch what NAP does instead."*

### Step 9 — Scale down (7:30 – 8:00)

```bash
kubectl scale deployment recommender --replicas=0
kubectl scale deployment shop-v1 --replicas=2
```

- **Pane B:** pods → `Terminating`
- **Pane C** *(still your sticky narrator)*:

```
Disrupting            nodeclaim/...   via consolidation: replace
WaitingForDeletion    node/...
Deleted               node/...
```

(1–2 minutes depending on `consolidateAfter`. Fill the silence with the cost framing below.)

### ⏸  PAUSE #3 — The cost story, told like a person (8:00 – 8:45)

Bring your energy down. This isn't a victory lap — it's relief.

> **"That E16s memory machine just got terminated. About **$1 an hour** in East US. We had it for one hour during the sale.*
>
> *Here's what didn't happen tonight:*
>
> *— Nobody got paged.*
> *— Nobody approved a node-pool PR at 11pm.*
> *— Nobody wrote 'temporary' YAML that'd still be in production next quarter.*
> *— No Monday-morning ticket on the finance side asking 'why did we burn a memory VM all weekend?'*
>
> *And the dollar math: roughly **$8 saved on a single node, on a single workload, on a single night**. Multiply by every workload, every team, every cluster, every night. That's the budget you suddenly have for the things you actually want to build.*
>
> *Pain #3 — solved. The on-call engineer is asleep."**

### Step 10 — Steady state (8:45 – 9:00)

```bash
kubectl get nodes                       # back to one D-family workload node
kubectl get pods -o wide                # bin-packed
curl http://<AGC-IP>/                   # AGC still works, no manual reconfig
```

### Closing — bring the diagram back (9:00 – 9:30)

Re-show `docs/architecture-nap-agc.png`.

> *"Same picture I started with. Now you've watched it happen on a real cluster.*
>
> *What we did **NOT** do tonight:*
> *— Did not pre-create node pools for two workload shapes.*
> *— Did not click a button in the Azure Portal to create the load balancer.*
> *— Did not write any HPA, CA, or scaling logic.*
> *— Did not manually drain or terminate any node.*
>
> *What we **did** do:*
> *— One NodePool YAML. Karpenter picked the SKUs.*
> *— One Gateway YAML. The ALB controller programmed AGC.*
> *— Deployed pods. The cluster did the rest.*
>
> *NAP for compute. AGC for traffic. Together, your AKS cluster becomes a self-managing platform — and your team gets their evenings back."*

---

## ✅ The 5 NAP wins (use as a closer slide or hand-out)

This is the "what did we just see, in five lines" recap. Read aloud at the end if there's a question pause.

| # | Win | Before NAP | With NAP | Outcome |
|---|---|---|---|---|
| **1** | **No more guessing machine sizes** | You guessed VM sizes and pre-created node pools | NAP picks the best VM for each workload automatically | ✅ Less planning, fewer mistakes |
| **2** | **No more "stuck" workloads** | If no node pool matched, the app waited forever | NAP creates a new node that fits exactly | ✅ Apps always get placed |
| **3** | **Better cost efficiency** 💰 | Over-provisioned nodes idle all night | Right-sized nodes, removed when not needed | ✅ Pay only for what you use *(better bin-packing + less waste)* |
| **4** | **Faster scaling** 🚀 | You discovered the spike from a Slack alert | NAP detects demand and spins up nodes itself | ✅ Spikes handled smoothly |
| **5** | **Less operational overhead** | Multiple pools, autoscaler tuning, capacity planning | One config, NAP runs the show | ✅ Less babysitting for the platform team |

---

## 💡 Cost levers — extra material for Q&A or a "deeper dive" follow-up

Drop these in if someone asks *"how do I push the cost lower?"* or *"can I mix Spot VMs?"* The live demo doesn't show them — they live here as ammunition.

### Mixed autoscaling — one node pool, many SKUs

> *"This is the part most people don't realize NAP can do. One logical node pool can pull from many VM sizes — even mixed families — and Karpenter picks the cheapest one that fits each batch of pods."*

- **Best-fit bin-packing** across many SKU sizes — no more "all my apps land on the same one big VM"
- **Distributes pods across SKUs**, finds the cheapest combination that fits everything
- **Replaces under-utilized nodes** when a smaller (cheaper) one would do the job
- **Saves time and removes node-pool sprawl** — one YAML instead of one-per-shape

> 🎤 Talking line: *"A customer with nine hand-tuned node pools — small-cpu, big-cpu, small-mem, big-mem, three GPU pools, two Spot pools — collapsed the lot into one NAP pool and saw 30% fewer idle vCPU-hours from better bin-packing alone."*

### Common scaling strategies that pair beautifully with NAP

**1. Pod-level autoscalers underneath NAP**

- **HPA** scales pods up and down based on CPU/RAM
- **VPA** right-sizes the pods themselves so they ask for what they actually need
- **KEDA** scales pods on **events** — Service Bus depth, Kafka lag, cron, queue length, etc.
- **NAP** then provisions the **nodes** underneath whatever the pod scalers ask for

> 🎤 *"Pod scalers handle the apps. NAP handles the floor under them. They don't fight each other — they layer."*

**2. NAP + Spot VMs — the cost lever everyone wants**

- **Spot VMs** = unused Azure capacity sold at up to **90% off** on-demand prices
- Trade-off: Azure can take them back with **~30 seconds notice** when it needs the capacity
- NAP automatically handles the eviction signal — drains the node, replaces it on-demand if the workload can't tolerate eviction
- Great for workloads that can handle restarts:
  - **Batch processing jobs**
  - **Dev / test environments**
  - **Large compute** (ML training, video encoding, simulations)
- Mix on-demand + Spot in **the same NodePool** — Karpenter picks per pod based on what each pod tolerates

```yaml
karpenter.sh/capacity-type   In ["on-demand", "spot"]
```

**3. Mix Intel · AMD · ARM64 in the same cluster**

- NAP supports x86 (Intel + AMD) and ARM64 (Azure Cobalt 100) **side-by-side**
- Karpenter looks at each container image's manifest and places the pod on an arch the image actually supports
- ARM64 typically delivers **30–40% better $/perf** for stateless services (web, API, cache)
- You don't need a second cluster, a second pipeline, or a second team

```yaml
kubernetes.io/arch   In ["amd64", "arm64"]
```

> 🎤 Combined headline: *"NAP + Spot + ARM, layered, regularly drops AKS compute spend by 40–60% with no migration project."*

### When you need to keep a tight grip — taints, affinity, topology

NAP respects every standard Kubernetes scheduling primitive. Pull these out if a customer says "but I need control":

- **Taints + tolerations** — "only pods that explicitly opt in can land on these nodes" *(GPU pools, Spot pools, isolated workloads)*
- **Node affinity** — "prefer / require pods to land on nodes with these labels" *(licensing pinning, locality)*
- **Pod anti-affinity** — "spread my replicas across nodes or zones" *(HA web tiers, stateful sets)*
- **Topology spread** — "balance pods evenly across zones / nodes / SKU families" *(multi-AZ resilience without manual placement)*

> 🎤 *"Same vocabulary as classic Kubernetes. NAP doesn't invent a new dialect — it just executes the existing one faster and without pre-allocated capacity."*

---

## 📋 Karpenter event cheat-sheet (for Pane C)

| Event | What it means | When you'll see it |
|---|---|---|
| `NominatePod` | Karpenter claimed a Pending pod | immediately |
| `NodeClaimCreated` | Decision made, spinning up VM | within ~5 sec |
| `Launched instance: Standard_<SKU>` | **The reveal** — VM type chosen | within ~30 sec |
| `Initialized` | Node is `Ready`, pods can bind | within ~60–90 sec |
| `Disrupting via consolidation: replace` | Under-utilized node being removed | after scale-down |
| `Deleted NodeClaim` | VM terminated, billing stops | once consolidation finishes |

---

## 🔁 Reset between takes

```bash
kubectl scale deployment recommender --replicas=0 --ignore-not-found
kubectl scale deployment shop-v1 --replicas=2
# wait ~3 minutes for Karpenter to consolidate, then:
kubectl get nodes                       # back to one D-family workload node
```

To restart from a fully empty cluster (workloads **and** AGC frontend):

```bash
kubectl delete -f manifests/deployment-large.yaml --ignore-not-found
kubectl delete -f manifests/deployment-small.yaml --ignore-not-found
kubectl delete -f manifests/gateway.yaml          --ignore-not-found
kubectl delete -f manifests/nginx-service.yaml    --ignore-not-found
# wait ~2 minutes for consolidation + AGC frontend teardown, then redeploy from Act 1 Step 1
```

---

## ⏱ Time-constrained variants

- **5 minutes** — drop Act 3 entirely. End right after Step 7. The cost story becomes one sentence in the close.
- **3 minutes** — Act 1 only. Apply NodePool → apply baseline → point at `Launched`. The "self-managing" point still lands.

---

## ✅ Presenter checklist (the night before)

- [ ] Pane D font **≥ 18pt** — confirmed by reading YAML from across the room
- [ ] Pane C running and visible the **whole** demo (not minimized, not behind another window)
- [ ] PAUSE #1 stopwatched: **3 silent seconds** when `Standard_D8...` appears
- [ ] Architecture diagram open in a browser tab for Act 0 and the close
- [ ] Companion deck (`docs/AGC-NAP-Beginner-Deck.pptx`) handy
- [ ] Three NAP scenarios + 5 NAP wins memorized so the opening lands without reading
- [ ] Azure Portal pinned to the **MC_** resource group
- [ ] Cluster pre-created (`bash scripts/02-create-aks.sh` already ran)
