# Guía de Arquitectura - Inovatech Gaming Store

## Resumen Ejecutivo

Inovatech es una tienda de juegos de video que implementa una arquitectura de microservicios en Kubernetes (EKS) con despliegue continuo mediante GitHub Actions. La solución garantiza escalabilidad horizontal, alta disponibilidad y automatización operativa.

## Arquitectura General

```
┌─────────────────────────────────────────────────────┐
│                    Internet                          │
│           (Usuarios de Inovatech)                    │
└────────────────────────┬────────────────────────────┘
                         │
        ┌────────────────▼────────────────┐
        │   AWS Load Balancer (ALB)       │
        │   Puerto 80/443                 │
        └────────────────┬────────────────┘
                         │
        ┌────────────────▼────────────────────────────┐
        │         EKS Cluster                         │
        │    (3+ Nodos t3.medium)                     │
        │                                             │
        │  ┌──────────────────────────────────────┐   │
        │  │   Namespace: inovatech               │   │
        │  │                                      │   │
        │  │  ┌──────────────────────────────┐   │   │
        │  │  │  Frontend (React + Nginx)    │   │   │
        │  │  │  2-4 Replicas (HPA)          │   │   │
        │  │  │  Puerto 80                   │   │   │
        │  │  └──────────────────────────────┘   │   │
        │  │                                      │   │
        │  │  ┌──────────────────────────────┐   │   │
        │  │  │  Products Service (Node.js)  │   │   │
        │  │  │  2-5 Replicas (HPA)          │   │   │
        │  │  │  Puerto 3001                 │   │   │
        │  │  └──────────────────────────────┘   │   │
        │  │                                      │   │
        │  │  ┌──────────────────────────────┐   │   │
        │  │  │  Orders Service (Node.js)    │   │   │
        │  │  │  2-5 Replicas (HPA)          │   │   │
        │  │  │  Puerto 3002                 │   │   │
        │  │  └──────────────────────────────┘   │   │
        │  │                                      │   │
        │  │  ┌──────────────────────────────┐   │   │
        │  │  │  MySQL Database              │   │   │
        │  │  │  1 Replica (StatefulSet)     │   │   │
        │  │  │  PersistentVolume: 10Gi      │   │   │
        │  │  │  Puerto 3306                 │   │   │
        │  │  └──────────────────────────────┘   │   │
        │  │                                      │   │
        │  └──────────────────────────────────────┘   │
        │                                             │
        └─────────────────────────────────────────────┘
                         │
        ┌────────────────▼────────────────┐
        │   Amazon ECR                    │
        │  (Container Image Registry)     │
        │  - inovatech/products           │
        │  - inovatech/orders             │
        │  - inovatech/frontend           │
        └────────────────┬────────────────┘
                         │
        ┌────────────────▼────────────────┐
        │   GitHub Actions                │
        │   (CI/CD Pipeline)              │
        │  - Build Images                 │
        │  - Push to ECR                  │
        │  - Deploy to EKS                │
        │  - Run Tests                    │
        └─────────────────────────────────┘
```

## Componentes Detallados

### 1. Frontend (React + Vite + Nginx)

**Características:**
- SPA (Single Page Application) con React
- Build optimizado con Vite
- Servido por Nginx
- 2-4 réplicas con autoscaling basado en CPU

**Flujo:**
1. Usuario accede a inovatech.local
2. ALB enruta al servicio frontend
3. Nginx sirve la aplicación React compilada
4. React hace requests a api.inovatech.local

**Endpoint:** http://inovatech.local
**Recursos:**
- Request: 50m CPU, 64Mi RAM
- Limit: 500m CPU, 256Mi RAM

### 2. Products Service (Microservicio Node.js)

**Responsabilidades:**
- CRUD de productos
- Gestión de catálogo
- Información de stock

**Endpoints:**
```
GET  /health                  # Health check
GET  /api/products           # Listar todos
GET  /api/products/:id       # Obtener uno
POST /api/products           # Crear
PUT  /api/products/:id       # Actualizar
DELETE /api/products/:id     # Eliminar
```

**Escalabilidad:**
- 2-5 replicas
- Escala cuando CPU > 70%
- Baja cuando < 70% (300s cooldown)

**Base de datos:**
- MySQL tabla `products`
- Índice en platform para búsquedas rápidas

### 3. Orders Service (Microservicio Node.js)

**Responsabilidades:**
- CRUD de órdenes
- Validación contra Products Service
- Comunicación inter-servicio

**Endpoints:**
```
GET  /health                 # Health check
GET  /api/orders            # Listar todas
GET  /api/orders/:id        # Obtener una
POST /api/orders            # Crear (valida producto)
PUT  /api/orders/:id        # Actualizar
DELETE /api/orders/:id      # Eliminar
```

**Escalabilidad:**
- 2-5 replicas
- Mismo HPA que Products

**Comunicación:**
- Valida productos mediante HTTP call a http://products-service:3001

### 4. MySQL Database

**Características:**
- Versión 8.0
- Almacenamiento persistente (PVC 10Gi)
- Init scripts en ConfigMap
- Health checks cada 10s

**Tablas:**
- `products`: Catálogo de juegos
- `orders`: Historial de compras

