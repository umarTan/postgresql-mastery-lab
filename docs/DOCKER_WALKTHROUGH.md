# 🎓 Docker Learning Journey: PostgreSQL Lab Walkthrough

> **Learn Docker by Building a Real Production Stack** - From beginner concepts to advanced orchestration

## 🎯 What We're Building

Our PostgreSQL Mastery Lab is a **multi-service architecture** that demonstrates real-world Docker patterns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   pgAdmin       │    │   Grafana       │    │   Prometheus    │
│   (Management)  │    │   (Dashboards)  │    │   (Metrics)     │
│   Port: 8080    │    │   Port: 3001    │    │   Port: 9090    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Network       │
                    │ postgres_network│
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │◄──►│   App Server    │◄──►│     Redis       │
│   (Primary)     │    │   (API/Web)     │    │   (Cache)       │
│   Port: 5432    │    │   Port: 3000    │    │   Port: 6379    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐
│   PostgreSQL    │
│   (Replica)     │
│   Port: 5433    │
└─────────────────┘
```

## 📚 Docker Concepts Through Our Lab

### 1. Understanding the docker-compose.yml Structure

```yaml
version: '3.8'  # ← Compose file format version
                #   Determines available features

services:       # ← All containers in our application
  postgres-primary:    # ← Service name (becomes hostname)
  redis:              # ← Another service
  # ... more services

volumes:        # ← Persistent storage definitions
networks:       # ← Custom network definitions
```

**🧠 Key Insight**: Docker Compose treats your entire application as a "stack" of interconnected services.

### 2. Service Definition Breakdown

Let's analyze our PostgreSQL primary service step by step:

```yaml
postgres-primary:                    # Service name
  image: pgvector/pgvector:pg16     # ← Docker image to use
  container_name: postgres-primary   # ← Custom container name
  environment:                      # ← Environment variables
    POSTGRES_DB: mastery_lab
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres_password
  ports:                           # ← Port mapping
    - "5432:5432"                 # host:container
  volumes:                         # ← Storage mounting
    - postgres_primary_data:/var/lib/postgresql/data
    - ./scripts/init:/docker-entrypoint-initdb.d
  networks:                        # ← Network attachment
    - postgres_network
  healthcheck:                     # ← Health monitoring
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### 3. Image Selection Strategy

```yaml
# Different image choices and their implications:

image: postgres:16                 # Official PostgreSQL
image: pgvector/pgvector:pg16     # PostgreSQL + AI vector extension
image: postgres:16-alpine         # Smaller, minimal variant
image: postgres:16.1              # Specific version (recommended for prod)
```

**🧠 Why pgvector/pgvector:pg16?**
- Includes PostgreSQL 16 + pgvector extension for AI features
- Pre-compiled and optimized
- Saves us from building custom images

### 4. Port Mapping Explained

```yaml
ports:
  - "5432:5432"    # Format: "host_port:container_port"
  - "8080:80"      # pgAdmin runs on 80 inside, we access via 8080
  - "5433:5432"    # Replica uses different host port to avoid conflict
```

**🧠 Port Mapping Rules:**
- Host port must be unique across all services
- Container port can be the same (they're isolated)
- External access only through mapped ports

### 5. Volume Types and Use Cases

```yaml
volumes:
  # Named Volume - Docker managed, survives container deletion
  - postgres_primary_data:/var/lib/postgresql/data
  
  # Bind Mount - Links host directory to container
  - ./scripts/init:/docker-entrypoint-initdb.d
  
  # Configuration File Mount
  - ./scripts/postgresql.conf:/etc/postgresql/postgresql.conf
```

**🧠 When to Use Each:**
- **Named Volumes**: Database data, cache files (Docker manages location)
- **Bind Mounts**: Config files, source code, logs (you control location)
- **tmpfs**: Temporary data in memory (not persisted)

### 6. Environment Variables Patterns

```yaml
environment:
  # Direct assignment
  POSTGRES_DB: mastery_lab
  
  # From .env file (recommended for secrets)
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  
  # Service discovery pattern
  DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres-primary:5432/mastery_lab
  #                                                     ↑
  #                                         Service name becomes hostname
```

### 7. Service Dependencies

```yaml
depends_on:
  postgres-primary:
    condition: service_healthy  # Wait for health check to pass
```

**🧠 Dependency Types:**
- `service_started`: Wait for container to start (default)
- `service_healthy`: Wait for health check to pass (better)
- `service_completed_successfully`: For init containers

### 8. Health Checks Deep Dive

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]  # Command to run
  interval: 10s      # How often to check
  timeout: 5s        # Max time for check to complete
  retries: 5         # Attempts before marking unhealthy
  start_period: 60s  # Grace period after container starts
