# Stop Guessing, Start Shipping: How NAP + AGC Make AKS Self-Managing

> **Subtitle:** Node Auto-Provisioning picks the right compute automatically. Application Gateway for Containers routes traffic intelligently. Together, they help you spend less time tuning infrastructure — and less money on idle capacity.

**Author:** Vyshnavi Namani
**Audience:** Platform engineers, AKS architects, FinOps and cloud cost owners

---

## TL;DR

Running Kubernetes shouldn't mean guessing VM sizes, babysitting node pools, or paying for capacity you don't use. Two Azure Kubernetes Service (AKS) capabilities change that:

- **Node Auto-Provisioning (NAP)** dynamically creates the right-sized node for each workload — and removes nodes when they're no longer needed. **NAP is where the cost savings live.**
- **Application Gateway for Containers (AGC)** is a managed Layer-7 ingress that auto-discovers your pods, routes traffic to the healthiest endpoints, and scales itself. **AGC is where the traffic is optimized.**

**NAP saves cost. AGC optimizes traffic.** Together, they turn an AKS cluster into a platform that responds to what your workloads actually need — in real time.

---

## The Problem (What Customers Tell Us)

If you operate Kubernetes today, these probably sound familiar:

> **"I don't know what VM sizes to pick."**
> Choose too small and pods stay `Pending`. Choose too large and you pay for headroom you never use.

> **"My workloads get stuck when nodes don't match."**
> A new pod needs more memory, or a GPU, or a different architecture — and there's no node pool that fits. The pod waits. The team scrambles.

> **"I'm wasting money on over-provisioned nodes."**
> Idle buffer capacity runs 24×7 "just in case." The bill arrives at the end of the month and nobody can justify it.

NAP removes all of that by **dynamically creating the right nodes based on what your workload needs — in real time.** And when demand drops, NAP removes those nodes so you stop paying for them.

---

## Architecture at a Glance

The relationship is clean and complementary:

- **AGC** manages the **front door** — how external traffic enters the cluster and reaches the right pods.
- **NAP** manages the **floor plan** — what compute exists to run those pods, sized to actual demand.

```
                    Internet
                       │
                       ▼
   ┌─────────────────────────────────────────┐
   │ Application Gateway for Containers      │  Azure-managed L7 ingress
   │ (AGC frontend, public FQDN)             │  Outside the cluster
   └─────────────────────────────────────────┘
                       │
                       │  Routes to healthy pods,
                       │  prefers least-loaded endpoints
                       ▼
   ┌──────────────── AKS cluster ───────────────────────────┐
   │ Gateway API:                                           │
   │   Gateway (gatewayClassName: azure-alb-external)       │
   │   └─ HTTPRoute  →  Service  →  Pods                    │
   │                                                        │
   │ ALB Controller (in-cluster add-on)                     │
   │   programs the AGC frontend via Azure ARM              │
   │                                                        │
   │ Node Auto-Provisioning (Karpenter, AKS-managed)        │
   │   watches Pending pods → reads CPU/memory/arch         │
   │   → picks the right Azure VM SKU → node joins          │
   │   → consolidates underutilized nodes automatically     │
   │                                                        │
   │ Existing node                NAP-provisioned node      │
   │   app pod  (busy)              app pod  (cool)         │
   │   app pod  (busy)              app pod  (cool)         │
   └────────────────────────────────────────────────────────┘
```

When NAP launches a new node and pods become `Ready`, AGC's health probes pick them up automatically — **no AGC config change, no load balancer restart**. The system converges on its own.

---

## Five Reasons Customers Move to NAP + AGC

### 1. No more guessing VM sizes

| Before | With NAP |
|---|---|
| You pick VM sizes up front and create node pools per workload type. | NAP reads each pod's actual request (CPU, memory, GPU, architecture) and picks an Azure VM SKU that fits. |

✅ **Outcome:** Less planning, fewer mistakes, and the right SKU for the job — every time.

---

### 2. No more "stuck" workloads

| Before | With NAP |
|---|---|
| If no existing node pool matches the pod's requirements, the pod sits `Pending`. | NAP provisions a new node sized to fit and the pod is placed. |

✅ **Outcome:** Apps get scheduled instead of waiting on a human to add capacity.

---

### 3. Better cost efficiency 💰

This is the headline benefit — and the one most customers feel first.

| Before | With NAP |
|---|---|
| Over-provisioned node pools sit idle most of the time. | NAP picks right-sized machines for the actual workload. |
| Idle nodes stay on the bill 24×7. | NAP **consolidates** underutilized nodes and removes them. |
| Spot capacity is hard to integrate. | NAP can mix on-demand and Spot via the same NodePool definition. |

✅ **Outcome:** You pay only for the compute you actually use — better bin-packing, less waste, and a smaller monthly bill.

