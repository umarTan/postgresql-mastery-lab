# 🐳 Docker Quick Reference Cheat Sheet

## 🚀 Essential Commands

### Container Lifecycle
```bash
# Start services
docker-compose up                    # Foreground
docker-compose up -d                 # Background (detached)
docker-compose up postgres-primary   # Start specific service

# Stop services
docker-compose stop                  # Stop all services
docker-compose stop postgres-primary # Stop specific service
docker-compose down                  # Stop and remove containers
docker-compose down -v               # Stop, remove containers AND volumes

# Restart services
docker-compose restart               # Restart all
docker-compose restart postgres-primary # Restart specific
```

### Monitoring and Logs
```bash
# View running containers
docker-compose ps                    # Compose services
docker ps                          # All containers
docker ps -a                       # Include stopped containers

# View logs
docker-compose logs                 # All services
docker-compose logs postgres-primary # Specific service
docker-compose logs -f postgres-primary # Follow logs (real-time)
docker-compose logs --tail=50 postgres-primary # Last 50 lines
```

### Execute Commands
```bash
# Interactive shell
docker-compose exec postgres-primary bash
docker-compose exec postgres-primary psql -U postgres

# One-off commands
docker-compose exec postgres-primary pg_dump -U postgres mastery_lab
docker-compose run --rm postgres-primary pg_isready
```

### Development Workflow
```bash
# Rebuild and restart
docker-compose build                # Rebuild images
docker-compose up --build          # Build and start
docker-compose up --force-recreate # Recreate containers

# Scale services
docker-compose up --scale api-server=3

# Override files for different environments
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

---

## 📁 File Structure Understanding

### Our PostgreSQL Lab Structure
```
postgresql-mastery-lab/
├── docker-compose.yml              # Main orchestration file
├── .env                           # Environment variables (create this)
├── scripts/                       # Initialization scripts
│   ├── init/                     # PostgreSQL init scripts
│   ├── postgresql.conf           # PostgreSQL configuration
│   └── setup-replica.sh         # Replica setup script
├── monitoring/                    # Monitoring configurations
│   ├── grafana/
│   └── prometheus/
└── src/                          # Application source code
    └── Dockerfile               # Application container definition
```

### Creating Environment File (.env)
```bash
# Create .env file for sensitive data
cat > .env << EOF
POSTGRES_PASSWORD=your_secure_password
POSTGRES_REPLICATION_PASSWORD=replication_password
PGADMIN_DEFAULT_PASSWORD=admin_secure_password
GRAFANA_ADMIN_PASSWORD=grafana_secure_password
EOF
```

---

## 🔧 Debugging Toolkit

### Container Inspection
```bash
# Container details
docker inspect postgres-primary
docker-compose exec postgres-primary env    # Environment variables
docker-compose top postgres-primary         # Running processes

# Resource usage
docker stats                               # Real-time stats
docker system df                          # Disk usage
docker system events                      # System events
```

### Network Debugging
```bash
# List networks
docker network ls

# Inspect network
docker network inspect postgresql-mastery-lab_postgres_network

# Test connectivity between containers
docker-compose exec api-server ping postgres-primary
docker-compose exec api-server nslookup postgres-primary
```

### Volume Management
```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect postgresql-mastery-lab_postgres_primary_data

# Backup volume data
docker run --rm -v postgresql-mastery-lab_postgres_primary_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .

# Restore volume data
docker run --rm -v postgresql-mastery-lab_postgres_primary_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /data
```

---

## 🛠️ Common Patterns in Our Setup

### 1. Service Dependencies
```yaml
depends_on:
  postgres-primary:
    condition: service_healthy    # Wait for health check to pass
```

### 2. Port Mapping Patterns
```yaml
ports:
  - "5432:5432"    # PostgreSQL primary
  - "5433:5432"    # PostgreSQL replica (different host port)
  - "8080:80"      # pgAdmin (container runs on 80, we access via 8080)
