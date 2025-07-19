-- Foundation Schema for Multi-Tenant CRM
-- Day 1-2: Advanced Schema Design

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Tenants table - the foundation of multi-tenancy
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    settings JSONB DEFAULT '{}',
    subscription_tier VARCHAR(50) DEFAULT 'basic',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT tenants_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT tenants_name_length CHECK (length(name) >= 2)
);

-- Indexes for tenants
CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_subscription ON tenants(subscription_tier);

-- Tenant users with role-based access
CREATE TABLE tenant_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50) DEFAULT 'user',
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT tenant_users_email_tenant_unique UNIQUE(email, tenant_id),
    CONSTRAINT tenant_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    CONSTRAINT tenant_users_role_valid CHECK (role IN ('admin', 'manager', 'user', 'viewer'))
);

-- Indexes for tenant_users
CREATE INDEX idx_tenant_users_tenant_id ON tenant_users(tenant_id);
CREATE INDEX idx_tenant_users_email ON tenant_users(email);
CREATE INDEX idx_tenant_users_role ON tenant_users(tenant_id, role);

-- Contacts table with JSONB custom fields
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    company VARCHAR(255),
    job_title VARCHAR(255),
    
    -- Custom fields as JSONB for flexibility
    custom_fields JSONB DEFAULT '{}',
    
    -- Metadata
    source VARCHAR(100),
    tags TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES tenant_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT contacts_email_format CHECK (
        email IS NULL OR 
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    ),
    CONSTRAINT contacts_name_required CHECK (
        first_name IS NOT NULL OR last_name IS NOT NULL OR company IS NOT NULL
    )
);

-- Indexes for contacts
CREATE INDEX idx_contacts_tenant_id ON contacts(tenant_id);
CREATE INDEX idx_contacts_email ON contacts(tenant_id, email);
CREATE INDEX idx_contacts_name ON contacts(tenant_id, first_name, last_name);
CREATE INDEX idx_contacts_company ON contacts(tenant_id, company);
CREATE INDEX idx_contacts_created_at ON contacts(tenant_id, created_at);
CREATE INDEX idx_contacts_tags ON contacts USING GIN(tags);

-- Leads table for sales opportunities
CREATE TABLE leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    
    -- Lead details
    title VARCHAR(255) NOT NULL,
    description TEXT,
    stage VARCHAR(100) DEFAULT 'new',
    value DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',
    probability INTEGER DEFAULT 0,
    
    -- Custom fields for lead-specific data
    custom_fields JSONB DEFAULT '{}',
    
    -- Dates
    expected_close_date DATE,
    actual_close_date DATE,
    
    -- Ownership and metadata
    assigned_to UUID REFERENCES tenant_users(id),
    source VARCHAR(100),
    tags TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES tenant_users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT leads_stage_valid CHECK (
        stage IN ('new', 'qualified', 'proposal', 'negotiation', 'won', 'lost')
    ),
    CONSTRAINT leads_probability_range CHECK (probability >= 0 AND probability <= 100),
    CONSTRAINT leads_value_positive CHECK (value IS NULL OR value >= 0),
    CONSTRAINT leads_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

-- Indexes for leads
CREATE INDEX idx_leads_tenant_id ON leads(tenant_id);
CREATE INDEX idx_leads_contact_id ON leads(contact_id);
CREATE INDEX idx_leads_stage ON leads(tenant_id, stage);
CREATE INDEX idx_leads_assigned_to ON leads(assigned_to);
CREATE INDEX idx_leads_value ON leads(tenant_id, value) WHERE value IS NOT NULL;
CREATE INDEX idx_leads_close_date ON leads(tenant_id, expected_close_date);
CREATE INDEX idx_leads_created_at ON leads(tenant_id, created_at);
CREATE INDEX idx_leads_tags ON leads USING GIN(tags);

-- Activities table (will be partitioned by time)
CREATE TABLE activities (
    id UUID DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
    
    -- Activity details
    type VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    description TEXT,
    duration_minutes INTEGER,
    
    -- Custom fields for activity-specific data
    custom_fields JSONB DEFAULT '{}',
    
    -- Ownership and metadata
    performed_by UUID REFERENCES tenant_users(id),
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT activities_type_valid CHECK (
        type IN ('call', 'email', 'meeting', 'task', 'note', 'follow_up')
    ),
    CONSTRAINT activities_duration_positive CHECK (
        duration_minutes IS NULL OR duration_minutes > 0
    ),
    CONSTRAINT activities_completed_logic CHECK (
        (is_completed = false AND completed_at IS NULL) OR
        (is_completed = true AND completed_at IS NOT NULL)
    )
) PARTITION BY RANGE (created_at);

-- Create initial partitions for activities (will extend this in partitioning exercise)
CREATE TABLE activities_2024_q1 PARTITION OF activities
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE activities_2024_q2 PARTITION OF activities
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE activities_2024_q3 PARTITION OF activities
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE activities_2024_q4 PARTITION OF activities
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- Indexes for activities (will be inherited by partitions)
CREATE INDEX idx_activities_tenant_id ON activities(tenant_id);
CREATE INDEX idx_activities_contact_id ON activities(contact_id);
CREATE INDEX idx_activities_lead_id ON activities(lead_id);
CREATE INDEX idx_activities_type ON activities(tenant_id, type);
CREATE INDEX idx_activities_performed_by ON activities(performed_by);
CREATE INDEX idx_activities_created_at ON activities(tenant_id, created_at);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to all tables
CREATE TRIGGER update_tenants_updated_at 
    BEFORE UPDATE ON tenants 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_users_updated_at 
    BEFORE UPDATE ON tenant_users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at 
    BEFORE UPDATE ON contacts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leads_updated_at 
    BEFORE UPDATE ON leads 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_activities_updated_at 
    BEFORE UPDATE ON activities 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create a view for easy tenant context switching
CREATE OR REPLACE VIEW current_tenant_info AS
SELECT 
    t.*,
    COUNT(tu.id) as user_count,
    COUNT(c.id) as contact_count,
    COUNT(l.id) as lead_count
FROM tenants t
LEFT JOIN tenant_users tu ON t.id = tu.tenant_id AND tu.is_active = true
LEFT JOIN contacts c ON t.id = c.tenant_id AND c.is_active = true  
LEFT JOIN leads l ON t.id = l.tenant_id AND l.is_active = true
WHERE t.id = current_setting('app.current_tenant', true)::uuid
GROUP BY t.id, t.name, t.slug, t.settings, t.subscription_tier, t.created_at, t.updated_at;

\\echo 'Foundation schema created successfully!'
\\echo 'Next steps:'
\\echo '1. Run 02-rls-policies.sql to implement Row-Level Security'
\\echo '2. Run 03-jsonb-fields.sql to add custom field examples'
\\echo '3. Run 04-jsonb-indexes.sql to optimize JSONB queries'
\\echo '4. Run 05-partitioning.sql to extend partitioning strategy'