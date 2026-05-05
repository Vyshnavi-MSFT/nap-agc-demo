# Lower Your AKS Bill Without Lowering Your Standards: How NAP + AGC Make Kubernetes Self-Managing

> **Subtitle:** Node Auto-Provisioning right-sizes your compute automatically and removes nodes the moment they go idle. Application Gateway for Containers routes traffic intelligently to the healthiest pods. The result is a measurably lower monthly bill and a platform team that spends less time tuning infrastructure.

**Author:** Vyshnavi Namani
**Audience:** Platform engineers, AKS architects, FinOps and cloud cost owners

---

## TL;DR

Running Kubernetes shouldn't mean guessing VM sizes, babysitting node pools, or paying for capacity you don't use. Two Azure Kubernetes Service (AKS) capabilities change that:

- **Node Auto-Provisioning (NAP)** dynamically creates the right-sized node for each workload — and removes nodes the moment they go idle. **NAP is where the cost savings live.** Customers eliminate idle buffer capacity, right-size every node to its workload, and tear down unused nodes automatically.
- **Application Gateway for Containers (AGC)** is a managed Layer-7 ingress that auto-discovers your pods, routes traffic to the healthiest endpoints, and scales itself. **AGC is where traffic is optimized.** It also brings WAF, mTLS, JWT authorization, and Gateway API support that customers consistently ask for.

**NAP saves cost. AGC optimizes traffic.** Together, they turn an AKS cluster into a platform that responds to what your workloads actually need — in real time, with no over-provisioning tax.

---

## Customer Engagement Log: What We Are Hearing in the Field

Before the technical deep dive, here is the customer signal that shaped this blog. Across a sustained set of internal and external engagements over the past two quarters — Tech Connect, AKS Accelerate, AGC Level-Up, Azure Networking Technical Champs, FY26 Azure Foundations Technical Insider, and customer-facing demo sessions — the same themes have surfaced repeatedly.

### Engagements at a glance

| Engagement | Date | Audience reached | Focus |
|---|---|---|---|
| Tech Connect — AI-Powered Networking | Feb 10–12 | 356 registered (largest, featured Theater Session) | Application delivery, Private DNS, ExpressRoute as foundations of private connectivity for AI workloads |
| AKS Accelerate — Navigating Ingress NGINX Retirement | Feb 9 | 250+ in person | Migration from Ingress NGINX to Gateway API + AGC |
| AGC Level-Up: Navigating Kubernetes Ingress with AGC (L300) | Jan 30 | 275+ | AGC positioning, hands-on demo, NGINX → AGC migration utility (5.0/5.0 average rating) |
| Azure Networking Technical Champs Skill-Up | Dec 11 | 35+ | Application Gateway + AI scenarios, roadmap |
| FY26 Azure Foundations — Technical Insider | Dec 10 | 65+ (capacity reached) | Application Gateway + AI scenarios, JWT authorization, mTLS passthrough, FIPS |
| L7 AGC Demo working session | May 4 | Internal field enablement | Demo refinement: WAF on AGC, ACNS pairing, multi-site routing, Cilium dataplane positioning |

Cumulative reach to date: **950+ attendees**, with satisfaction scores of 100% (Level-Up) and 92% (Tech Connect).

### What customers and the field are asking us to solve

These are the themes that came up in more than one engagement and were captured in working notes from the most recent demo sessions. Each one maps to a real product capability that NAP and AGC deliver — and each one is a CELA-safe, customer-facing way to position the value.

**1. "We need to retire Ingress NGINX with confidence."**
Customers facing NGINX retirement want a credible, supported migration path. AGC, with the Kubernetes Gateway API, has emerged as the primary Microsoft-native answer. The NGINX-to-AGC migration utility and concrete migration guidance turn this from a fear to a plan.

**2. "We need WAF for our container workloads."**
A consistent gap raised in field demos: Azure Container Network Services (ACNS) does not include a Web Application Firewall. Customers handling SQL injection (`?'1=1`) and other OWASP-class attacks need WAF in front of their pods. **AGC pairs naturally with ACNS** — AGC brings traffic in (with WAF, TLS, and L7 routing), ACNS handles allow/deny inside the cluster (DNS filtering, inbound and outbound traffic policy). This split-of-concerns is increasingly the recommended posture.

**3. "We need private end-to-end ingress."**
Tech Connect, AKS Accelerate, and the Networking Champs sessions all surfaced strong anticipation for **Private Ingress** and the **AGC AKS Add-On** experience. Customers in regulated industries cannot expose ingress publicly and want a fully private path from Front Door / private endpoint to pod.

**4. "We need authentication and authorization on the ingress tier."**
JWT authorization, mTLS passthrough, and FIPS support — announced at the FY26 Foundations session — are now actively requested in production architectures. AI-front-door scenarios in particular are driving demand for token-based authz at the gateway.

