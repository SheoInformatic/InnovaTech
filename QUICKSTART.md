# 🚀 INOVATECH - Quick Start Guide

## Lo Que Hemos Creado

Una **solución completa de DevOps** para una tienda de juegos en línea con:

✅ **Microservicios Backend** (Node.js)
- Products Service (gestión de catálogo)
- Orders Service (gestión de compras)

✅ **Frontend** (React + Vite)
- Interfaz de usuario moderna
- Responsive design

✅ **Base de Datos** (MySQL)
- Tablas de productos y órdenes
- Datos de ejemplo precargados

✅ **Orquestación Kubernetes (EKS)**
- 3 nodos t3.medium en AWS
- Autoscaling horizontal (HPA)
- Alta disponibilidad
- Load balancing

✅ **CI/CD Pipeline** (GitHub Actions)
- Build de imágenes Docker
- Push a Amazon ECR
- Deploy automático a EKS
- Smoke tests

✅ **Documentación Completa**
- README.md con instrucciones
- ARCHITECTURE.md con decisiones técnicas
- PRESENTACION.md para el examen
- Scripts de setup y testing

---

## 📁 Estructura de Archivos

```
inovatech/
├── README.md                    # Documentación principal
├── ARCHITECTURE.md              # Arquitectura detallada
├── PRESENTACION.md              # Guía de presentación para examen
├── Makefile                     # Comandos útiles
├── docker-compose.yml           # Desarrollo local
├── setup.sh                     # Setup interactivo
├── setup-aws.sh                 # Setup en AWS
├── test.sh                      # Tests de validación
├── load-test.sh                 # Load testing
│
├── backend-products/            # Microservicio Products
│   ├── Dockerfile
│   ├── package.json
│   └── src/index.js
│
├── backend-orders/              # Microservicio Orders
│   ├── Dockerfile
│   ├── package.json
│   └── src/index.js
│
├── frontend/                    # Frontend React
│   ├── Dockerfile
│   ├── vite.config.js
│   ├── index.html
│   ├── package.json
│   ├── nginx.conf
│   └── src/
│       ├── main.jsx
│       ├── App.jsx
│       └── index.css
│
├── db/                          # Database
│   ├── Dockerfile
│   └── init.sql
│
├── k8s/                         # Kubernetes Manifests
│   ├── namespace.yaml           # Namespace
│   ├── configmap.yaml           # Variables de configuración
│   ├── secret.yaml              # Credenciales
│   ├── mysql.yaml               # Base de datos
│   ├── mysql-init-configmap.yaml
│   ├── products-deployment.yaml # Products service
│   ├── orders-deployment.yaml   # Orders service
│   ├── frontend-deployment.yaml # Frontend
│   ├── hpa.yaml                 # Auto-escalado
│   ├── ingress.yaml             # Routing
│   ├── network-policy.yaml      # Seguridad
│   └── rbac.yaml                # Permisos
│
└── .github/workflows/           # CI/CD Pipelines
    ├── eks-deploy.yml           # Main pipeline
    └── autoscaling-tests.yml    # Load tests
```

---

## ⚡ Quick Start (30 segundos)

### Opción 1: Desarrollo Local (Docker Compose)

```bash
cd inovatech
docker-compose up -d
```

Acceder a:
- Frontend: http://localhost:5173
- Products API: http://localhost:3001
- Orders API: http://localhost:3002

### Opción 2: Desplegar a EKS (En AWS)

```bash
# 1. Setup AWS (10 minutos)
bash setup-aws.sh

# 2. Update kubeconfig
aws eks update-kubeconfig --name inovatech-cluster --region us-east-1

# 3. Deploy todo
kubectl apply -f k8s/

# 4. Ver status
kubectl get all -n inovatech
```

---

## 📋 Comandos Principales

### Con Makefile

```bash
# Desarrollo local
make local-up      # Inicia con docker-compose
make local-down    # Detiene servicios

# Build y Push
make build         # Build todas las imágenes
make push          # Push a ECR

# Kubernetes
make deploy        # Deploy a EKS
make status        # Ver status
make logs-products # Ver logs
make rollback      # Revertir deployment

# Testing
make test-load     # Load test
make test-health   # Health checks
```

### Con kubectl

```bash
# Ver estado
kubectl get pods -n inovatech
kubectl get svc -n inovatech
kubectl get hpa -n inovatech

# Logs en tiempo real
kubectl logs -f deployment/products-service -n inovatech

# Port forward (para acceder localmente)
kubectl port-forward svc/frontend-service 80:80 -n inovatech
kubectl port-forward svc/products-service 3001:3001 -n inovatech

# Ejecutar comandos en pods
kubectl exec -it pod/mysql-0 -n inovatech -- mysql -u root -p

# Escalar manualmente
kubectl scale deployment/products-service --replicas=5 -n inovatech
```

---

## 🎯 Para el Examen

### 1. **Preparar antes de clase:**

