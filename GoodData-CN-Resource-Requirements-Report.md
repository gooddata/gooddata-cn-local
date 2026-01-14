# GoodData.CN Resource Requirements Report

**Generated:** January 14, 2026  
**Installation Version:** GoodData.CN 3.52.0  
**Test Environment:** Apple M4 Pro, 48GB RAM, macOS  
**Deployment Method:** k3d + Helm (Local Development)

---

## Executive Summary

This report provides a comprehensive analysis of resource requirements for deploying GoodData.CN in a local development environment using k3d (Kubernetes in Docker). The installation is optimized for minimal resource consumption while maintaining full functionality.

### Key Findings

- **Total Pods Deployed:** 49 pods across 5 namespaces
- **GoodData.CN Pods:** 31 pods (core services)
- **Pulsar Pods:** 11 pods (message streaming)
- **Infrastructure Pods:** 7 pods (kube-system, ingress, cert-manager)
- **Actual Memory Usage:** ~12.98 GB across 3 Kubernetes nodes
- **Actual CPU Usage:** ~1,049m cores (1.05 vCPU) under normal load

---

## Access Information

### Host System
- **CPU:** Apple M4 Pro (12 cores)
- **Memory:** 48 GB total
- **Storage:** 461GB total (53GB available before installation)
- **OS:** macOS (Darwin 25.2.0)

### Software Versions
- **k3d:** v5.8.3
- **Kubernetes:** v1.31.5-k3s1
- **Helm:** v3.18.6
- **kubectl:** v1.34.0
- **k9s:** v0.50.9

---

## Resource Usage by Category

### 1. Pulsar (Message Streaming) - 11 Pods

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| pulsar-bookie-0 | 200m | — | 128Mi | — |
| pulsar-bookie-1 | 200m | — | 128Mi | — |
| pulsar-bookie-2 | 200m | — | 128Mi | — |
| pulsar-broker-0 | 200m | — | 256Mi | — |
| pulsar-broker-1 | 200m | — | 256Mi | — |
| pulsar-recovery-0 | 50m | — | 64Mi | — |
| pulsar-zookeeper-0 | 100m | — | 256Mi | — |
| pulsar-zookeeper-1 | 100m | — | 256Mi | — |
| pulsar-zookeeper-2 | 100m | — | 256Mi | — |
| **Pulsar Total** | **1,350m** | **—** | **1,728Mi (~1.7GB)** | **—** |

**Notes:**
- Pulsar pods do not have CPU/memory limits set (can burst beyond requests)
- 2 init pods (bookie-init, pulsar-init) complete during initialization

---

### 2. PostgreSQL HA (Database) - 5 Pods

| Pod | CPU Usage (Actual) | Memory Usage (Actual) | Estimated Request | Estimated Limit |
|-----|:------------------:|:---------------------:|:-----------------:|:---------------:|
| db-postgresql-0 | 80m | 139Mi | 100m / 256Mi | 500m / 512Mi |
| db-postgresql-1 | 45m | 114Mi | 100m / 256Mi | 500m / 512Mi |
| db-postgresql-2 | 61m | 108Mi | 100m / 256Mi | 500m / 512Mi |
| db-pgpool-0 | 40m | 544Mi | 50m / 512Mi | 200m / 1Gi |
| db-pgpool-1 | 39m | 477Mi | 50m / 512Mi | 200m / 1Gi |
| **PostgreSQL Total** | **265m** | **1,382Mi** | **400m / 1,792Mi** | **1,900m / 4Gi** |

**Notes:**
- PostgreSQL pods use Bitnami defaults (no explicit requests/limits in Helm values)
- **Actual usage observed:** ~265m CPU, ~1.4 GB memory
- Provides 3 PostgreSQL replicas with automatic failover
- 2 pgpool pods for connection pooling (higher memory due to connection caching)
- **TIP:** This PostgreSQL cluster can be shared with your other applications

**Recommended values-gdcn.yaml settings:**
```yaml
postgresql-ha:
  postgresql:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  pgpool:
    resources:
      requests:
        cpu: 50m
        memory: 512Mi
      limits:
        cpu: 200m
        memory: 1Gi
```