**5. "We need the cluster to right-size itself, not us."**
The single most common platform-team pain point: *"we don't know what VM SKU to put in the node pool"* and *"after the sale, the extra capacity sits idle on the bill all night."* This is exactly the gap NAP closes — picking the right SKU per workload and consolidating idle nodes automatically.

**6. "We need scale and limits we can plan against."**
Field teams consistently request clearer guidance on AGC scale boundaries, regional availability, and multi-cluster architectures. AGC's self-scaling design and the published limits documentation are how we answer this; the underlying point for customers is that they no longer pre-size the ingress tier for worst case.

**7. "Cilium and the new dataplane should be the default story."**
The Cilium eBPF dataplane delivers measurable performance and observability advantages, and is the dataplane NAP requires. Customers asking *"why Cilium?"* are asking the right question — and the answer is part performance, part security policy, part NAP eligibility.

> The remainder of this blog explains how the NAP and AGC capabilities behind these themes actually work, and where the cost savings come from. The customer signal above is what the technical detail below is designed to satisfy.

---

## The Problem (What Customers Tell Us)

If you operate Kubernetes today, these probably sound familiar:

> **"I don't know what VM sizes to pick."**
> Choose too small and pods stay `Pending`. Choose too large and you pay for headroom you never use.

> **"My workloads get stuck when nodes don't match."**
> A new pod needs more memory, or a GPU, or a different architecture — and there is no node pool that fits. The pod waits. The team scrambles.

> **"I'm wasting money on over-provisioned nodes."**
> Idle buffer capacity runs 24×7 "just in case." The bill arrives at the end of the month and nobody can justify it.

NAP removes all of that by **dynamically creating the right nodes based on what your workload needs — in real time.** When demand drops, NAP removes those nodes so you stop paying for them.

---

## Architecture at a Glance

The relationship is clean and complementary:

- **AGC** manages the **front door** — how external traffic enters the cluster and reaches the right pods, with WAF, TLS, and Gateway API-based routing.
- **NAP** manages the **floor plan** — what compute exists to run those pods, sized to actual demand.
- **ACNS** (optional pairing) handles **in-cluster network policy** — allow/deny, DNS filtering, observability — alongside AGC at the edge.

```
                    Internet
                       |
                       v
   +------------------------------------------+
   | Application Gateway for Containers (AGC) |  Azure-managed L7 ingress
   | Public FQDN, TLS, WAF, JWT, mTLS         |  Outside the cluster
   +------------------------------------------+
                       |
                       |  Routes to healthy pods,
                       |  prefers least-loaded endpoints
                       v
   +---------------- AKS cluster ---------------------------+
   | Gateway API:                                           |
   |   Gateway (gatewayClassName: azure-alb-external)       |
   |   HTTPRoute  ->  Service  ->  Pods                     |
   |                                                        |
   | ALB Controller (in-cluster add-on)                     |
   |   programs the AGC frontend via Azure ARM              |
   |                                                        |
   | Node Auto-Provisioning (Karpenter, AKS-managed)        |
   |   watches Pending pods -> reads CPU/memory/arch        |
   |   -> picks the right Azure VM SKU -> node joins        |
   |   -> consolidates underutilized nodes automatically    |
   |                                                        |
   | (Optional) ACNS for in-cluster allow/deny + DNS policy |
   |                                                        |
   | Existing node                NAP-provisioned node      |
   |   app pod  (busy)              app pod  (cool)         |
   |   app pod  (busy)              app pod  (cool)         |
   +--------------------------------------------------------+
```

When NAP launches a new node and pods become `Ready`, AGC's health probes pick them up automatically — **no AGC config change, no load balancer restart**. The system converges on its own.

---

## Five Reasons Customers Move to NAP + AGC

### 1. No more guessing VM sizes

| Before | With NAP |
|---|---|
| You pick VM sizes up front and create node pools per workload type. | NAP reads each pod's actual request (CPU, memory, GPU, architecture) and picks an Azure VM SKU that fits. |

**Outcome:** Less planning, fewer mistakes, and the right SKU for the job — every time. No more paying for a `Standard_D16s` when a `Standard_D4s` would do.

---

### 2. No more "stuck" workloads

| Before | With NAP |
|---|---|
| If no existing node pool matches the pod's requirements, the pod sits `Pending`. | NAP provisions a new node sized to fit and the pod is placed. |

**Outcome:** Apps get scheduled instead of waiting on a human to add capacity.

---

### 3. Better cost efficiency — the headline benefit

This is the result customers feel first, and it is the single biggest reason platform teams adopt NAP. Three structural changes drive the savings:

