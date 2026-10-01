# Oracle GoldenGate 23ai Container Image Analysis & GCP Artifact Registry Deployment Guide

This document presents a technical analysis of the **Oracle GoldenGate 23ai Microservices Container Image archive** (`ora23ai-2326202.tar`) and provides deployment procedures for storing and running it within **Google Cloud Platform (GCP)** using Artifact Registry, Google Kubernetes Engine (GKE), or Compute Engine (GCE).

---

## 1. Executive Summary & Image Technical Profile

| Attribute | Details |
| :--- | :--- |
| **Archive File** | `ora23ai-2326202.tar` (~2.86 GB compressed / ~3.07 GB uncompressed TAR) |
| **Source URL** | `https://objectstorage.eu-zurich-1.oraclecloud.com/p/_Rozg2bzsPyKLktcTVOc3jpPI9_h75fsGyMTAqUFFkR2kOa0-TM6lNFUPLZAtvkH/n/zrtpnntkgyvg/b/codina_aistudio/o/ora23ai-2326202.tar` |
| **Image Repo & Tag** | `localhost/oracle/goldengate:23.26.2.0.2` |
| **Product Version** | Oracle GoldenGate 23ai Microservices Architecture (Release `23.26.2.0.2`, built June 11, 2026) |
| **Base Operating System** | Oracle Linux 8 (`oraclelinux:8`) |
| **Architecture & Platform** | `linux/amd64` |
| **Build Software** | `fbo_ggs_Linux_x64_Oracle_services_shiphome.zip` |
| **Container Engine Compatibility** | Docker, Podman, Containerd, Google Cloud Buildpack / Artifact Registry |

---

## 2. Deep-Dive Container Image Inspection

Through deep inspection of the container image manifest (`manifest.json`) and image configuration (`364d3e8ee0a89c673b4ed05d577b8b8bb56176f52282b95eca4ac4d0cfeb4301.json`), the internal structure and runtime configurations are established:

### 2.1 Environment Variables
```bash
OGG_HOME=/u01/ogg
OGG_DEPLOYMENT_HOME=/u02
OGG_TEMPORARY_FILES=/u03
OGG_DEPLOYMENT_SCRIPTS=/u01/ogg/scripts
PATH=/u01/ogg/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### 2.2 Network Ports & Routing
- **Exposed Ports**: `80/tcp` (HTTP) and `443/tcp` (HTTPS).
- **Internal NGINX Reverse Proxy**: NGINX is built into the container image to act as a front-end reverse proxy routing TLS/HTTP connections to internal GoldenGate Microservices components (Service Manager, Admin Server, Distribution Server, Receiver Server, Performance Metrics Server).

### 2.3 Volume Mount Points & Persistent Storage Layout
- `/u02`: **GoldenGate Deployment Home (`OGG_DEPLOYMENT_HOME`)**. Stores deployment runtime state, trail files (`/u02/deployments/<name>/dirdat`), process parameter files (`dirprm`), checkpoint files (`dirchk`), and SSL/TLS certificates. Must be mounted on persistent storage (e.g. GKE PersistentVolumeClaim or GCE persistent disk).
- `/u03`: **Temporary Files (`OGG_TEMPORARY_FILES`)**. Used for temporary swap and trail file staging.
- `/u01/ogg/scripts`: **Custom Startup Scripts (`OGG_DEPLOYMENT_SCRIPTS`)**.

### 2.4 Entrypoint & Health Check Probes
- **Entrypoint**: `/usr/local/bin/deployment-main.sh`
- **Healthcheck Command**: `/usr/local/bin/healthcheck`
- **Start Period**: 90 seconds (allows NGINX and Service Manager initialization).

---

## 3. Uploading & Publishing to GCP Artifact Registry

To make this image available for GKE clusters, Cloud Run, or GCE VMs across GCP, import and push the archive to Google Artifact Registry.

### Step 1: Create an Artifact Registry Docker Repository
```bash
gcloud artifacts repositories create oracle-migration \
    --repository-format=docker \
    --location=europe-west3 \
    --description="Docker repository for Oracle ZDM & GoldenGate containers"
