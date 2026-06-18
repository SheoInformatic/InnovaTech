# Inovatech Gaming Store - DevOps Deployment

Sistema de orquestación y despliegue continuo para una tienda de juegos en línea usando Kubernetes (EKS) en AWS.

## Estructura del Proyecto

```
inovatech/
├── backend-products/        # Microservicio de Productos
├── backend-orders/          # Microservicio de Órdenes
├── frontend/                # Aplicación React
├── db/                       # Base de datos MySQL
├── k8s/                      # Manifiestos de Kubernetes
└── .github/workflows/        # Pipelines de CI/CD
```

## Componentes

### Microservicios Backend
- **Products Service** (Node.js + Express) - Puerto 3001
- **Orders Service** (Node.js + Express) - Puerto 3002
- **MySQL Database** - Puerto 3306

### Frontend
- **React + Vite** - Interfaz web
- **Nginx** - Servidor web

## Requisitos Previos

- AWS Account con permisos EKS, ECR
- AWS CLI v2
- kubectl
- Docker
- GitHub Actions configurado

## Configuración de AWS

### 1. Crear EKS Cluster

```bash
eksctl create cluster \
  --name inovatech-cluster \
  --version 1.28 \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 10
```

### 2. Crear ECR Repositories

```bash
aws ecr create-repository --repository-name inovatech/products --region us-east-1
aws ecr create-repository --repository-name inovatech/orders --region us-east-1
aws ecr create-repository --repository-name inovatech/frontend --region us-east-1
```

### 3. Configurar AWS IAM Role para GitHub Actions

```bash
# Crear OIDC Provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com

# Crear role
aws iam create-role \
  --role-name github-actions-inovatech \
  --assume-role-policy-document file://trust-policy.json
```

### 4. Crear Secrets en GitHub

En Settings → Secrets and variables → Actions, agregar:

```
AWS_ACCOUNT_ID: xxxxxxxxxxxxx
AWS_ROLE_ARN: arn:aws:iam::xxxxxxxxxxxxx:role/github-actions-inovatech
```

## Despliegue

### Opción 1: Despliegue Manual

```bash
# 1. Crear namespace
kubectl create namespace inovatech

# 2. Aplicar ConfigMaps y Secrets
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/mysql-init-configmap.yaml

# 3. Desplegar MySQL
kubectl apply -f k8s/mysql.yaml

# 4. Desplegar servicios
kubectl apply -f k8s/products-deployment.yaml
kubectl apply -f k8s/orders-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml

# 5. Aplicar HPA y Ingress
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml

# 6. Verificar estado
kubectl get deployments -n inovatech
kubectl get svc -n inovatech
```

### Opción 2: Despliegue con CI/CD

1. Realizar push a rama `main`
2. GitHub Actions automáticamente:
   - Construye imágenes Docker
   - Push a ECR
   - Deploya a EKS
   - Ejecuta smoke tests

## Scaling y Alta Disponibilidad

### Horizontal Pod Autoscaler (HPA)

Cada servicio tiene HPA configurado:

- **Products Service**: 2-5 pods, trigger en 70% CPU
- **Orders Service**: 2-5 pods, trigger en 70% CPU
- **Frontend**: 2-4 pods, trigger en 75% CPU

```bash
# Ver estado de HPA
kubectl get hpa -n inovatech
kubectl describe hpa products-service-hpa -n inovatech
```

### Pod Disruption Budget

```bash
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: products-pdb
  namespace: inovatech
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: products-service
EOF
```

## Monitoreo y Logs

### Ver logs en tiempo real

```bash
# Logs de un servicio
kubectl logs -f deployment/products-service -n inovatech

# Logs del último fallo
kubectl logs --previous deployment/products-service -n inovatech

# Ver eventos del cluster
kubectl get events -n inovatech
```

### Métricas

```bash
# Instalar metrics-server si no está presente
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Ver uso de recursos
kubectl top nodes
kubectl top pods -n inovatech
```

### CloudWatch

```bash
# Enviar logs a CloudWatch
aws logs create-log-group --log-group-name /eks/inovatech
```

## Pruebas de Carga

### Manual con Apache Bench

```bash
# Port forward
kubectl port-forward -n inovatech svc/products-service 3001:3001 &

# Ejecutar prueba
ab -n 1000 -c 50 http://localhost:3001/api/products

# Ver cómo escala
watch kubectl get pods -n inovatech
```

### Automatizado con GitHub Actions

```bash
# Trigger manual del workflow
gh workflow run autoscaling-tests.yml -R Diegorcl94/devopstres
```

## Rollback

```bash
# Ver historial de despliegues
kubectl rollout history deployment/products-service -n inovatech

# Rollback a versión anterior
kubectl rollout undo deployment/products-service -n inovatech

# Rollback a versión específica
kubectl rollout undo deployment/products-service -n inovatech --to-revision=2
```

## Troubleshooting

### Pod no inicia

```bash
kubectl describe pod <pod-name> -n inovatech
kubectl logs <pod-name> -n inovatech
```

### Servicio no responde

```bash
kubectl exec -it <pod-name> -n inovatech -- /bin/sh
nc -zv products-service 3001
```

### Database connection issues

```bash
kubectl exec -it mysql-0 -n inovatech -- mysql -u root -p${MYSQL_ROOT_PASSWORD}
```

## Limpieza

```bash
# Eliminar todo el namespace
kubectl delete namespace inovatech

# Eliminar cluster EKS
eksctl delete cluster --name inovatech-cluster --region us-east-1

# Eliminar ECR repositories
aws ecr delete-repository --repository-name inovatech/products --region us-east-1 --force
```

## Documentación de Decisiones Arquitectónicas

### 1. Uso de EKS vs ECS

**Selección: EKS**

Razones:
- Kubernetes es el estándar industrial
- Portabilidad entre clouds
- Comunidad más grande
- Mejor para microservicios complejos
- Escalabilidad superior

### 2. Microservicios

**Separación en Products y Orders**

Ventajas:
- Escalabilidad independiente
- Despliegues independientes
- Fallos aislados
- Equipos autónomos

### 3. Multi-réplica y Anti-Affinity

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - products-service
        topologyKey: kubernetes.io/hostname
```

Garantiza que pods de un mismo servicio se distribuyen en diferentes nodos.

### 4. Probes de Salud

- **Liveness Probe**: Reinicia el contenedor si está muerto
- **Readiness Probe**: Quita del tráfico si no está listo

### 5. Resource Limits

Previene consumo descontrolado y fairness entre pods.

### 6. HPA Basado en CPU

- Umbral 70% para backends
- Escalamiento rápido (30s) y descendimiento lento (300s)
- Evita oscilaciones

## KPIs Monitorear

1. **Disponibilidad**: % de tiempo que el servicio está online
2. **Latencia**: Tiempo de respuesta P95, P99
3. **Throughput**: Requests por segundo
4. **Error Rate**: % de requests fallidos
5. **Pod Count**: Número de replicas activas
6. **Deploy Frequency**: Despliegues por día
7. **Deployment Lead Time**: Tiempo desde commit a producción
8. **Mean Time to Recovery**: Tiempo promedio para recuperarse de fallos

## Referencias

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
