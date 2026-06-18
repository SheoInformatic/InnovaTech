#!/bin/bash

# Script rápido para preparar el setup en AWS

set -e

REGION="us-east-1"
CLUSTER_NAME="inovatech-cluster"
AWS_ACCOUNT_ID="123456789012"  # Reemplazar con tu account ID

echo "🚀 Inovatech AWS Setup Script"
echo "============================="

# 1. Crear EKS Cluster
echo "1️⃣  Creating EKS Cluster..."
eksctl create cluster \
  --name $CLUSTER_NAME \
  --version 1.28 \
  --region $REGION \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 10 \
  --managed \
  --with-oidc

# 2. Crear ECR Repositories
echo ""
echo "2️⃣  Creating ECR Repositories..."
aws ecr create-repository \
  --repository-name inovatech/products \
  --region $REGION \
  --encryption-configuration encryptionType=AES || true

aws ecr create-repository \
  --repository-name inovatech/orders \
  --region $REGION \
  --encryption-configuration encryptionType=AES || true

aws ecr create-repository \
  --repository-name inovatech/frontend \
  --region $REGION \
  --encryption-configuration encryptionType=AES || true

# 3. Crear IAM Role para GitHub Actions
echo ""
echo "3️⃣  Creating IAM Role for GitHub Actions..."

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Diegorcl94/devopstres:*"
        }
      }
    }
  ]
}
EOF

# Create role
ROLE_NAME="github-actions-inovatech"
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file:///tmp/trust-policy.json || true

# Create policy
cat > /tmp/policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${AWS_ACCOUNT_ID}:repository/inovatech/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name github-actions-policy \
  --policy-document file:///tmp/policy.json || true

# 4. Get kubeconfig
echo ""
echo "4️⃣  Updating kubeconfig..."
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# 5. Install metrics-server
echo ""
echo "5️⃣  Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 6. Install AWS Load Balancer Controller
echo ""
echo "6️⃣  Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add GitHub secrets:"
echo "   AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "   AWS_ROLE_ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "2. Push to GitHub:"
echo "   git add ."
echo "   git commit -m 'Add Inovatech infrastructure'"
echo "   git push origin main"
echo ""
echo "3. GitHub Actions will automatically deploy!"
