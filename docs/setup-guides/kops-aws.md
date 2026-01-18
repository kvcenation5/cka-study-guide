# Kubernetes on AWS with kOps

kOps (Kubernetes Operations) is an open-source tool used to create, destroy, upgrade, and maintain production-grade, highly available Kubernetes clusters on AWS and other cloud providers.

Often referred to as **"The kubectl for clusters,"** kOps manages the entire cluster lifecycle, from infrastructure provisioning to Kubernetes software installation.

---

## Key Features

- **Full Automation**: Provisions all AWS resources (EC2, VPC, ASG, IAM, ELB).
- **High Availability**: Supports multi-master setups across multiple Availability Zones.
- **State-Sync Model**: Uses an S3 bucket to store the cluster configuration/state.
- **Dry-runs**: Preview infrastructure changes before applying them (`kops update cluster`).
- **Terraform Integration**: Can output Terraform manifests for Infrastructure-as-Code (IaC) workflows.

---

## Step-by-Step AWS Setup

### 1. Prerequisites (IAM & S3)
kOps requires an IAM user with appropriate permissions and an S3 bucket to store the cluster state.

```bash
# 1. Create S3 Bucket for state storage
aws s3 mb s3://clusters.example.com --region us-east-1

# 2. Versioning is highly recommended
aws s3api put-bucket-versioning --bucket clusters.example.com --versioning-configuration Status=Enabled

# 3. Export the state store environment variable
export KOPS_STATE_STORE=s3://clusters.example.com
```

### 2. DNS Configuration
kOps uses DNS for cluster discovery. You can use:
- **Public/Private Route53 Hosted Zone**: Recommended for production.
- **Gossip DNS**: Uses `.k8s.local` suffix for simpler setups without a real domain.

### 3. Create Cluster Configuration
This command generates the cluster specification but doesn't create the resources yet.

```bash
kops create cluster \
    --name=mycluster.k8s.local \
    --zones=us-east-1a,us-east-1b \
    --node-count=2 \
    --node-size=t3.medium \
    --master-size=t3.medium \
    --dns gossip
```

### 4. Build the Cluster
Review the plan and then apply it to provision AWS resources.

```bash
# Preview the changes
kops update cluster --name mycluster.k8s.local

# Apply and build
kops update cluster --name mycluster.k8s.local --yes --admin
```

It usually takes 5-10 minutes for the cluster to become ready.

---

## Lifecycle Management Commands

| Action | Command |
| :--- | :--- |
| **Validate Cluster** | `kops validate cluster` |
| **List Clusters** | `kops get clusters` |
| **Edit Configuration** | `kops edit cluster <name>` |
| **Rolling Update** | `kops rolling-update cluster --yes` |
| **Delete Cluster** | `kops delete cluster --name <name> --yes` |

---

## kOps vs. EKS vs. Kubeadm

| Feature | kOps | AWS EKS | Kubeadm |
| :--- | :--- | :--- | :--- |
| **Management** | Self-managed | AWS-managed Control Plane | Self-managed |
| **Infrastructure** | Automated (AWS) | Automated (AWS) | Manual / Any |
| **Control Plane** | You manage Nodes | AWS manages Nodes | You manage Nodes |
| **Customization** | Extremely High | Moderate | High |
| **Best For** | Custom production | Cloud-native production | Learning / On-prem |