```

### Step 2: Download and Load the Image Tarball
```bash
# Download archive from OCI Object Storage
curl -O "https://objectstorage.eu-zurich-1.oraclecloud.com/ora23ai-2326202.tar"

# Load image into Docker daemon
docker load -i ora23ai-2326202.tar

# Verify loaded image
docker images | grep goldengate
```

### Step 3: Tag and Push to GCP Artifact Registry
```bash
# Configure Docker authentication for GCP Artifact Registry
gcloud auth configure-docker europe-west3-docker.pkg.dev

# Tag image for Artifact Registry
docker tag localhost/oracle/goldengate:23.26.2.0.2 \
    europe-west3-docker.pkg.dev/${GCP_PROJECT_ID}/oracle-migration/goldengate:23.26.2.0.2

docker tag localhost/oracle/goldengate:23.26.2.0.2 \
    europe-west3-docker.pkg.dev/${GCP_PROJECT_ID}/oracle-migration/goldengate:latest

# Push image to Artifact Registry
docker push europe-west3-docker.pkg.dev/${GCP_PROJECT_ID}/oracle-migration/goldengate:23.26.2.0.2
docker push europe-west3-docker.pkg.dev/${GCP_PROJECT_ID}/oracle-migration/goldengate:latest
```

---

## 4. Kubernetes (GKE) Deployment Specification

The updated Kubernetes deployment manifest (`modules/zdm_container/k8s/goldengate-deployment.yaml`) incorporates the exact ports, volume mounts, and health checks required by this 23ai image:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ogg-trail-pvc
  namespace: zdm-migration
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: goldengate-deployment
  namespace: zdm-migration
spec:
  replicas: 1
  selector:
    matchLabels:
      app: goldengate
  template:
    metadata:
      labels:
        app: goldengate
    spec:
      containers:
        - name: goldengate
          image: europe-west3-docker.pkg.dev/YOUR_PROJECT_ID/oracle-migration/goldengate:23.26.2.0.2
          ports:
            - containerPort: 80
              name: http
            - containerPort: 443
              name: https
          env:
            - name: OGG_ADMIN_USER
              value: "oggadmin"
            - name: OGG_ADMIN_PASSWORD
              value: "OracleGoldenGate123#"
            - name: OGG_DEPLOYMENT_NAME
              value: "oggdep1"
          volumeMounts:
            - name: ogg-storage
              mountPath: /u02
          livenessProbe:
            exec:
              command:
                - /usr/local/bin/healthcheck
            initialDelaySeconds: 90
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 60
            periodSeconds: 15
      volumes:
        - name: ogg-storage
          persistentVolumeClaim:
            claimName: ogg-trail-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: goldengate-service
  namespace: zdm-migration
spec:
  ports:
    - port: 80
      targetPort: 80
      name: http
    - port: 443
      targetPort: 443
      name: https
  selector:
    app: goldengate
  type: ClusterIP
```

---

## 5. Oracle Zero Downtime Migration (ZDM) Integration

In an **Online Logical Migration** flow:
1. **Schema & Initial Load**: ZDM orchestrates Data Pump export from the source Oracle database to GCS / Object Storage, and imports into target Oracle Database (GCE DB, Exadata Database Service, or Autonomous Database).
2. **Change Data Capture (CDC)**: ZDM configures GoldenGate 23ai running in GKE or on a VM.
3. **Replication**: Extract process captures source redo logs, writes trail files to `/u02/deployments/<name>/dirdat`, and Replicat process applies transactions to the target database over SQL*Net (port 1521/1522).
4. **Zero-Downtime Cutover**: Once target latency reaches 0 seconds, application traffic is switched to GCP target database.
