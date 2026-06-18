#!/bin/bash

# Inovatech - Load Testing Script for Demonstrating Autoscaling

NAMESPACE="inovatech"
DURATION=${1:-300}  # Default 5 minutes
CONCURRENT=${2:-50}  # Default 50 concurrent connections

echo "🔥 Inovatech Load Testing - Autoscaling Demonstration"
echo "====================================================="
echo "Duration: ${DURATION}s"
echo "Concurrent connections: ${CONCURRENT}"
echo ""

# Get initial pod count
echo "📊 Initial Pod Count:"
echo "Products Service:"
kubectl get pods -n $NAMESPACE -l app=products-service --no-headers
echo ""
echo "Orders Service:"
kubectl get pods -n $NAMESPACE -l app=orders-service --no-headers
echo ""

# Port forward
echo "🌐 Starting port forwarding..."
(kubectl port-forward -n $NAMESPACE svc/products-service 3001:3001 > /dev/null 2>&1 &)
PF_PID=$!
sleep 2

# Start load test
echo "🚀 Starting load test..."
echo ""

# Background monitoring
(
    while true; do
        echo "[$(date +%H:%M:%S)] Pod Count:"
        echo "  Products: $(kubectl get pods -n $NAMESPACE -l app=products-service --no-headers | wc -l)"
        echo "  Orders: $(kubectl get pods -n $NAMESPACE -l app=orders-service --no-headers | wc -l)"
        echo ""
        kubectl get hpa -n $NAMESPACE products-service-hpa --no-headers | awk '{print "  Products HPA: current=" $2 "/" $3 ", desired=" $4 ", conditions=" $5}'
        echo ""
        sleep 15
    done
) &
MON_PID=$!

# Run Apache Bench
if command -v ab &> /dev/null; then
    echo "Using Apache Bench..."
    # Calculate requests per second rate
    REQ_PER_SEC=$((1000 / (DURATION / 5)))
    
    for i in $(seq 1 5); do
        echo "Batch $i/5..."
        ab -n 1000 -c $CONCURRENT -q http://localhost:3001/api/products 2>/dev/null || true
        sleep $((DURATION / 5))
    done
else
    # Fallback to curl if ab is not available
    echo "Using curl for load test..."
    START=$(date +%s)
    COUNT=0
    
    while true; do
        ELAPSED=$(($(date +%s) - START))
        if [ $ELAPSED -ge $DURATION ]; then
            break
        fi
        
        for i in $(seq 1 $CONCURRENT); do
            (curl -s http://localhost:3001/api/products > /dev/null &)
        done
        
        COUNT=$((COUNT + CONCURRENT))
        sleep 5
    done
    
    echo "Completed $COUNT requests in ${DURATION}s"
fi

echo ""
echo "✅ Load test completed!"
echo ""

# Cleanup
kill $PF_PID $MON_PID 2>/dev/null || true

# Final status
echo "📊 Final Pod Count:"
echo "Products Service:"
kubectl get pods -n $NAMESPACE -l app=products-service --no-headers
echo ""
echo "Orders Service:"
kubectl get pods -n $NAMESPACE -l app=orders-service --no-headers
echo ""

echo "HPA Status:"
kubectl describe hpa products-service-hpa -n $NAMESPACE | tail -20
