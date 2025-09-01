# Infrastructure Resumption Guide

## Project Overview
- **Project ID**: gke-infra-969184
- **Account**: sambeyene@gmail.com
- **Primary Region**: us-central1
- **Primary Zone**: us-central1-a
- **Cluster Name**: main-cluster

## Current Infrastructure Snapshot
- **Cluster Created**: July 30, 2025
- **Current Node Count**: 8 nodes
- **Node Type**: e2-standard-2
- **Kubernetes Version**: v1.33.3-gke.1136000
- **Autoscaling**: 3-12 nodes
- **Disk Size**: 50GB per node

## Step-by-Step Resumption Process

### 1. Verify GCloud Configuration
```bash
# Set up gcloud (if on new machine)
gcloud auth login
gcloud config set project gke-infra-969184
gcloud config set compute/zone us-central1-a
gcloud config set compute/region us-central1
```

### 2. Recreate GKE Cluster
```bash
# Create the cluster with exact specifications
gcloud container clusters create main-cluster \
    --zone=us-central1-a \
    --machine-type=e2-standard-2 \
    --num-nodes=8 \
    --enable-autoscaling \
    --min-nodes=3 \
    --max-nodes=12 \
    --disk-size=50GB \
    --disk-type=pd-standard \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-network-policy \
    --enable-ip-alias \
    --enable-shielded-nodes \
    --enable-workload-identity \
    --release-channel=regular
```

### 3. Get Cluster Credentials
```bash
gcloud container clusters get-credentials main-cluster --zone=us-central1-a
```

### 4. Verify Cluster Connection
```bash
kubectl cluster-info
kubectl get nodes
```

### 5. Restore Applications

#### A. Restore Helm Releases
Based on helm-releases.txt, restore your applications:
```bash
# Navigate to your Helm charts directory
cd "C:\Users\AiO PC - Sam\OneDrive\Documents\Projects\SRE Helm"

# Install each Helm release (adjust based on actual releases)
# Example - replace with your actual releases from helm-releases.txt
.\helm install [RELEASE_NAME] [CHART_PATH] --namespace [NAMESPACE]
```

#### B. Apply Kubernetes Manifests
```bash
# If you have additional YAML manifests
kubectl apply -f manifests/
```

#### C. Restore ConfigMaps (if needed)
```bash
# Only restore critical ConfigMaps not managed by Helm
kubectl apply -f configmaps-backup.yaml
```

### 6. Restore Secrets
```bash
# Manually recreate sensitive secrets (don't apply from backup for security)
# Review secrets-list.txt and recreate necessary ones
kubectl create secret generic [SECRET_NAME] --from-literal=[KEY]=[VALUE]
```

### 7. Verify Application Status
```bash
kubectl get all --all-namespaces
kubectl get pv,pvc --all-namespaces
```

### 8. Test Applications
- Verify all services are running
- Test external endpoints/ingresses
- Validate data integrity
- Check monitoring and logging

## Important Backup Files Created
- `cluster-info.txt` - Cluster endpoint information
- `nodes-info.txt` - Node specifications and status
- `all-resources.txt` - All Kubernetes resources
- `persistent-volumes.txt` - Storage information
- `cluster-config.yaml` - Complete cluster configuration
- `gcloud-config.txt` - GCloud CLI settings
- `configmaps-backup.yaml` - All ConfigMaps
- `secrets-list.txt` - List of secrets (NOT values)
- `helm-releases.txt` - Helm deployments
- `ingress-list.txt` - External access points

## Cost Considerations During Pause
- **Stop**: All compute instances, load balancers, node pools
- **Keep**: Container registry images, persistent disk snapshots (if any), project settings
- **Monthly Storage Cost**: Estimated $5-20 for container images and small persistent storage

## Resumption Time Estimate
- **Cluster Creation**: 10-15 minutes
- **Application Deployment**: 15-30 minutes
- **Total**: 30-45 minutes

## Critical Notes
1. **External IP addresses** may change - update DNS records if needed
2. **TLS certificates** may need renewal if expired
3. **Service accounts** and **IAM permissions** are preserved
4. **Database connections** need to be re-established
5. **Monitoring and logging** will restart data collection

## Emergency Contacts & Resources
- **Google Cloud Console**: https://console.cloud.google.com/
- **Project Dashboard**: https://console.cloud.google.com/home/dashboard?project=gke-infra-969184
- **GitHub Repository**: [Add your repo URL]
- **Documentation**: This folder contains all backup files

## Validation Checklist
- [ ] Cluster is running and accessible
- [ ] All nodes are in Ready state
- [ ] All Helm releases are deployed
- [ ] All pods are running
- [ ] Persistent volumes are attached
- [ ] External services are accessible
- [ ] DNS/ingress is working
- [ ] Monitoring/logging is functional
