# 🐳 Docker Mastery Guide for PostgreSQL Lab

> **From Zero to Docker Hero** - Understanding containers, networking, and orchestration through real PostgreSQL examples

## 🎯 What You'll Learn

- Docker fundamentals: containers, images, volumes, networks
- Docker Compose orchestration for multi-service applications
- PostgreSQL-specific Docker patterns
- Production-ready container strategies
- Debugging and troubleshooting techniques

---

## 📚 Docker Fundamentals

### What is Docker?
Docker packages applications into **containers** - lightweight, portable environments that include everything needed to run your app:
- Application code
- Runtime dependencies
- System libraries
- Environment variables

### Key Concepts

| Concept | Definition | Example |
|---------|------------|---------|
| **Image** | Blueprint for creating containers | `postgres:16`, `redis:7-alpine` |
| **Container** | Running instance of an image | Your database server running |
| **Volume** | Persistent storage for containers | Database data that survives restarts |
| **Network** | Communication layer between containers | PostgreSQL talking to Redis |
| **Port** | Access point from host to container | `5432:5432` (host:container) |

---

## 🔍 Analyzing Our PostgreSQL Lab Setup

Let's break down our `docker-compose.yml` line by line:

### 1. Version and Services Declaration
```yaml
version: '3.8'  # Docker Compose file format version

services:       # Define all containers in our stack
```

### 2. PostgreSQL Primary Database
```yaml
postgres-primary:
  image: pgvector/pgvector:pg16           # Pre-built image with PostgreSQL + pgvector extension
  container_name: postgres-primary        # Custom name (instead of auto-generated)
  environment:                           # Environment variables passed to container
    POSTGRES_DB: mastery_lab             # Database name to create
    POSTGRES_USER: postgres              # Superuser name
    POSTGRES_PASSWORD: postgres_password # Superuser password
  ports:
    - "5432:5432"                       # Map host port 5432 to container port 5432
  volumes:
    - postgres_primary_data:/var/lib/postgresql/data  # Named volume for data persistence
    - ./scripts/init:/docker-entrypoint-initdb.d      # Mount local scripts for initialization
  networks:
    - postgres_network                   # Connect to custom network
  healthcheck:                          # Container health monitoring
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**🧠 Key Learning Points:**
- **Image Selection**: `pgvector/pgvector:pg16` includes PostgreSQL + AI vector extension
- **Port Mapping**: `host:container` format allows external access
- **Volume Types**: Named volumes persist data, bind mounts share files
- **Health Checks**: Docker monitors if PostgreSQL is ready to accept connections

### 3. Read Replica Setup
```yaml
postgres-replica:
  image: pgvector/pgvector:pg16
  ports:
    - "5433:5432"                       # Different host port to avoid conflicts
  depends_on:
    postgres-primary:
      condition: service_healthy        # Wait for primary to be healthy before starting
  command: >                           # Override default container command
    bash -c "
    pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P
    echo 'standby_mode = on' >> /var/lib/postgresql/data/postgresql.conf
    postgres
    "
```

**🧠 Key Learning Points:**
- **Service Dependencies**: `depends_on` controls startup order
- **Command Override**: Replace default behavior with custom setup
- **Container Communication**: Services can talk using service names as hostnames

### 4. Supporting Services
```yaml
redis:
  image: redis:7-alpine               # Alpine Linux = smaller, secure base image
  command: redis-server --appendonly yes  # Enable persistent storage

pgadmin:
  image: dpage/pgadmin4:latest
  environment:
    PGADMIN_DEFAULT_EMAIL: admin@masterylab.com
    PGADMIN_CONFIG_SERVER_MODE: 'False'  # Single-user mode
  volumes:
    - ./scripts/pgadmin-servers.json:/pgadmin4/servers.json  # Pre-configure servers
```

### 5. Monitoring Stack
```yaml
prometheus:
  volumes:
    - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
```

**🧠 Key Learning Points:**
- **Configuration Files**: Mount config files from host to container
- **Command Arguments**: Pass runtime parameters to applications
- **Data Persistence**: Separate config (bind mount) from data (named volume)

---

## 🛠️ Essential Docker Commands

### Basic Container Operations

```bash
# Build and start all services
docker-compose up -d

# View running containers
docker-compose ps
docker ps

# View logs
docker-compose logs postgres-primary
docker logs postgres-primary --follow

# Execute commands in running container
docker-compose exec postgres-primary psql -U postgres -d mastery_lab
docker exec -it postgres-primary bash

# Stop and remove everything
docker-compose down
docker-compose down -v  # Also remove volumes (DANGER: deletes data)

# Restart specific service
docker-compose restart postgres-primary
```

### Debugging and Inspection

```bash
# Inspect container details
docker inspect postgres-primary

# View container resource usage
docker stats

# Check container processes
docker-compose top postgres-primary

# View volume details
docker volume ls
docker volume inspect postgresql-mastery-lab_postgres_primary_data

# Network inspection
docker network ls
docker network inspect postgresql-mastery-lab_postgres_network
```

### Image Management

```bash
# List images
docker images

# Pull latest image
docker pull pgvector/pgvector:pg16

# Remove unused images
docker image prune

# Build custom image (if you have a Dockerfile)
docker build -t my-postgres .

