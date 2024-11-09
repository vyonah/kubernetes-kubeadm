#!/bin/bash
# MAINTAINER: Ndiforamang Fusi
# Date Modified: 11/09/2024
# Description: Script to deploy a highly available k8s cluster with Kubernetes 1.29

# Step 1: Install kops for Kubernetes 1.29 on a Linux Server
cd /tmp  # Use /tmp directory for downloading files
curl -Lo kops https://github.com/kubernetes/kops/releases/download/v1.29.0/kops-linux-amd64
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
curl -Lo kubectl https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl
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
aws s3 mb s3://dominionclass37-state-store --region us-east-2

# Step 4: Enable versioning on the S3 bucket
aws s3api put-bucket-versioning --bucket dominionclass37-state-store --versioning-configuration Status=Enabled

# Step 5: Enable server-side encryption on the S3 bucket
aws s3api put-bucket-encryption --bucket dominionclass37-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Step 6: Set up environment variables for kops
export NAME=dominionclass37.k8s.local
export KOPS_STATE_STORE=s3://dominionclass37-state-store

# Make the variables permanent by adding them to ~/.bashrc
echo "export NAME=dominionclass37.k8s.local" >> ~/.bashrc
echo "export KOPS_STATE_STORE=s3://dominionclass37-state-store" >> ~/.bashrc

# Step 7: Generate SSH key pair if not already existing
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<< y >/dev/null 2>&1
fi

# Step 8: Create a highly available Kubernetes cluster using kops
kops create cluster --name ${NAME} --cloud=aws --zones us-east-2a,us-east-2b,us-east-2c \
--control-plane-size t3.medium --node-count=2 --node-size t3.medium --kubernetes-version 1.29.0

# Step 9: Build the cluster
kops update cluster --name ${NAME} --yes --admin

# Step 10: Validate the cluster with increased wait time to reduce timeouts
kops validate cluster --wait 15m 






