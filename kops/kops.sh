#!/bin/bash
# MAINTAINER: Ndiforamang Fusi
# Date Modified: 11/09/2024
# Description: Script to deploy a highly available Kubernetes cluster with Kubernetes 1.29

# Configuration
CLUSTER_NAME="dominionclass37.k8s.local"
S3_BUCKET="dominionclass37-state-store"
AWS_REGION="us-east-2"
K8S_VERSION="1.29.6"
NODE_COUNT=2
NODE_SIZE="t3.medium"
CONTROL_PLANE_SIZE="t3.medium"
ZONES="${AWS_REGION}a,${AWS_REGION}b,${AWS_REGION}c"
DNS_ZONE="dominionclass37.k8s.local"  # Replace with your actual Route 53 DNS zone (e.g., "k8s.example.com")

# Step 1: Install kops for Kubernetes 1.29 on a Linux Server
cd /tmp  # Use /tmp directory for downloading files
echo "Downloading kops..."
curl -Lo kops https://github.com/kubernetes/kops/releases/download/v${K8S_VERSION}/kops-linux-amd64
if [ $? -ne 0 ]; then
  echo "Failed to download kops."
  exit 1
fi
chmod +x kops
sudo mv kops /usr/local/bin/kops

# Verify if kops was successfully installed
if ! command -v kops &> /dev/null; then
    echo "kops installation failed."
    exit 1
fi

# Step 2: Install kubectl for Kubernetes 1.29 on a Linux Server
echo "Downloading kubectl..."
curl -Lo kubectl https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubectl
if [ $? -ne 0 ]; then
  echo "Failed to download kubectl."
  exit 1
fi
chmod +x kubectl
mkdir -p $HOME/bin && mv kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc  # Add kubectl to PATH permanently

# Verify if kubectl was successfully installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl installation failed."
    exit 1
fi

# Step 3: Create an S3 bucket in AWS for state storage
echo "Creating S3 bucket ${S3_BUCKET} for kops state store..."
aws s3api create-bucket --bucket ${S3_BUCKET} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION} || echo "Bucket already exists"

# Step 4: Enable versioning on the S3 bucket
echo "Enabling versioning on S3 bucket ${S3_BUCKET}..."
aws s3api put-bucket-versioning --bucket ${S3_BUCKET} --versioning-configuration Status=Enabled

# Step 5: Enable server-side encryption on the S3 bucket
echo "Enabling server-side encryption on S3 bucket ${S3_BUCKET}..."
aws s3api put-bucket-encryption --bucket ${S3_BUCKET} --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Step 6: Set up environment variables for kops
export NAME=${CLUSTER_NAME}
export KOPS_STATE_STORE=s3://${S3_BUCKET}

# Make the variables permanent by adding them to ~/.bashrc
echo "export NAME=${CLUSTER_NAME}" >> ~/.bashrc
echo "export KOPS_STATE_STORE=s3://${S3_BUCKET}" >> ~/.bashrc

# Step 7: Generate SSH key pair if not already existing
echo "Generating SSH key pair..."
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
fi

# Step 8: Create a highly available Kubernetes cluster using kops with DNS zone
echo "Creating Kubernetes cluster ${CLUSTER_NAME} with kops..."
kops create cluster --name ${NAME} --cloud=aws --zones ${ZONES} \
--control-plane-size ${CONTROL_PLANE_SIZE} --node-count=${NODE_COUNT} --node-size ${NODE_SIZE} \
--kubernetes-version ${K8S_VERSION} --ssh-public-key ~/.ssh/id_rsa.pub --dns-zone ${DNS_ZONE}

# Step 9: Build the cluster
echo "Building the cluster..."
kops update cluster --name ${NAME} --yes

# Step 10: Configure kubectl access to the cluster
echo "Setting up kubectl access to the cluster..."
kops export kubecfg --name ${NAME}

# Step 11: Validate the cluster with increased wait time to reduce timeouts
echo "Validating the cluster. This may take several minutes..."
kops validate cluster --wait 15m

echo "Cluster ${CLUSTER_NAME} deployed and validated successfully!"