| Before | With NAP |
|---|---|
| Over-provisioned node pools sit idle most of the time. | NAP picks right-sized machines for the actual workload. |
| Idle nodes stay on the bill 24×7. | NAP **consolidates** underutilized nodes and removes them within minutes. |
| Spot capacity is hard to integrate. | NAP can mix on-demand and Spot via a single NodePool definition. |

**What that translates into on the invoice:**

- **No idle buffer tax.** Traditional clusters carry "just-in-case" headroom across multiple node pools, billed every hour of every day. NAP brings nodes up only when there is a pending pod, and removes them the moment that pod goes away.
- **Right-sized VMs, not pool-sized VMs.** A node pool forces every workload onto the same SKU. NAP picks the cheapest SKU that fits each workload's real CPU, memory, and architecture requirements, so you stop paying for unused vCPU and unused memory on every node.
- **Aggressive consolidation.** When utilization drops, Karpenter's consolidation logic moves pods together and terminates the now-empty nodes. Idle compute literally disappears from the bill.
- **Spot, the easy way.** Adding a second NodePool with `capacityType: Spot` lets non-critical workloads (batch, dev, CI) run on deeply discounted Azure capacity without any per-pool management overhead.
- **No L7 ingress idle tax.** AGC autoscales itself, so you also stop paying for an over-sized fixed ingress tier 24×7.

**Outcome:** You pay only for the compute you actually use. Better bin-packing, less waste, and a measurably smaller monthly bill.

> See the [Node Auto-Provisioning overview](https://learn.microsoft.com/azure/aks/node-autoprovision) for the consolidation and SKU-selection behavior in detail. Actual savings vary by workload; customers should validate against their own usage patterns.

---

### 4. Faster scaling for spikes

| Before | With NAP |
|---|---|
| Scaling depends on pre-defined node pool min/max ranges. | NAP detects pending demand and provisions nodes automatically. |

**Outcome:** Traffic surges (flash sales, marketing blasts, end-of-quarter loads) are absorbed without manual intervention — and without keeping idle nodes around between events.

---

### 5. Less operational overhead

| Before | With NAP + AGC |
|---|---|
| Multiple node pools to manage. | A single `NodePool` CRD describes intent; NAP handles the rest. |
| Cluster autoscaler tuning per pool. | NAP handles scale up and consolidation. |
| Manual capacity planning meetings. | Capacity follows workloads. |
| Hand-rolled Ingress YAML and load balancer rules. | AGC is managed and self-scaling; routing is declared via the Kubernetes Gateway API. |

**Outcome:** Your platform team spends less time babysitting infrastructure — and that engineering time is itself a recurring cost line you reclaim.

---

## Where the Cost Savings Come From

NAP is engineered to reduce spend along five measurable cost drivers. This is the section to bring to a FinOps or finance review.

| Cost driver | Traditional approach | With NAP + AGC | Why it lowers the bill |
|---|---|---|---|
| **Idle buffer capacity** | Multiple pools × min nodes, running 24×7. | Nodes appear on demand only. | You stop paying for hours when no workload needed the capacity. |
| **VM right-sizing** | One SKU per pool, usually oversized. | Per-workload SKU selection from a wide family. | Every node closely matches the workload's real CPU and memory request. |
| **Spot exploitation** | Manual setup per pool. | `capacityType: Spot` declared once. | Non-critical workloads run on heavily discounted Azure capacity. |
| **Idle teardown** | Manual or autoscaler tuning. | Automatic consolidation when demand drops. | Nodes leave the bill within minutes of going idle, not hours. |
| **Ingress tier sizing** | Fixed L7 tier paid 24×7. | AGC autoscales independently. | The ingress tier costs scale with traffic, not with your worst-case projection. |

**Best-fit cost-savings scenarios:**

- **Batch, ML, and GPU jobs** — VMs exist only while the job runs. GPU SKUs are expensive to leave idle; NAP guarantees they do not sit around between jobs.
- **Dev and test environments** — Spot capacity for non-critical workloads, with NAP managing the lifecycle automatically.
- **Bursty web traffic** — capacity tracks demand instead of sitting idle. Off-peak hours stop costing what peak hours cost.
- **Mixed workloads on a single cluster** — many SKU shapes from one cluster, with no node pool sprawl to maintain.
- **Multi-tenant platforms** — per-tenant or per-team workloads get exactly the compute they need, charged back accurately.

> Actual savings vary by workload mix, region, and reservation posture. Customers should validate against their own usage patterns before generalizing any specific savings number.

---

## And What About Traffic? That Is AGC.

While NAP is busy keeping your compute right-sized and right-priced, **AGC** handles the front door. The capabilities below are the ones the field and customers have specifically called out as required for production:

- **Built on the Kubernetes Gateway API** — the modern, vendor-neutral successor to Ingress, and the migration target for customers retiring Ingress NGINX.
- **Self-managed and self-scaling** — you do not run or size the ingress tier; Azure does. The ingress tier no longer has a fixed 24×7 cost line.
- **Auto-discovers pods** — as NAP brings nodes and pods online, AGC's health probes include them automatically.
- **Load-aware routing** — new connections prefer the least-loaded healthy pod, so newly-provisioned cool pods absorb spikes instead of overwhelmed ones.
- **Web Application Firewall (WAF)** — OWASP rule sets that block SQL injection, cross-site scripting, and other Layer-7 attacks at the edge. This is a capability ACNS does not provide, which is why the AGC + ACNS pairing is becoming a recommended posture.
- **TLS, mTLS, and JWT authorization** — including mTLS passthrough and JWT authorization at the ingress, a frequent ask for AI-fronted scenarios.
- **Production protocol coverage** — gRPC, WebSocket, weighted traffic shifting, header- and path-based routing, multi-site hosting.

A minimal AGC route looks like this:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      backendRefs: [{ name: api-service, port: 80 }]
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: frontend-service, port: 80 }]
```

> See the [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview).

---

## A Realistic Scenario: A Retailer's Flash Sale

A retail platform runs a multi-service application — `frontend`, `api`, `checkout` — fronted by AGC.

1. **Marketing sends an email blast.** Traffic spikes. HPA scales `frontend` and `api` pods.
2. **New pods land `Pending`** — existing nodes are saturated.
3. **NAP responds:** picks a CPU-optimized SKU for the lightweight services and a memory-optimized SKU for `checkout`. Nodes join the cluster within roughly a minute.
4. **AGC auto-includes the new pods** in its backend pool, with WAF still enforcing the OWASP rule set on inbound traffic, and prefers the cool pods for new connections.
5. **The sale ends.** Pods scale down. NAP consolidates the now-idle nodes and removes them. The bill stops accruing for that capacity.

Result: the platform absorbed a spike and cleaned itself up without a human in the loop, with WAF and TLS continuously enforced at the edge.

---

## What Customers Should Know Before Adopting

NAP and AGC are powerful, but they are not magic. Plan around these realities:

- **NAP requires Azure CNI Overlay with the Cilium dataplane.** This is also what unlocks the performance and policy story customers have been asking about.
- **NAP and the cluster autoscaler cannot coexist** on the same cluster — plan a green/blue cluster cut-over rather than an in-place flip.
- **No Windows node pools, no IPv6, no custom kubelet config** with NAP today.
- **Managed identity is required** (no service principals).
- **Consolidation is configurable.** For latency-sensitive production workloads, lengthen `consolidateAfter` and add disruption budgets so you control churn windows.
- **Treat AGC's `Gateway` as a platform contract.** Application teams own `HTTPRoute`s; the platform team owns `Gateway`s. This split-of-concerns scales well.
- **Pair AGC with ACNS for in-cluster policy.** AGC handles WAF, TLS, and L7 routing at the edge; ACNS handles allow/deny, DNS filtering, and observability inside the cluster.

> Check the current limits in the [NAP documentation](https://learn.microsoft.com/azure/aks/node-autoprovision) before planning a migration.

---

## Getting Started

```bash
# 1. Create AKS with NAP enabled
az aks create -n my-cluster -g my-rg \
  --network-plugin azure --network-plugin-mode overlay \
  --network-dataplane cilium \
  --node-provisioning-mode Auto