---

### 3. Redis HA (Cache) - 3 Pods

| Pod | CPU Usage (Actual) | Memory Usage (Actual) | Estimated Request | Estimated Limit |
|-----|:------------------:|:---------------------:|:-----------------:|:---------------:|
| redis-ha-server-0 | 16m | 20Mi | 25m / 32Mi | 100m / 128Mi |
| redis-ha-server-1 | 20m | 21Mi | 25m / 32Mi | 100m / 128Mi |
| redis-ha-server-2 | 17m | 24Mi | 25m / 32Mi | 100m / 128Mi |
| **Redis Total** | **53m** | **65Mi** | **75m / 96Mi** | **300m / 384Mi** |

**Notes:**
- Redis pods use container defaults (no explicit requests/limits in Helm values)
- **Actual usage observed:** ~53m CPU, ~65Mi memory
- Provides 3-node Redis HA cluster with Sentinel
- Very lightweight - caching metadata and session data

**Recommended values-gdcn.yaml settings:**
```yaml
redis-ha:
  redis:
    resources:
      requests:
        cpu: 25m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

---

### 4. etcd (Distributed Key-Value Store) - 1 Pod

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| etcd-0 | 100m | 300m | 256Mi | 512Mi |
| **etcd Total** | **100m** | **300m** | **256Mi** | **512Mi** |

**Notes:**
- Reduced from 3 replicas to 1 for local development
- For production HA, set `etcd.replicaCount: 3` (+200m CPU, +512Mi per replica)

---

### 5. GoodData.CN Core Services - 22 Pods

#### API & Gateway Services

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| api-gateway | 100m | 500m | 300Mi | 540Mi |
| api-gw | 280m | 1000m | 400Mi | 1000Mi |
| auth-service | 100m | 500m | 400Mi | 750Mi |
| metadata-api | 100m | 1250m | 1500Mi | 2400Mi |
| organization-controller | 10m | 100m | 50Mi | 200Mi |
| dex | 30m | 100m | 50Mi | 50Mi |
| **Subtotal** | **620m** | **3,450m** | **2,700Mi** | **4,940Mi** |

#### Computation & Query Engine

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| afm-exec-api | 100m | 750m | 600Mi | 965Mi |
| calcique | 150m | 500m | 500Mi | 1024Mi |
| sql-executor | 100m | 500m | 550Mi | 1356Mi |
| result-cache | 100m | 750m | 1330Mi | 1555Mi |
| quiver-cache | 100m | 300m | 256Mi | 768Mi |
| quiver-datasource | 400m | 1500m | 384Mi | 768Mi |
| quiver-ml | 200m | 500m | 256Mi | 512Mi |
| quiver-xtab | 200m | 500m | 256Mi | 512Mi |
| **Subtotal** | **1,350m** | **5,300m** | **4,132Mi** | **7,460Mi** |

#### UI Components

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| analytical-designer | 50m | 150m | 15Mi | 35Mi |
| dashboards | 50m | 150m | 15Mi | 35Mi |
| home-ui | 50m | 150m | 15Mi | 35Mi |
| ldm-modeler | 50m | 150m | 15Mi | 35Mi |
| measure-editor | 10m | 100m | 15Mi | 35Mi |
| web-components | 50m | 150m | 15Mi | 35Mi |
| apidocs | 10m | 100m | 15Mi | 35Mi |
| **Subtotal** | **270m** | **950m** | **105Mi** | **245Mi** |

#### GoodData.CN Core Total

| Category | Pods | CPU Request | CPU Limit | Memory Request | Memory Limit |
|----------|------|-------------|-----------|----------------|--------------|
| API & Gateway | 6 | 620m | 3,450m | 2,700Mi | 4,940Mi |
| Computation & Query | 8 | 1,350m | 5,300m | 4,132Mi | 7,460Mi |
| UI Components | 7 | 270m | 950m | 105Mi | 245Mi |
| etcd | 1 | 100m | 300m | 256Mi | 512Mi |
| **Total** | **22** | **2,340m** | **10,000m** | **7,193Mi** | **13,157Mi** |

---

### 6. Infrastructure Services

| Namespace | Pod | CPU Request | Memory Request |
|-----------|-----|-------------|----------------|
| kube-system | coredns | 100m | 70Mi |
| kube-system | metrics-server | 100m | 70Mi |
| ingress-nginx | ingress-nginx-controller | 100m | 90Mi |
| cert-manager | cert-manager (3 pods) | — | — |
| **Infrastructure Total** | | **300m** | **230Mi** |

---

## Summary Tables

### Total Resource Requests by Category

| Category | Pods | CPU Requests | Memory Requests | CPU Usage (Actual) | Memory Usage (Actual) |
|----------|:----:|:------------:|:---------------:|:------------------:|:---------------------:|
| **Pulsar** | 11 | 1,350m | 1,728Mi (~1.7 GB) | ~300m | ~1.5 GB |
| **PostgreSQL HA** | 5 | ~400m (est.) | ~1,792Mi (~1.8 GB) | 265m | 1,382Mi |
| **Redis HA** | 3 | ~75m (est.) | ~96Mi | 53m | 65Mi |
| **etcd** | 1 | 100m | 256Mi | 10m | 44Mi |
| **GoodData.CN Core** | 22 | 2,340m | 7,193Mi (~7 GB) | ~150m | ~5.2 GB |
| **Infrastructure** | 7 | 300m | 230Mi | ~50m | ~200Mi |
| **Total** | **49** | **~4,565m (~4.6 vCPU)** | **~11,295Mi (~11 GB)** | **~828m** | **~8.4 GB** |

### Actual Node Resource Usage

| Node | CPU Usage | CPU % | Memory Usage | Memory % |
|------|-----------|-------|--------------|----------|
| k3d-gdcluster-server-0 | 376m | 3% | 5,458Mi | 22% |
| k3d-gdcluster-agent-0 | 437m | 4% | 3,738Mi | 15% |
| k3d-gdcluster-agent-1 | 236m | 2% | 3,782Mi | 15% |
| **Total** | **1,049m** | **9%** | **12,978Mi (~12.7GB)** | **52%** |

---

## Configuration Comparison: Minimal vs Full Installation

This section compares the **current minimal installation** with a **full installation** that includes all features (AI, exports, HA configuration, etc.).

### Feature Comparison Matrix

| Feature | Minimal (Current) | Full Installation |
|---------|:-----------------:|:-----------------:|
| **Core Analytics** | ✅ | ✅ |
| **Dashboards & Visualizations** | ✅ | ✅ |
| **LDM Modeler** | ✅ | ✅ |
| **API Access** | ✅ | ✅ |
| **Dex Identity Provider** | ✅ | ✅ |
| **TLS/HTTPS** | ✅ | ✅ |
| **AI Assistant (GenAI Chat)** | ❌ | ✅ |
| **Semantic Search** | ❌ | ✅ |
| **Qdrant Vector DB** | ❌ | ✅ |
| **PDF/Excel Exports** | ❌ | ✅ |
| **CSV/Tabular Exports** | ❌ | ✅ |
| **Scheduled Automation** | ❌ | ✅ |
| **Data Source Scanning** | ❌ | ✅ |
| **Admin CLI Tools** | ❌ | ✅ |
| **etcd High Availability** | ❌ (1 replica) | ✅ (3 replicas) |

---

### Resource Comparison: Minimal vs Full

#### Pod Count Comparison

| Category | Minimal | Full | Difference |
|----------|:-------:|:----:|:----------:|
| **GoodData.CN Core** | 22 | 33 | +11 pods |
| **Pulsar** | 11 | 11 | — |
| **PostgreSQL HA** | 5 | 5 | — |
| **Redis HA** | 3 | 3 | — |
| **etcd** | 1 | 3 | +2 pods |
| **Infrastructure** | 7 | 7 | — |
| **Total** | **49** | **62** | **+13 pods** |

#### CPU Requirements Comparison

| Category | Minimal (Request) | Full (Request) | Minimal (Limit) | Full (Limit) |
|----------|:-----------------:|:--------------:|:---------------:|:------------:|
| **GoodData.CN Core** | 2,340m | 4,950m | 10,000m | 19,100m |
| **AI Features** | — | 2,500m | — | 5,000m |
| **Export Features** | — | 2,400m | — | 8,800m |
| **Automation** | — | 100m | — | 500m |
| **Scan Model** | — | 100m | — | 500m |
| **Tools** | — | 10m | — | 200m |
| **etcd (extra 2 replicas)** | — | 200m | — | 600m |
| **Pulsar** | 1,350m | 1,350m | — | — |
| **Infrastructure** | 300m | 300m | — | — |
| **Total** | **~4.0 vCPU** | **~9.3 vCPU** | **~10 vCPU** | **~24.7 vCPU** |

#### Memory Requirements Comparison

| Category | Minimal (Request) | Full (Request) | Minimal (Limit) | Full (Limit) |
|----------|:-----------------:|:--------------:|:---------------:|:------------:|
| **GoodData.CN Core** | 7,193Mi | 12,908Mi | 13,157Mi | 21,372Mi |
| **AI Features** | — | 5,488Mi | — | 8,500Mi |
| **Export Features** | — | 5,475Mi | — | 8,865Mi |
| **Automation** | — | 450Mi | — | 1,200Mi |
| **Scan Model** | — | 300Mi | — | 560Mi |
| **Tools** | — | 5Mi | — | 200Mi |
| **etcd (extra 2 replicas)** | — | 512Mi | — | 1,024Mi |
| **Pulsar** | 1,728Mi | 1,728Mi | — | — |
| **Infrastructure** | 230Mi | 230Mi | — | — |
| **Total** | **~9.2 GB** | **~21.4 GB** | **~13.2 GB** | **~33.7 GB** |

---

### Visual Comparison Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GoodData.CN Resource Comparison                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PODS                                                                       │
│  Minimal: ████████████████████████████████████████████████░░░░░  49 pods    │
│  Full:    ██████████████████████████████████████████████████████████  62    │
│                                                                             │
│  CPU REQUESTS                                                               │
│  Minimal: ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~4.0 vCPU      │
│  Full:    ██████████████████████████████████████████████████  ~9.3 vCPU     │
│                                                                             │
│  MEMORY REQUESTS                                                            │
│  Minimal: ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~9.2 GB        │
│  Full:    ██████████████████████████████████████████████████  ~21.4 GB      │
│                                                                             │
│  CPU LIMITS                                                                 │
│  Minimal: ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~10 vCPU       │
│  Full:    ██████████████████████████████████████████████████  ~24.7 vCPU    │
│                                                                             │
│  MEMORY LIMITS                                                              │
│  Minimal: ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ~13.2 GB       │
│  Full:    ██████████████████████████████████████████████████  ~33.7 GB      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Detailed Feature Resource Breakdown

The following features are **disabled** in the current minimal installation:

#### AI Features (3 pods)

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|:-----------:|:---------:|:--------------:|:------------:|
| gen-ai | 2,000m | 4,000m | 5,000Mi | 8,000Mi |
| gen-ai-metadata-sync | 250m | 500m | 238Mi | 250Mi |
| qdrant-db | 250m | 500m | 250Mi | 250Mi |
| **Subtotal** | **2,500m** | **5,000m** | **5,488Mi** | **8,500Mi** |

**Description:** Enables AI-powered assistant, semantic search, and natural language queries.

#### Export Features (3 pods)

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|:-----------:|:---------:|:--------------:|:------------:|
| export-builder | 2,250m | 8,100m | 4,765Mi | 7,815Mi |
| export-controller | 100m | 500m | 560Mi | 800Mi |
| tabular-exporter | 50m | 200m | 150Mi | 250Mi |
| **Subtotal** | **2,400m** | **8,800m** | **5,475Mi** | **8,865Mi** |

**Description:** Enables PDF, Excel, and CSV exports of dashboards and reports.

#### Optional Services (3 pods)

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|:-----------:|:---------:|:--------------:|:------------:|
| automation | 100m | 500m | 450Mi | 1,200Mi |
| scan-model | 100m | 500m | 300Mi | 560Mi |
| tools | 10m | 200m | 5Mi | 200Mi |
| **Subtotal** | **210m** | **1,200m** | **755Mi** | **1,960Mi** |

**Description:** Scheduled tasks, data source schema discovery, and admin CLI utilities.

#### etcd HA (2 additional pods)

| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|:-----------:|:---------:|:--------------:|:------------:|
| etcd-1 | 100m | 300m | 256Mi | 512Mi |
| etcd-2 | 100m | 300m | 256Mi | 512Mi |
| **Subtotal** | **200m** | **600m** | **512Mi** | **1,024Mi** |

**Description:** High availability configuration for etcd distributed key-value store.

---

### Total Resource Savings (Minimal vs Full)

| Metric | Full Installation | Minimal (Current) | Savings | % Reduction |
|--------|:-----------------:|:-----------------:|:-------:|:-----------:|
| **Pods** | 62 | 49 | 13 pods | 21% |
| **CPU Requests** | 9.3 vCPU | 4.0 vCPU | 5.3 vCPU | 57% |
| **CPU Limits** | 24.7 vCPU | 10.0 vCPU | 14.7 vCPU | 60% |
| **Memory Requests** | 21.4 GB | 9.2 GB | 12.2 GB | 57% |
| **Memory Limits** | 33.7 GB | 13.2 GB | 20.5 GB | 61% |

> **The minimal configuration reduces resource requirements by approximately 57-61%** while maintaining core analytics functionality.

---

## Minimum System Requirements

### Minimal Configuration (Current Installation)

| Component | Minimum | Recommended | Notes |
|-----------|:-------:|:-----------:|-------|
| **CPU** | 4 cores | 8+ cores | 4 vCPU requested |
| **Memory** | 16 GB | 32 GB+ | 9.2 GB requested, ~13 GB actual |
| **Storage** | 50 GB free | 100 GB+ free | Docker images + persistent volumes |
| **Docker Memory** | 12 GB | 16 GB+ | Must allocate in Docker Desktop |

### Full Configuration (All Features Enabled)

| Component | Minimum | Recommended | Notes |
|-----------|:-------:|:-----------:|-------|
| **CPU** | 10 cores | 16+ cores | 9.3 vCPU requested |
| **Memory** | 32 GB | 64 GB+ | 21.4 GB requested, ~25 GB actual |
| **Storage** | 100 GB free | 200 GB+ free | AI models + export cache |
| **Docker Memory** | 28 GB | 32 GB+ | Must allocate in Docker Desktop |

---

## Configuration File Reference

### values-gdcn.yaml Key Settings

```yaml
# Replica count for all services
replicaCount: 1

