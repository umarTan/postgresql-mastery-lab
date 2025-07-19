# 🚀 Getting Started with PostgreSQL Mastery Lab

## Quick Setup

```bash
# 1. Clone the repository
git clone https://github.com/umarTan/postgresql-mastery-lab.git
cd postgresql-mastery-lab

# 2. Start the lab environment
docker-compose up -d

# 3. Wait for services to be ready (check with)
docker-compose ps

# 4. Connect to PostgreSQL
psql postgresql://postgres:postgres_password@localhost:5432/mastery_lab
```

## 🎯 Your 30-Day Journey Starts Here

### Day 1-2: Begin with Advanced Schema Design
Navigate to your first exercise:
```bash
cd exercises/week1/day1-schema-design
```

Follow the README and run the SQL files in order:
1. `01-foundation-schema.sql` - Core multi-tenant tables
2. `02-rls-policies.sql` - Row-Level Security implementation

## 📊 Lab Environment Access

Once Docker containers are running, access:

- **PostgreSQL**: `localhost:5432` (postgres/postgres_password)
- **pgAdmin**: http://localhost:8080 (admin@masterylab.com/admin_password)
- **Grafana**: http://localhost:3001 (admin/grafana_password)
- **Prometheus**: http://localhost:9090
- **Redis**: `localhost:6379`

## 🎖️ Success Metrics

Track your progress:
- [ ] Complete foundation schema (Day 1)
- [ ] Implement RLS policies (Day 2)
- [ ] Master JSONB optimization (Week 1)
- [ ] Build scalable partitioning (Week 2)
- [ ] Integrate AI features (Week 3)
- [ ] Deploy production system (Week 4)

## 🔄 Daily Workflow

1. **Morning**: Review theory in exercise README
2. **Practice**: Complete hands-on SQL exercises
3. **Experiment**: Try performance variations
4. **Document**: Update your learning journal

## 🆘 Need Help?

- **Issues**: [GitHub Issues](https://github.com/umarTan/postgresql-mastery-lab/issues)
- **Discussions**: [GitHub Discussions](https://github.com/umarTan/postgresql-mastery-lab/discussions)
- **Study Plan**: [Detailed Curriculum](STUDY_PLAN.md)

---

**Ready to master PostgreSQL?** 

👉 Start with [Day 1-2: Advanced Schema Design](exercises/week1/day1-schema-design/README.md)

Good luck on your journey to becoming a PostgreSQL Systems Architect! 🐘