# 2. Enable the AGC ALB Controller add-on
az aks addon enable -n my-cluster -g my-rg --addon application-load-balancer

# 3. Apply your NodePool, Gateway, HTTPRoute, and Deployment
kubectl apply -f nodepool.yaml -f gateway.yaml -f app.yaml
```

That is it. The cluster handles the rest.

---

## Summary

- **NAP** = the right compute, the right size, at the right time — automatically. **This is where you save money — on idle capacity, on oversized VMs, and on the engineering time spent tuning autoscalers.**
- **AGC** = the right routing, the right health management, at the right scale — automatically. **This is where your traffic gets optimized, with WAF, TLS, mTLS, and JWT at the edge, and no fixed ingress tier paid 24×7.**
- **Together** = a self-managing AKS platform that lets your team stop tuning infrastructure and start shipping products — at a materially lower run-rate cost.

If you have ever said *"I don't know what VM size to pick,"* *"my workloads get stuck,"* or *"I'm wasting money on idle nodes,"* NAP and AGC are designed for you.

---

## References

- [Node Auto-Provisioning overview (AKS docs)](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)
- [AGC quickstart with ALB Controller](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller)
- [Gateway API on AKS](https://learn.microsoft.com/azure/application-gateway/for-containers/how-to-traffic-splitting-gateway-api)
- [Azure CNI Overlay with Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Karpenter (open source, the engine NAP is built on)](https://karpenter.sh)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io)
