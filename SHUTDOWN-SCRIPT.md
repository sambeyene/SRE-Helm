# Safe Infrastructure Shutdown Script

## Pre-Shutdown Checklist
- [x] All backup files created
- [x] Resumption guide documented
- [x] Helm releases documented
- [x] Configurations exported

## Current Helm Releases to Restore
Based on your current deployments, you'll need to restore these releases:

```text
NAME                NAMESPACE        STATUS     CHART                      
sre-kagent-dev      sre-dev         deployed   kagent-0.6.5              
sre-kagent-crds     sre-dev         deployed   kagent-crds-0.6.5          
argocd              argocd-v2       deployed   argo-cd-8.3.0              
backup-system-v2    backup-system   deployed   agentex-backup-system-1.0.0
ccr                 agentex-system  deployed   ccr-1.0.0                  
dapr                dapr-system     deployed   dapr-1.15.9                
dapr-dashboard      dapr-system     deployed   dapr-dashboard-0.15.0      
external-secrets    external-secrets deployed  external-secrets-0.19.2   
jaeger-v2           observability   deployed   jaeger-3.4.1               
kubecost            kubecost        deployed   cost-analyzer-2.8.2        
loki-v2             observability   deployed   loki-6.36.1                
temporal            temporal-system deployed   temporal-0.65.0            
temporal-worker     agentex-system  deployed   temporal-worker-0.1.0      

FAILED RELEASES (need investigation):
agentex-monitoring  monitoring      failed     kube-prometheus-stack-77.0.1
agentex-portal      agentex-system  failed     agentex-portal-0.1.0       
```

## Shutdown Commands

### 1. Final Data Backup (Optional)
```bash
# If you have critical data in persistent volumes
kubectl get pv
# Create snapshots if needed (this will incur costs)
```

### 2. Delete the GKE Cluster
```bash
# This stops ALL compute costs immediately
gcloud container clusters delete main-cluster --zone=us-central1-a --quiet
```

### 3. Clean Up Additional Resources (Optional Cost Savings)
```bash
# Delete any orphaned disks
gcloud compute disks list
gcloud compute disks delete [DISK_NAME] --zone=us-central1-a --quiet

# Delete any load balancers
gcloud compute forwarding-rules list
gcloud compute forwarding-rules delete [RULE_NAME] --region=us-central1 --quiet

# Delete any static IPs
gcloud compute addresses list
gcloud compute addresses delete [ADDRESS_NAME] --region=us-central1 --quiet
```

### 4. Preserve Container Images (Small Cost)
```bash
# List current images (keep these - minimal cost)
gcloud container images list
```

## What Gets Deleted (Cost Savings)
- ✅ All GKE nodes (~$200-400/month savings)
- ✅ Load balancers (~$15-30/month savings)
- ✅ Compute Engine VMs
- ✅ Network egress charges

## What Stays (Minimal Cost)
- ✅ Container Registry images (~$5-10/month)
- ✅ Project settings and IAM
- ✅ Service accounts and API keys
- ✅ Cloud DNS zones (if any)
- ✅ Persistent disk snapshots (if created)

## Estimated Monthly Savings
- **Current estimated cost**: $250-500/month
- **Paused cost**: $5-20/month
- **Net savings**: $230-480/month

## Time to Execute Shutdown
- **Total time**: 5-10 minutes
- **Cluster deletion**: 3-5 minutes
- **Resource cleanup**: 2-5 minutes

## Critical Reminders
1. **GitHub repository** contains all your infrastructure code
2. **All Helm charts** are preserved in this directory
3. **Configuration files** are backed up in this folder
4. **Project billing** will continue for storage (~$5-20/month)
5. **Service accounts and secrets** will need to be recreated manually

## Post-Shutdown Verification
```bash
# Verify cluster is deleted
gcloud container clusters list

# Verify no compute instances running
gcloud compute instances list

# Check for any remaining billable resources
gcloud compute disks list
gcloud compute forwarding-rules list
gcloud compute addresses list
```

## Emergency Recovery (If Needed)
If you need to quickly restore for urgent access:
1. Follow `RESUMPTION-GUIDE.md`
2. Start with cluster creation (10-15 minutes)
3. Deploy only critical applications first
4. Full restoration can be completed later