**Backup:**
```bash
kubectl exec -it mysql-0 -n inovatech -- \
  mysqldump -u root -p${MYSQL_ROOT_PASSWORD} inovatech > backup.sql
```

## Configuración de Networking

### Service Discovery

```
products-service:3001   -> Product API
orders-service:3002     -> Orders API
mysql-service:3306      -> Database
frontend-service:80     -> Frontend
```

### Ingress Rules

```
inovatech.local         -> Frontend Service (port 80)
api.inovatech.local     -> Products + Orders (routing)
```

## Escalabilidad

### Horizontal Pod Autoscaler (HPA)

Cada servicio usa HPA v2 con múltiples métricas:

```yaml
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      averageUtilization: 80
```

**Comportamiento de Escalamiento:**

Scale Up (Escalamiento):
- Latencia: 0 segundos
- Políticas: +100% cada 30s, o +2 pods cada 60s
- Máximo: 5 pods (productos/órdenes), 4 pods (frontend)

Scale Down (Contracción):
- Latencia: 300 segundos
- Política: -50% cada 60s
- Mínimo: 2 pods

### Tolerancia a Fallos

**Pod Anti-Affinity:**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
```

Garantiza que pods del mismo servicio se distribuyen en diferentes nodos.

**Resource Requests & Limits:**

Previene "Noisy Neighbor Problem" y garantiza fairness.

**Health Checks:**

- Liveness: Reinicia contenedor si está muerto
- Readiness: Quita del tráfico si no está ready

### Rolling Updates

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

Garantiza 0 downtime durante despliegues.

## Seguridad

### Network Policies

```yaml
policyTypes:
- Ingress
- Egress
```

- Solo permite tráfico dentro del namespace
- Permite DNS para resolución
- Deniega por defecto

### RBAC (Role-Based Access Control)

```yaml
ServiceAccount: inovatech-sa
Role: inovatech-role
  - get pods, services
  - list deployments
  - watch logs
```

### Secrets Management

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=root \
  --from-literal=DB_PASSWORD=inovatech123 \
  -n inovatech
```

## CI/CD Pipeline

### GitHub Actions Workflow

```
Push a main/develop
        ↓
Build Docker Images (Products, Orders, Frontend)
        ↓
Login a ECR
        ↓
Push Images a ECR
        ↓
Update kubeconfig
        ↓
Apply ConfigMaps/Secrets
        ↓
Deploy MySQL
        ↓
Deploy Servicios (rollout)
        ↓
Apply HPA + Ingress
        ↓
Smoke Tests
        ↓
Notificación
```

**Tiempos:**
- Build: ~2 minutos
- Push a ECR: ~1 minuto
- Deploy: ~3 minutos
- Tests: ~2 minutos
- **Total: ~8 minutos**

## Monitoreo y Observabilidad

### Métricas Disponibles

```bash
# Ver recursos
kubectl top pods -n inovatech

# Ver HPA
kubectl get hpa -n inovatech

# Describir HPA
kubectl describe hpa products-service-hpa -n inovatech
```

### CloudWatch Integration (Opcional)

```bash
# Logs enviados automáticamente si EKS logging está habilitado
aws logs describe-log-groups --region us-east-1 | grep inovatech
```

## Justificación de Decisiones

### ¿Por qué EKS?

| Criterio | EKS | ECS |
|----------|-----|-----|
| Portabilidad | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Comunidad | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Escalabilidad | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Complejidad | ⭐⭐⭐⭐ | ⭐⭐ |
| Multi-cloud | ⭐⭐⭐⭐⭐ | ❌ |

**Conclusión:** EKS es la opción correcta para escala, portabilidad y futuro.

### ¿Por qué Microservicios?

- **Escalabilidad Independiente:** Products puede escalar sin tocar Orders
- **Despliegues Independientes:** Actualizar un servicio sin afectar otros
- **Equipos Autónomos:** Cada equipo posee su microservicio
- **Tolerancia a Fallos:** Fallo en Orders no derriba Products

### ¿Por qué Node.js?

- Livianos (bajo footprint)
- Rápidos de iniciar (importante en Kubernetes)
- Excelente para I/O (APIs REST)
- Fácil de escalar horizontalmente

### ¿Por qué MySQL?

- Datos relacionales bien definidos
- Fiable y probado
- Soporte nativo en Kubernetes
- Fácil de respaldar y recuperar

## Métricas de Éxito

| KPI | Target | Método |
|-----|--------|--------|
| Disponibilidad | 99.9% | Monitoreo CloudWatch |
| P95 Latencia | < 200ms | Application Insights |
| Error Rate | < 1% | Application Logs |
| Deployment Frequency | 1-2 por día | GitHub Actions metrics |
| Lead Time | < 10 min | GitHub Actions metrics |
| MTTR | < 5 min | Manual + Alertas |

## Roadmap Futuro

1. **Observabilidad Avanzada:** Prometheus + Grafana
2. **Service Mesh:** Istio para control de tráfico
3. **Ingress Avanzado:** Cert-manager para HTTPS
4. **Database Replication:** Multi-AZ MySQL
5. **Disaster Recovery:** Backups automatizados
6. **Performance:** Redis cache para productos