```

**🧠 Health Check Benefits:**
- Ensures service is actually ready (not just started)
- Enables proper dependency management
- Production load balancers can use this info

---

## 🔍 Docker Compose Commands Explained

### Starting Services

```bash
# Start all services in foreground (see logs)
docker-compose up

# Start in background (detached mode)
docker-compose up -d

# Start specific service and its dependencies
docker-compose up postgres-primary

# Rebuild images before starting
docker-compose up --build

# Force recreate containers (ignores cache)
docker-compose up --force-recreate
```

### Monitoring Services

```bash
# Check status of all services
docker-compose ps

# View logs from all services
docker-compose logs

# Follow logs from specific service
docker-compose logs -f postgres-primary

# View last 50 lines of logs
docker-compose logs --tail=50 postgres-primary
```

### Executing Commands

```bash
# Interactive shell in running container
docker-compose exec postgres-primary bash

# Run PostgreSQL client
docker-compose exec postgres-primary psql -U postgres -d mastery_lab

# Run one-off command
docker-compose run --rm postgres-primary pg_dump -U postgres mastery_lab
```

### Stopping and Cleanup

```bash
# Stop all services (containers remain)
docker-compose stop

# Stop and remove containers, networks
docker-compose down

# Also remove volumes (DANGER: deletes data!)
docker-compose down -v

# Remove only specific service
docker-compose rm postgres-primary
```

---

## 🛠️ Hands-On Docker Exercises

### Exercise 1: Container Lifecycle
```bash
# 1. Start only PostgreSQL
docker-compose up -d postgres-primary

# 2. Check if it's running
docker-compose ps
docker-compose logs postgres-primary

# 3. Connect and explore
docker-compose exec postgres-primary bash
ls -la /var/lib/postgresql/data
ps aux | grep postgres
exit

# 4. Stop and remove
docker-compose stop postgres-primary
docker-compose rm postgres-primary
```

### Exercise 2: Volume Persistence
```bash
# 1. Start PostgreSQL and create data
docker-compose up -d postgres-primary
docker-compose exec postgres-primary psql -U postgres -d mastery_lab -c "CREATE TABLE test_persistence (id SERIAL PRIMARY KEY, data TEXT);"
docker-compose exec postgres-primary psql -U postgres -d mastery_lab -c "INSERT INTO test_persistence (data) VALUES ('This should survive container restart');"

# 2. Stop and remove container (but keep volumes)
docker-compose stop postgres-primary
docker-compose rm postgres-primary

# 3. Start again and check data
docker-compose up -d postgres-primary
# Wait a moment for startup
docker-compose exec postgres-primary psql -U postgres -d mastery_lab -c "SELECT * FROM test_persistence;"
# Your data should still be there!
```

### Exercise 3: Network Communication
```bash
# 1. Start PostgreSQL and Redis
docker-compose up -d postgres-primary redis

# 2. Test network connectivity
docker-compose exec postgres-primary ping redis
docker-compose exec redis ping postgres-primary

# 3. Check network details
docker network ls
docker network inspect postgresql-mastery-lab_postgres_network
```

### Exercise 4: Environment Variables
```bash
# 1. Check environment inside container
docker-compose exec postgres-primary env | grep POSTGRES

# 2. Connect using environment variables
docker-compose exec postgres-primary psql -U $POSTGRES_USER -d $POSTGRES_DB

# 3. Create .env file and test
cat > .env << EOF
POSTGRES_PASSWORD=my_secure_password
EOF

# Restart and verify
docker-compose down
docker-compose up -d postgres-primary
```

---

## 🚨 Common Issues and Solutions

### 1. "Port already in use"
```
Error: bind: address already in use
```

**Diagnosis:**
```bash
# Check what's using the port
lsof -i :5432
netstat -tulpn | grep :5432
```

**Solutions:**
```bash
# Option 1: Stop conflicting service
sudo systemctl stop postgresql