# Tag and push image
docker tag my-postgres registry.com/my-postgres:v1.0
docker push registry.com/my-postgres:v1.0
```

### Advanced Operations

```bash
# Scale services (for load testing)
docker-compose up --scale api-server=3

# Override compose file for different environments
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up

# Create network manually
docker network create postgres_network

# Run one-off commands
docker-compose run --rm postgres-primary pg_dump -U postgres mastery_lab
```

---

## 🏗️ Docker Compose Patterns Explained

### 1. Multi-Container Applications
Our lab demonstrates a **microservices architecture**:
```
PostgreSQL (Primary) ←→ Application Server ←→ Redis (Cache)
       ↓
PostgreSQL (Replica)  ←→ Monitoring (Prometheus/Grafana)
```

### 2. Data Persistence Strategies

```yaml
volumes:
  # Named volumes - managed by Docker, survive container deletion
  postgres_primary_data:     # PostgreSQL data directory
  redis_data:                # Redis persistence
  
  # Bind mounts - link host directories to container paths
  - ./scripts:/scripts       # Development: edit files on host
  - /var/log:/app/logs      # Production: centralized logging
```

### 3. Network Communication

```yaml
networks:
  postgres_network:          # Isolated network for our services
    driver: bridge          # Default network type
```

**How it works:**
- All services on same network can communicate using service names
- `postgres-primary:5432` resolves to the PostgreSQL container
- External access only through published ports

### 4. Environment-Based Configuration

```yaml
# Development
environment:
  NODE_ENV: development
  DATABASE_URL: postgresql://postgres:password@postgres-primary:5432/mastery_lab

# Production (override with docker-compose.prod.yml)
environment:
  NODE_ENV: production
  DATABASE_URL: ${DATABASE_URL}  # From environment variable
```

---

## 🚨 Common Issues and Solutions

### 1. Port Conflicts
**Problem**: `Port 5432 already in use`
```bash
# Check what's using the port
netstat -tulpn | grep :5432
lsof -i :5432

# Kill conflicting process or change port mapping
ports:
  - "5433:5432"  # Use different host port
```

### 2. Volume Permissions
**Problem**: `Permission denied` when mounting volumes
```bash
# Fix ownership (Linux/Mac)
sudo chown -R 999:999 ./postgres_data

# Or use named volumes instead of bind mounts
volumes:
  - postgres_data:/var/lib/postgresql/data  # Let Docker manage permissions
```

### 3. Container Won't Start
**Problem**: Container exits immediately
```bash
# Check container logs
docker-compose logs service-name

# Run container interactively to debug
docker run -it --rm pgvector/pgvector:pg16 bash

# Check if ports are available
docker-compose ps
```

### 4. Database Connection Issues
**Problem**: `Connection refused` from application
```bash
# Verify PostgreSQL is ready
docker-compose exec postgres-primary pg_isready -U postgres

# Check network connectivity
docker-compose exec api-server ping postgres-primary

# Verify environment variables
docker-compose exec api-server env | grep DATABASE
```

---

## 🎯 Best Practices for Production

### 1. Security
```yaml
# Use secrets for sensitive data
secrets:
  db_password:
    file: ./secrets/db_password.txt

services:
  postgres:
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

### 2. Resource Limits
```yaml
services:
  postgres-primary:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
```

### 3. Health Checks
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### 4. Logging Configuration
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

## 🧪 Hands-On Exercises

### Exercise 1: Explore Container Internals
```bash
# 1. Start the lab environment
docker-compose up -d postgres-primary

# 2. Connect to PostgreSQL container
docker-compose exec postgres-primary bash

# 3. Explore the filesystem
ls -la /var/lib/postgresql/data
ps aux
cat /etc/postgresql/postgresql.conf

# 4. Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql.log

# 5. Exit container
exit
```

### Exercise 2: Database Backup and Restore
```bash
# 1. Create a backup
docker-compose exec postgres-primary pg_dump -U postgres mastery_lab > backup.sql

# 2. Copy file from container to host
docker cp postgres-primary:/backup.sql ./backup.sql

# 3. Restore to new database
docker-compose exec postgres-primary createdb -U postgres test_restore
docker-compose exec postgres-primary psql -U postgres test_restore < backup.sql
```

### Exercise 3: Scale and Load Balance
```bash
# 1. Scale API servers
docker-compose up --scale api-server=3

# 2. Check running instances
docker-compose ps api-server

# 3. Test load distribution (if you have a load balancer)
for i in {1..10}; do curl http://localhost:3000/health; done
```

---

## 📚 Advanced Topics

### 1. Multi-Stage Builds
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage
FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### 2. Docker Swarm (Orchestration)
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml postgres-lab

# Scale services
docker service scale postgres-lab_api-server=5
```

### 3. Custom Networks
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

services:
  web:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend  # Only internal access
```

---

## 🎉 Congratulations!

You now understand:
- ✅ Docker fundamentals and PostgreSQL container patterns
- ✅ Docker Compose orchestration for complex applications
- ✅ Volume management and data persistence
- ✅ Network communication between services
- ✅ Debugging and troubleshooting techniques
- ✅ Production best practices

**Next Steps:**
1. Practice with the PostgreSQL lab exercises
2. Experiment with different container configurations
3. Learn Kubernetes for production orchestration
4. Explore Docker security scanning and optimization

---

**Remember**: Docker is about consistency, portability, and isolation. Every environment (dev, staging, prod) runs the same way! 🚀
