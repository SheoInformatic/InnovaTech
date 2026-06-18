# Makefile for Inovatech DevOps

.PHONY: help build push deploy test logs clean

# Variables
DOCKER_REGISTRY = 123456789012.dkr.ecr.us-east-1.amazonaws.com
IMAGE_PREFIX = inovatech
NAMESPACE = inovatech
CLUSTER = inovatech-cluster
REGION = us-east-1

help:
	@echo "Inovatech Makefile Commands"
	@echo "============================"
	@echo "make build              - Build all Docker images"
	@echo "make build-products     - Build Products image only"
	@echo "make build-orders       - Build Orders image only"
	@echo "make build-frontend     - Build Frontend image only"
	@echo "make push               - Push images to ECR"
	@echo "make local-up           - Start local development (docker-compose)"
	@echo "make local-down         - Stop local development"
	@echo "make deploy             - Deploy to EKS"
	@echo "make rollback           - Rollback last deployment"
	@echo "make status             - Show deployment status"
	@echo "make logs-products      - Show Products logs"
	@echo "make logs-orders        - Show Orders logs"
	@echo "make logs-frontend      - Show Frontend logs"
	@echo "make clean              - Clean up all resources"
	@echo "make test-load          - Run load test"

build:
	docker build -t $(IMAGE_PREFIX)/products:latest ./backend-products
	docker build -t $(IMAGE_PREFIX)/orders:latest ./backend-orders
	docker build -t $(IMAGE_PREFIX)/frontend:latest ./frontend

build-products:
	docker build -t $(IMAGE_PREFIX)/products:latest ./backend-products

build-orders:
	docker build -t $(IMAGE_PREFIX)/orders:latest ./backend-orders

build-frontend:
	docker build -t $(IMAGE_PREFIX)/frontend:latest ./frontend

push: build
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(DOCKER_REGISTRY)
	docker tag $(IMAGE_PREFIX)/products:latest $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/products:latest
	docker tag $(IMAGE_PREFIX)/orders:latest $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/orders:latest
	docker tag $(IMAGE_PREFIX)/frontend:latest $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/frontend:latest
	docker push $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/products:latest
	docker push $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/orders:latest
	docker push $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/frontend:latest

local-up:
	docker-compose -f docker-compose.yml up -d
	@echo "✓ Services started"
	@echo "Frontend: http://localhost:5173"
	@echo "Products API: http://localhost:3001"
	@echo "Orders API: http://localhost:3002"

local-down:
	docker-compose -f docker-compose.yml down

deploy:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/secret.yaml
	kubectl apply -f k8s/mysql-init-configmap.yaml
	kubectl apply -f k8s/mysql.yaml
	kubectl apply -f k8s/products-deployment.yaml
	kubectl apply -f k8s/orders-deployment.yaml
	kubectl apply -f k8s/frontend-deployment.yaml
	kubectl apply -f k8s/hpa.yaml
	kubectl apply -f k8s/ingress.yaml
	@echo "✓ Deployment started"

rollback:
	kubectl rollout undo deployment/products-service -n $(NAMESPACE)
	kubectl rollout undo deployment/orders-service -n $(NAMESPACE)
	kubectl rollout undo deployment/frontend -n $(NAMESPACE)

status:
	@echo "=== Deployments ==="
	@kubectl get deployments -n $(NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== HPA ==="
	@kubectl get hpa -n $(NAMESPACE)

logs-products:
	kubectl logs -f deployment/products-service -n $(NAMESPACE)

logs-orders:
	kubectl logs -f deployment/orders-service -n $(NAMESPACE)

logs-frontend:
	kubectl logs -f deployment/frontend -n $(NAMESPACE)

logs-all:
	kubectl logs -f -l app=products-service,app=orders-service,app=frontend -n $(NAMESPACE)

describe-deployment:
	kubectl describe deployment products-service -n $(NAMESPACE)
	kubectl describe deployment orders-service -n $(NAMESPACE)
	kubectl describe deployment frontend -n $(NAMESPACE)

clean:
	kubectl delete namespace $(NAMESPACE)
	@echo "✓ Namespace deleted"

test-load:
	@echo "Starting load test..."
	kubectl port-forward -n $(NAMESPACE) svc/products-service 3001:3001 &
	sleep 2
	ab -n 1000 -c 50 http://localhost:3001/api/products
	@echo "✓ Load test completed"

test-health:
	@echo "Testing services health..."
	kubectl port-forward -n $(NAMESPACE) svc/products-service 3001:3001 &
	sleep 2
	curl -s http://localhost:3001/health | jq .
	kubectl port-forward -n $(NAMESPACE) svc/orders-service 3002:3002 &
	sleep 2
	curl -s http://localhost:3002/health | jq .

scale-up:
	kubectl scale deployment/products-service -n $(NAMESPACE) --replicas=5
	kubectl scale deployment/orders-service -n $(NAMESPACE) --replicas=5
	kubectl scale deployment/frontend -n $(NAMESPACE) --replicas=4

scale-down:
	kubectl scale deployment/products-service -n $(NAMESPACE) --replicas=2
	kubectl scale deployment/orders-service -n $(NAMESPACE) --replicas=2
	kubectl scale deployment/frontend -n $(NAMESPACE) --replicas=2