# Option 2: Change host port
ports:
  - "5433:5432"  # Use different host port

# Option 3: Use different interface
ports:
  - "127.0.0.1:5432:5432"  # Only bind to localhost
```

### 2. "Volume mount failed"
```
Error: invalid mount config for type "bind"
```

**Common Causes:**
- File/directory doesn't exist on host
- Incorrect path format (Windows vs Linux)
- Permission issues

**Solutions:**
```bash
# Create missing directories
mkdir -p ./scripts/init

# Fix permissions (Linux/Mac)
chmod 755 ./scripts/init

# Use absolute paths if relative paths fail
volumes:
  - /full/path/to/scripts:/docker-entrypoint-initdb.d
```

### 3. "Container exits immediately"
```
Exited with code 1
```

**Diagnosis:**
```bash
# Check container logs
docker-compose logs postgres-primary

# Run container interactively to debug
docker run -it --rm pgvector/pgvector:pg16 bash

# Check if required files exist
ls -la ./scripts/postgresql.conf
```

### 4. "Cannot connect to database"
```
psql: could not connect to server: Connection refused
```

**Troubleshooting Steps:**
```bash
# 1. Check if container is running
docker-compose ps postgres-primary

# 2. Check health status
docker inspect postgres-primary | grep Health

# 3. Verify PostgreSQL is ready
docker-compose exec postgres-primary pg_isready -U postgres

# 4. Check network connectivity
docker-compose exec api-server ping postgres-primary

# 5. Verify environment variables
docker-compose exec postgres-primary env | grep POSTGRES
```

---

## 🎯 Production Best Practices

### 1. Security
```yaml
# Use secrets for sensitive data
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt

services:
  postgres-primary:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
```

### 2. Resource Limits
```yaml
services:
  postgres-primary:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
        reservations:
          memory: 1G
          cpus: '1.0'
```

### 3. Logging Configuration
```yaml
services:
  postgres-primary:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
```

### 4. Health Checks
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### 5. Image Security
```yaml
# Use specific versions, not 'latest'
image: pgvector/pgvector:pg16.1  # Not pg16 or latest

# Scan images for vulnerabilities
# docker scan pgvector/pgvector:pg16
```

---

## 🚀 Advanced Docker Patterns

### 1. Multi-Environment Configuration

**docker-compose.override.yml** (automatically loaded):
```yaml
version: '3.8'
services:
  postgres-primary:
    environment:
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
```

**docker-compose.prod.yml**:
```yaml
version: '3.8'
services:
  postgres-primary:
    environment:
      POSTGRES_PASSWORD: ${PROD_PASSWORD}
    ports: []  # No external ports in production
```

Usage:
```bash
# Development (uses override automatically)
docker-compose up

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### 2. Service Scaling
```bash
# Scale API servers for load testing
docker-compose up --scale api-server=3

# Check running instances
docker-compose ps api-server
```

### 3. Init Containers Pattern
```yaml
services:
  db-migration:
    image: migrate/migrate
    command: ["-path", "/migrations", "-database", "postgres://...", "up"]
    volumes:
      - ./migrations:/migrations
    depends_on:
      postgres-primary:
        condition: service_healthy

  app:
    depends_on:
      db-migration:
        condition: service_completed_successfully
```

---

## 🎓 Graduation: You Now Understand

✅ **Docker Fundamentals**: Images, containers, volumes, networks  
✅ **Compose Orchestration**: Multi-service applications  
✅ **Service Communication**: DNS resolution, port mapping  
✅ **Data Persistence**: Volume strategies and backup  
✅ **Health Monitoring**: Health checks and dependencies  
✅ **Production Patterns**: Security, scaling, monitoring  
✅ **Debugging Skills**: Logs, inspection, troubleshooting  

## 🔄 Next Steps

1. **Practice**: Complete the PostgreSQL mastery exercises
2. **Experiment**: Modify the compose file and observe changes
3. **Learn Kubernetes**: Next level of container orchestration
4. **Docker Swarm**: Native Docker clustering
5. **CI/CD Integration**: Automate builds and deployments

---

**🎉 Congratulations! You've mastered Docker through real-world PostgreSQL patterns!** 

You can now design, deploy, and debug containerized applications with confidence. The PostgreSQL lab is your playground—experiment, break things, and learn! 🐳