> 📚 See [Node Auto-Provisioning overview](https://learn.microsoft.com/azure/aks/node-autoprovision) for the consolidation and SKU-selection behavior in detail.

---

### 4. Faster scaling for spikes 🚀

| Before | With NAP |
|---|---|
| Scaling depends on pre-defined node pool min/max ranges. | NAP detects pending demand and provisions nodes automatically. |

✅ **Outcome:** Traffic surges (flash sales, marketing blasts, end-of-quarter loads) are absorbed without manual intervention.

---

### 5. Less operational overhead

| Before | With NAP + AGC |
|---|---|
| Multiple node pools to manage. | A single `NodePool` CRD describes intent; NAP handles the rest. |
| Cluster autoscaler tuning per pool. | NAP handles scale up and consolidation. |
| Manual capacity planning meetings. | Capacity follows workloads. |
| Hand-rolled Ingress YAML and load balancer rules. | AGC is managed and self-scaling; routing is declared via the Kubernetes Gateway API. |

✅ **Outcome:** Your platform team spends less time babysitting infrastructure and more time enabling product teams.

---

## Where the Cost Savings Come From

NAP is designed to reduce spend in four ways customers can measure:

| Cost driver | Traditional approach | With NAP |
|---|---|---|
| **Idle buffer capacity** | Multiple pools × min nodes, running 24×7. | Nodes appear on demand, not "just in case." |
| **VM right-sizing** | One SKU per pool — usually oversized. | Per-workload SKU selection from a wide family. |
| **Spot exploitation** | Manual setup per pool. | `capacityType: Spot` declared once in the NodePool. |
| **Idle teardown** | Manual or autoscaler tuning. | Automatic consolidation when demand drops. |

**Best-fit cost-savings scenarios:**

- **Batch / ML / GPU jobs** — VMs exist only while the job runs.
- **Dev and test environments** — Spot capacity for non-critical workloads.
- **Bursty web traffic** — capacity tracks demand instead of sitting idle.
- **Mixed workloads on a single cluster** — many SKU shapes without node pool sprawl.

> Actual savings vary by workload mix and region. Customers should validate against their own usage patterns before generalizing.

---

## And What About Traffic? That's AGC.

While NAP is busy keeping your compute right-sized and right-priced, **AGC** handles the front door:

- **Built on the Kubernetes Gateway API** — the modern, vendor-neutral successor to Ingress.
- **Self-managed and self-scaling** — you don't run or size the ingress tier; Azure does.
- **Auto-discovers pods** — as NAP brings nodes and pods online, AGC's health probes include them automatically.
- **Load-aware routing** — new connections prefer the least-loaded healthy pod, so newly-provisioned cool pods absorb spikes instead of overwhelmed ones.
- **Production features included** — TLS termination, weighted traffic shifting, header- and path-based routing, gRPC, WebSocket, mTLS, and Web Application Firewall.

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

> 📚 See [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview).

---

## A Realistic Scenario: A Retailer's Flash Sale

A retail platform runs a multi-service application — `frontend`, `api`, `checkout` — fronted by AGC.

1. **Marketing sends an email blast.** Traffic spikes. HPA scales `frontend` and `api` pods.
2. **New pods land `Pending`** — existing nodes are saturated.
3. **NAP responds:** picks a CPU-optimized SKU for the lightweight services and a memory-optimized SKU for `checkout`. Nodes join the cluster within roughly a minute.
4. **AGC auto-includes the new pods** in its backend pool — no routing change required — and prefers the cool pods for new connections.
5. **The sale ends.** Pods scale down. NAP consolidates the now-idle nodes and removes them. The bill stops accruing for that capacity.

Result: the platform absorbed a spike and cleaned itself up — without a human in the loop.

---

## What Customers Should Know Before Adopting

NAP and AGC are powerful, but they're not magic. Plan around these realities:

- **NAP requires Azure CNI Overlay with the Cilium dataplane.**
- **NAP and the cluster autoscaler can't coexist** on the same cluster — plan a green/blue cluster cut-over rather than an in-place flip.
- **No Windows node pools, no IPv6, no custom kubelet config** with NAP today.
- **Managed identity is required** (no service principals).
- **Consolidation is configurable.** For latency-sensitive production workloads, lengthen `consolidateAfter` and add disruption budgets so you control churn windows.
- **Treat AGC's `Gateway` as a platform contract.** Application teams own `HTTPRoute`s; the platform team owns `Gateway`s. This split-of-concerns scales well.

> 📚 Check the current limits in the [NAP documentation](https://learn.microsoft.com/azure/aks/node-autoprovision) before planning a migration.

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

That's it. The cluster handles the rest.

---

## Summary

- **NAP** = the right compute, the right size, at the right time — automatically. **This is where you save money.**
- **AGC** = the right routing, the right health management, at the right scale — automatically. **This is where your traffic gets optimized.**
- **Together** = a self-managing AKS platform that lets your team stop tuning infrastructure and start shipping products — at a lower cost.

If you've ever said *"I don't know what VM size to pick,"* *"my workloads get stuck,"* or *"I'm wasting money on idle nodes,"* NAP + AGC are designed for you.

---

## References

- [Node Auto-Provisioning overview (AKS docs)](https://learn.microsoft.com/azure/aks/node-autoprovision)
- [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)
- [AGC quickstart with ALB Controller](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller)
- [Gateway API on AKS](https://learn.microsoft.com/azure/application-gateway/for-containers/how-to-traffic-splitting-gateway-api)
- [Azure CNI Overlay with Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Karpenter (open source, the engine NAP is built on)](https://karpenter.sh)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io)