```

### 3. Volume Patterns
```yaml
volumes:
  # Named volume (Docker managed)
  - postgres_primary_data:/var/lib/postgresql/data
  
  # Bind mount (host directory)
  - ./scripts/init:/docker-entrypoint-initdb.d
  
  # Configuration file
  - ./scripts/postgresql.conf:/etc/postgresql/postgresql.conf
```

### 4. Environment Variable Patterns
```yaml
environment:
  # Direct values
  POSTGRES_DB: mastery_lab
  
  # From .env file
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  
  # Service discovery
  DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres-primary:5432/mastery_lab
```

---

## 🚨 Troubleshooting Guide

### Problem: "Port already in use"
```bash
# Check what's using the port
netstat -tulpn | grep :5432
lsof -i :5432

# Solutions:
# 1. Stop conflicting service
sudo systemctl stop postgresql

# 2. Change port mapping
ports:
  - "5433:5432"
```

### Problem: "Container exits immediately"
```bash
# Check logs for error messages
docker-compose logs postgres-primary

# Run container interactively to debug
docker run -it --rm pgvector/pgvector:pg16 bash

# Check if all required files exist
ls -la ./scripts/postgresql.conf
```

### Problem: "Permission denied" on volumes
```bash
# For PostgreSQL data directory (Linux/Mac)
sudo chown -R 999:999 ./postgres_data

# Or use named volumes instead of bind mounts
volumes:
  - postgres_data:/var/lib/postgresql/data  # Docker handles permissions
```

### Problem: "Cannot connect to database"
```bash
# 1. Check if PostgreSQL is ready
docker-compose exec postgres-primary pg_isready -U postgres

# 2. Verify container is running
docker-compose ps postgres-primary

# 3. Check network connectivity from app
docker-compose exec api-server ping postgres-primary

# 4. Verify environment variables
docker-compose exec api-server env | grep DATABASE
```

### Problem: "Out of disk space"
```bash
# Clean up unused resources
docker system prune                    # Remove unused containers, networks, images
docker system prune -a                # Also remove unused images
docker volume prune                   # Remove unused volumes (CAREFUL!)

# Check disk usage
docker system df
```

---

## 🎯 Production Readiness Checklist

### Security
- [ ] Use secrets instead of environment variables for passwords
- [ ] Run containers as non-root user
- [ ] Use specific image tags, not `latest`
- [ ] Scan images for vulnerabilities
- [ ] Enable Docker Content Trust

### Performance
- [ ] Set resource limits (CPU, memory)
- [ ] Configure proper restart policies
- [ ] Use multi-stage builds to reduce image size
- [ ] Enable health checks for all services

### Monitoring
- [ ] Configure centralized logging
- [ ] Set up metrics collection
- [ ] Implement alerting rules
- [ ] Monitor container resource usage

### Backup & Recovery
- [ ] Regular database backups
- [ ] Test restore procedures
- [ ] Document recovery processes
- [ ] Store backups securely off-site

---

## 📚 Learning Path

### Beginner → Intermediate
1. ✅ Master docker-compose basics (this guide)
2. Learn Dockerfile creation and optimization
3. Understand networking and security
4. Practice with CI/CD pipelines

### Intermediate → Advanced
1. Learn Kubernetes orchestration
2. Implement service mesh (Istio)
3. Master container security scanning
4. Design multi-environment strategies

### Pro Tips
- Always use `.dockerignore` to exclude unnecessary files
- Pin image versions for reproducibility (`postgres:16.1` not `postgres:latest`)
- Use health checks to ensure service reliability
- Implement graceful shutdown handling
- Monitor container performance metrics

---

## 🔗 Quick Links

- **PostgreSQL Lab**: Start with `docker-compose up -d`
- **pgAdmin**: http://localhost:8080 (admin@masterylab.com/admin_password)
- **Grafana**: http://localhost:3001 (admin/grafana_password)
- **Prometheus**: http://localhost:9090
- **Full Guide**: [DOCKER_GUIDE.md](./DOCKER_GUIDE.md)

---

**🎯 Remember**: Docker is about consistency across environments. The same setup works on your laptop, CI/CD, and production! 🚀