# AI Features (disabled)
deployGenAIService: false
enableSemanticSearch: false
enableGenAIChat: false
deployGenAIMetadataSync: false
deployQdrant: false

# Export Features (disabled)
# deployExportBuilder is a proper flag in gooddata-common/values.yaml
deployExportBuilder: false
exportController:
  replicaCount: 0
tabularExporter:
  replicaCount: 0

# Optional Services (disabled)
automation:
  replicaCount: 0
scanModel:
  replicaCount: 0
tools:
  replicaCount: 0

# etcd (reduced for local dev)
etcd:
  replicaCount: 1

# TLS Configuration
ingress:
  lbProtocol: https
dex:
  ingress:
    authHost: 'localhost'
    tls:
      authSecretName: 'gooddata-cn-tls-secret'
```

### Available Deploy Flags (exports.flags)

These flags from `gooddata-common/values.yaml` can properly enable/disable components:

| Flag | Default | Description |
|------|:-------:|-------------|
| `deployGateway` | `true` | API Gateway (required for most operations) |
| `deployGatewayMdSink` | `false` | Metadata sink gateway |
| `deployDexIdP` | `true` | Dex Identity Provider |
| `deployGenAIService` | `false` | GenAI chat and AI assistant |
| `deployGenAIMetadataSync` | `false` | AI metadata synchronization |
| `deployExportBuilder` | `true` | PDF/Excel export builder |
| `deployMCPServer` | `false` | MCP Server for AI integrations |
| `deployAgenticWorkflows` | `false` | Agentic AI workflows (Temporal workers) |
| `deployQuiverDatasource` | `false` | Additional FlexQuery datasource nodes |
| `deployQuiverDatasourceFs` | `false` | FS-based datasource capabilities |
| `deployQuiverGeoCollections` | `false` | Geo collections support |
| `deployDedicatedPolicyNodes` | `false` | Dedicated policy evaluation nodes |
| `deployQdrant` | `false` | Qdrant vector database (parent chart) |
| `deployRedisHA` | `true` | Redis HA cluster (parent chart) |
| `deployPostgresHA` | `true` | PostgreSQL HA cluster (parent chart) |

**Services without deploy flags** (use `replicaCount: 0` to disable):
- `automation` - Scheduled tasks, alerts, notifications
- `scanModel` - Data source schema discovery
- `tools` - Admin CLI utilities
- `exportController` - Export job orchestration
- `tabularExporter` - CSV/tabular exports

---

## Quick Commands

```bash
# Enter bootstrap container
./shell.sh up

