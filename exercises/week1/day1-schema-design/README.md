# Day 1-2: Advanced Schema Design

## 🎯 Objectives
- Design multi-tenant SaaS architecture for a CRM system
- Implement Row-Level Security (RLS) patterns
- Create efficient JSONB indexes and queries
- Partition tables by tenant and time

## 🚀 Quick Start

```bash
# Navigate to this exercise
cd exercises/week1/day1-schema-design

# Start the database
docker-compose up -d

# Connect to PostgreSQL
psql postgresql://postgres:postgres_password@localhost:5432/mastery_lab
```

## 📋 Exercise 1: Multi-Tenant CRM Schema Design

### Business Requirements
You're building a SaaS CRM for small businesses. Each tenant (company) needs:
- **Contacts**: Customer information with custom fields
- **Leads**: Sales opportunities with stages and values
- **Activities**: Interactions (calls, emails, meetings)
- **Users**: Team members with role-based access

### Schema Design Challenge

Create a multi-tenant schema that supports:
1. **Tenant Isolation**: Complete data separation between companies
2. **Flexibility**: Custom fields per tenant without schema changes
3. **Performance**: Sub-100ms queries on 10M+ records per tenant
4. **Security**: Row-level access control

### Step 1: Core Tables

```sql
-- Start with the foundation schema
\\i 01-foundation-schema.sql

-- Verify table structure
\\d+ tenants
\\d+ tenant_users
\\d+ contacts
\\d+ leads
```

### Step 2: Row-Level Security (RLS)

```sql
-- Implement RLS policies
\\i 02-rls-policies.sql

-- Test tenant isolation
SET app.current_tenant = 'tenant-1-uuid';
SELECT * FROM contacts; -- Should only show tenant 1 data
```

### Step 3: JSONB Custom Fields

```sql
-- Add flexible custom fields
\\i 03-jsonb-fields.sql

-- Create optimized indexes
\\i 04-jsonb-indexes.sql
```

### Step 4: Partitioning

```sql
-- Implement time-based partitioning for activities
\\i 05-partitioning.sql

-- Test partition pruning
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM activities 
WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01';
```

## 📊 Performance Benchmarks

### Target Metrics
- **Contact Search**: < 50ms for 1M contacts per tenant
- **Lead Analytics**: < 100ms for complex aggregations
- **Activity Feed**: < 25ms for recent activities
- **Tenant Switch**: < 10ms context change

### Benchmark Queries

```sql
-- Test 1: Contact search with custom fields
\\timing on
SELECT * FROM contacts 
WHERE tenant_id = $1 
  AND custom_fields @> '{"industry": "tech"}'
LIMIT 20;

-- Test 2: Lead pipeline analytics
SELECT 
  stage,
  COUNT(*) as count,
  SUM((custom_fields->>'value')::numeric) as total_value
FROM leads 
WHERE tenant_id = $1 
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY stage;

-- Test 3: Activity timeline
SELECT 
  type,
  subject,
  created_at,
  custom_fields
FROM activities 
WHERE tenant_id = $1 
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 50;
```

## 🧪 Testing Scenarios

### Scenario 1: Multi-Tenant Data Isolation

```sql
-- Create test data for 3 tenants
\\i data/seed-tenants.sql

-- Verify complete isolation
-- Each query should return 0 results for other tenants
SET app.current_tenant = 'tenant-1-uuid';
SELECT COUNT(*) FROM contacts WHERE tenant_id != 'tenant-1-uuid';
-- Expected: 0
```

### Scenario 2: Custom Fields Performance

```sql
-- Test JSONB query performance
\\i tests/jsonb-performance.sql

-- Should complete in < 100ms
SELECT COUNT(*) FROM contacts 
WHERE custom_fields @> '{"status": "active", "priority": "high"}';
```

### Scenario 3: Partition Pruning

```sql
-- Verify partition pruning works
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT COUNT(*) FROM activities 
WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31';

-- Check that only relevant partitions are scanned
```

## 🎯 Success Criteria

- [ ] All tables implement proper RLS policies
- [ ] JSONB queries use appropriate GIN indexes
- [ ] Partition pruning eliminates irrelevant partitions
- [ ] Benchmark queries meet performance targets
- [ ] Zero data leakage between tenants
- [ ] Schema supports 100+ custom fields per entity

## 🔍 Key Learning Points

### Multi-Tenant Patterns Compared

| Pattern | Pros | Cons | Use Case |
|---------|------|------|----------|
| **Shared Database + RLS** | Cost effective, simple ops | Noisy neighbor, complex queries | SMB SaaS |
| **Shared Database + Schema** | Better isolation, simple queries | More complex ops | Mid-market |
| **Separate Databases** | Complete isolation | High operational overhead | Enterprise |

### JSONB Best Practices

```sql
-- ✅ Good: Specific path queries
WHERE custom_fields->>'status' = 'active'

-- ✅ Good: Containment with indexes
WHERE custom_fields @> '{"status": "active"}'

-- ❌ Avoid: Complex nested queries without indexes
WHERE (custom_fields->'preferences'->>'theme') = 'dark'
```

### RLS Performance Tips

```sql
-- ✅ Use session variables for tenant context
SET app.current_tenant = 'uuid';

-- ✅ Ensure RLS policies use indexed columns
USING (tenant_id = current_setting('app.current_tenant')::uuid)

-- ❌ Avoid function calls in RLS policies
USING (tenant_id = get_current_tenant()) -- Slow!
```

## 📚 Additional Resources

- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [JSONB Indexing Strategies](https://www.postgresql.org/docs/current/datatype-json.html#id-1.5.7.22.18)
- [Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [Multi-Tenant SaaS Patterns](https://docs.aws.amazon.com/whitepapers/latest/saas-architecture-fundamentals/tenant-isolation-approaches.html)

## 🏆 Bonus Challenges

1. **Dynamic Partitioning**: Implement automatic partition creation
2. **Cross-Tenant Analytics**: Design secure aggregated reporting
3. **Schema Evolution**: Plan for adding new core fields without downtime
4. **Audit Trail**: Track all data changes with temporal tables

---

**Next**: [Day 3-4: Performance Optimization](../day3-performance/README.md)