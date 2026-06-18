#!/bin/bash

# Inovatech - Setup and Deployment Script

set -e

echo "🚀 Inovatech Setup Script"
echo "========================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo ""
    echo "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_info "Docker found: $(docker --version)"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_info "kubectl found: $(kubectl version --client --short)"
    
    # Check aws cli
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI is not installed (required for EKS)"
    else
        log_info "AWS CLI found: $(aws --version)"
    fi
}

# Build Docker images
build_images() {
    echo ""
    echo "Building Docker images..."
    
    log_info "Building Products Service..."
    docker build -t inovatech/products:latest ./backend-products
    
    log_info "Building Orders Service..."
    docker build -t inovatech/orders:latest ./backend-orders
    
    log_info "Building Frontend..."
    docker build -t inovatech/frontend:latest ./frontend
}

# Start with docker-compose
start_docker_compose() {
    echo ""
    echo "Starting services with docker-compose..."
    
    docker-compose -f docker-compose.yml up -d
    
    log_info "Services started!"
    echo ""
    echo "Services URLs:"
    echo "  Frontend: http://localhost:5173"
    echo "  Products API: http://localhost:3001"
    echo "  Orders API: http://localhost:3002"
    echo ""
    echo "Run 'docker-compose logs -f' to see logs"
}

# Deploy to EKS
deploy_eks() {
    echo ""
    echo "Deploying to EKS..."
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_warn "Make sure kubeconfig is configured: aws eks update-kubeconfig --name inovatech-cluster --region us-east-1"
        exit 1
    fi
    
    log_info "Connected to cluster: $(kubectl cluster-info | head -1)"
    
    # Create namespace
    log_info "Creating namespace..."
    kubectl create namespace inovatech --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations
    log_info "Applying ConfigMaps and Secrets..."
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/secret.yaml
    kubectl apply -f k8s/mysql-init-configmap.yaml
    
    # Deploy services
    log_info "Deploying MySQL..."
    kubectl apply -f k8s/mysql.yaml
    kubectl rollout status deployment/mysql -n inovatech --timeout=5m
    
    log_info "Deploying Products Service..."
    kubectl apply -f k8s/products-deployment.yaml
    
    log_info "Deploying Orders Service..."
    kubectl apply -f k8s/orders-deployment.yaml
    
    log_info "Deploying Frontend..."
    kubectl apply -f k8s/frontend-deployment.yaml
    
    # Apply policies and HPA
    log_info "Applying Network Policies..."
    kubectl apply -f k8s/network-policy.yaml
    
    log_info "Applying RBAC..."
    kubectl apply -f k8s/rbac.yaml
    
    log_info "Configuring Autoscaling..."
    kubectl apply -f k8s/hpa.yaml
    
    log_info "Configuring Ingress..."
    kubectl apply -f k8s/ingress.yaml
    
    # Wait for rollout
    log_info "Waiting for deployments to be ready..."
    kubectl rollout status deployment/products-service -n inovatech --timeout=5m
    kubectl rollout status deployment/orders-service -n inovatech --timeout=5m
    kubectl rollout status deployment/frontend -n inovatech --timeout=5m
    
    log_info "All services deployed successfully!"
}

# Show status
show_status() {
    echo ""
    echo "Current Status:"
    echo "=============="
    
    kubectl get deployments -n inovatech
    echo ""
    
    kubectl get svc -n inovatech
    echo ""
    
    kubectl get pods -n inovatech
}

# Main menu
show_menu() {
    echo ""
    echo "Select deployment mode:"
    echo "1) Local Development (Docker Compose)"
    echo "2) EKS Production Deployment"
    echo "3) Check Prerequisites"
    echo "4) Show Status"
    echo "5) Exit"
    echo ""
    read -p "Enter choice [1-5]: " choice
}

# Main script
main() {
    check_prerequisites
    
    while true; do
        show_menu
        
        case $choice in
            1)
                build_images
                start_docker_compose
                ;;
            2)
                deploy_eks
                show_status
                ;;
            3)
                check_prerequisites
                ;;
            4)
                show_status
                ;;
            5)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                ;;
        esac
    done
}

main