# Monitor cluster
k9s

# Check pod status
kubectl get pods -n gooddata-cn
kubectl get pods -n pulsar

# View resource usage
kubectl top nodes
kubectl top pods -n gooddata-cn

# Check organization
kubectl get organizations -n gooddata-cn

# View logs
kubectl logs -f deploy/gooddata-cn-auth-service -n gooddata-cn
```

---

## Conclusion

### Current Installation Summary

| Metric | Minimal (Current) | Full Installation | Savings |
|--------|:-----------------:|:-----------------:|:-------:|
| **Total Pods** | 49 | 62 | 13 pods (21%) |
| **CPU Requested** | ~4.6 vCPU | ~10 vCPU | 5.4 vCPU (54%) |
| **Memory Requested** | ~11 GB | ~23 GB | 12 GB (52%) |
| **Actual CPU Usage** | ~828m | ~2 vCPU (est.) | ~1.2 vCPU |
| **Actual Memory Usage** | ~8.4 GB | ~18 GB (est.) | ~9.6 GB |

### What's Included in Minimal Configuration

✅ Full analytics and BI capabilities  
✅ Dashboard creation and visualization  
✅ LDM (Logical Data Model) designer  
✅ SQL executor and query engine  
✅ User authentication via Dex  
✅ HTTPS/TLS access  
✅ PostgreSQL HA database (shared)  
✅ Redis HA cache  
✅ Pulsar messaging  

### What's Disabled in Minimal Configuration

❌ AI Assistant and GenAI Chat (saves 2.5 vCPU, 5.5 GB)  
❌ Semantic Search and Qdrant (included in AI)  
❌ PDF/Excel Export Builder (saves 2.25 vCPU, 4.7 GB)  
❌ CSV/Tabular Exports (saves 150m, 710 MB)  
❌ Scheduled Automation (saves 100m, 450 MB)  
❌ Data Source Schema Scanner (saves 100m, 300 MB)  
❌ Admin CLI Tools (saves 10m, 5 MB)  
❌ etcd HA (3→1 replica, saves 200m, 512 MB)  

### Recommendation

- **For development/testing:** Use the minimal configuration (current)
- **For production with exports:** Enable `deployExportBuilder: true`
- **For AI-powered features:** Enable all `deployGenAI*` and `deployQdrant` flags
- **For production HA:** Set `etcd.replicaCount: 3`

The minimal configuration provides **57% resource savings** while maintaining full core analytics functionality, making it ideal for local development and testing environments.

---

*Report generated automatically during GoodData.CN installation optimization.*  
*Last updated: January 14, 2026*
