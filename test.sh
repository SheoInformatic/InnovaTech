#!/bin/bash

# Quick test to verify all services are running
set -e

NAMESPACE="inovatech"

echo "🔍 Running Inovatech System Validation Tests"
echo "==========================================="

# Test 1: Check namespace
echo ""
echo "Test 1: Checking namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "✓ Namespace $NAMESPACE exists"
else
    echo "✗ Namespace $NAMESPACE not found"
    exit 1
fi

# Test 2: Check deployments
echo ""
echo "Test 2: Checking deployments..."
DEPLOYMENTS=("mysql" "products-service" "orders-service" "frontend")
for dep in "${DEPLOYMENTS[@]}"; do
    if kubectl get deployment $dep -n $NAMESPACE &> /dev/null; then
        echo "✓ Deployment $dep found"
    else
        echo "✗ Deployment $dep not found"
    fi
done

# Test 3: Check pod status
echo ""
echo "Test 3: Checking pod status..."
RUNNING=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -q | wc -l)
TOTAL=$(kubectl get pods -n $NAMESPACE -q | wc -l)
echo "✓ Running pods: $RUNNING/$TOTAL"

if [ $RUNNING -lt 5 ]; then
    echo "⚠ Not all pods are running yet"
fi

# Test 4: Check services
echo ""
echo "Test 4: Checking services..."
SERVICES=("products-service" "orders-service" "frontend-service" "mysql-service")
for svc in "${SERVICES[@]}"; do
    if kubectl get svc $svc -n $NAMESPACE &> /dev/null; then
        echo "✓ Service $svc found"
    else
        echo "✗ Service $svc not found"
    fi
done

# Test 5: Check HPA
echo ""
echo "Test 5: Checking Horizontal Pod Autoscalers..."
HPA_COUNT=$(kubectl get hpa -n $NAMESPACE -q | wc -l)
echo "✓ HPAs configured: $HPA_COUNT"

# Test 6: Health checks
echo ""
echo "Test 6: Running health checks..."
echo "Starting port-forwards in background..."

# Products health check
(kubectl port-forward -n $NAMESPACE svc/products-service 3001:3001 > /dev/null 2>&1 &)
sleep 2
if curl -s http://localhost:3001/health | grep -q "UP"; then
    echo "✓ Products service is healthy"
else
    echo "✗ Products service health check failed"
fi

# Orders health check
(kubectl port-forward -n $NAMESPACE svc/orders-service 3002:3002 > /dev/null 2>&1 &)
sleep 2
if curl -s http://localhost:3002/health | grep -q "UP"; then
    echo "✓ Orders service is healthy"
else
    echo "✗ Orders service health check failed"
fi

# Kill port-forwards
pkill -f "port-forward" || true

# Test 7: Database connectivity
echo ""
echo "Test 7: Checking database connectivity..."
if kubectl exec -it -n $NAMESPACE mysql-0 -- mysql -u root -pinovatech123 -e "SELECT 1" &> /dev/null; then
    echo "✓ Database is accessible"
else
    echo "✗ Database connectivity failed"
fi

echo ""
echo "✅ System validation complete!"
echo ""
echo "Current Status:"
kubectl get all -n $NAMESPACE