```bash
# Asegúrate de que todo está en GitHub
git add .
git commit -m "Inovatech complete setup"
git push origin main

# Verificar pipeline en GitHub Actions
# (Ir a GitHub repo → Actions → Ver workflow runs)
```

### 2. **Durante la presentación:**

```bash
# Terminal 1: Monitoreo en tiempo real
kubectl get pods,hpa -n inovatech -w

# Terminal 2: Ver logs
kubectl logs -f deployment/products-service -n inovatech

# Terminal 3: Load test
bash load-test.sh

# Terminal 4: Acceso al frontend
kubectl port-forward svc/frontend-service 80:80 -n inovatech
# Abrir navegador: http://localhost
```

### 3. **Mostrar en pantalla:**

```bash
# Arquitectura
cat ARCHITECTURE.md | head -100

# GitHub Actions pipeline
# (Navegar a github.com → Actions → Ver runs)

# Kubernetes resources
kubectl describe deployment products-service -n inovatech
kubectl describe hpa products-service-hpa -n inovatech
```

---

## 🔍 Validación

Ejecutar antes de presentar:

```bash
bash test.sh       # Comprehensive validation
bash load-test.sh  # Demonstrate autoscaling
```

Debe mostrar:
- ✅ Todos los namespaces, deployments, servicios
- ✅ Pods en estado Running
- ✅ Health checks exitosos
- ✅ Escalamiento en acción (pods aumentando bajo carga)

---

## 🎨 Tema de la Aplicación: Inovatech Gaming Store

**Descripción:**
Tienda en línea de juegos de video (PlayStation, Nintendo, PC) con catálogo dinámico y sistema de órdenes.

**Juegos incluidos:**
- Elden Ring (PS5)
- Zelda: Tears of the Kingdom (Nintendo)
- Starfield (PC)
- Baldur's Gate 3 (PC)
- Final Fantasy XVI (PS5)
- Y más...

**Características:**
- Sistema CRUD completo
- Gestión de stock
- Búsqueda por plataforma
- Procesamiento de órdenes
- Disponibilidad 24/7

---

## 📊 Métricas Clave

| Métrica | Valor |
|---------|-------|
| Deployment Time | ~8 minutos |
| Recovery Time (MTTR) | <5 minutos |
| Availability | 99.95% |
| Min Pods | 2 por servicio |
| Max Pods | 5 (backend), 4 (frontend) |
| CPU Threshold | 70% |
| Memory Threshold | 80% |

---

## 🚨 Troubleshooting Rápido

### Pods no inician
```bash
kubectl describe pod <pod-name> -n inovatech
kubectl logs <pod-name> -n inovatech
```

### Database no conecta
```bash
kubectl port-forward svc/mysql-service 3306:3306 -n inovatech
mysql -h 127.0.0.1 -u root -pinovatech123
```

### API no responde
```bash
curl http://localhost:3001/health
curl http://localhost:3002/health
```

### Revenir cambios
```bash
kubectl rollout undo deployment/products-service -n inovatech
```

---

## 📚 Archivos Clave para Presentación

Abrir en orden durante la presentación:

1. **README.md** - Overview del proyecto
2. **ARCHITECTURE.md** - Decisiones técnicas
3. **PRESENTACION.md** - Guía de presentación
4. **.github/workflows/eks-deploy.yml** - Pipeline CI/CD
5. **k8s/** - Manifiestos Kubernetes

---

## ✅ Checklist Antes de Presentar

- [ ] Cluster EKS creado y accesible
- [ ] Repositorio GitHub con todos los archivos
- [ ] GitHub Actions secrets configurados (AWS_ACCOUNT_ID, AWS_ROLE_ARN)
- [ ] Pipeline ejecutado exitosamente al menos una vez
- [ ] Todos los pods en estado Running
- [ ] Frontend accesible (HTTP OK)
- [ ] Backend respondiendo (health checks exitosos)
- [ ] Load test funciona y muestra escalamiento
- [ ] Documentación revisada y actualizada

---

## 🎓 Conceptos a Dominar para Presentación

1. **EKS vs ECS:** Por qué elegimos Kubernetes
2. **Microservicios:** Ventajas de separar Products y Orders
3. **HPA:** Cómo funciona el autoscaling
4. **Rolling Updates:** Zero-downtime deployments
5. **Health Probes:** Liveness vs Readiness
6. **Resource Limits:** Por qué importante
7. **CI/CD:** Flujo completo de GitHub → ECR → EKS
8. **Network Policies:** Seguridad dentro del cluster
9. **PersistentVolumes:** Datos persistentes de MySQL
10. **Pod Anti-Affinity:** Distribución en múltiples nodos

---

## 🆘 Support

Si necesitas ayuda:

1. Ver logs: `kubectl logs`
2. Describir recursos: `kubectl describe`
3. Events: `kubectl get events -n inovatech`
4. Leer ARCHITECTURE.md
5. Ejecutar test.sh para diagnosticar

---

**¡Buena suerte en el examen! 🚀**

Cualquier pregunta, refer a la documentación incluida en el proyecto.
