-- Row-Level Security (RLS) Policies
-- Day 1-2: Advanced Schema Design

-- Enable RLS on all tenant-aware tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Create database roles for different access levels
DO $$ 
BEGIN
    -- Application role for normal operations
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user;
    END IF;
    
    -- Read-only role for analytics
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly;
    END IF;
    
    -- Admin role for management operations
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin;
    END IF;
END $$;

-- Grant basic permissions to roles
GRANT USAGE ON SCHEMA public TO app_user, app_readonly, app_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly, app_user, app_admin;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user, app_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user, app_admin;

-- Helper function to get current tenant from session
CREATE OR REPLACE FUNCTION get_current_tenant()
RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.current_tenant', true)::uuid;
EXCEPTION 
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_tenant_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_setting('app.user_role', true) = 'admin';
EXCEPTION 
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.current_user_id', true)::uuid;
EXCEPTION 
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies for tenants table
-- Only allow access to current tenant
CREATE POLICY tenant_isolation ON tenants
    FOR ALL TO app_user, app_readonly
    USING (id = get_current_tenant());

-- Admins can see all tenants
CREATE POLICY tenant_admin_access ON tenants
    FOR ALL TO app_admin
    USING (true);

-- RLS Policies for tenant_users table
-- Users can only see users from their tenant
CREATE POLICY tenant_users_isolation ON tenant_users
    FOR ALL TO app_user, app_readonly
    USING (tenant_id = get_current_tenant());

-- Users can only update their own profile (except admins)
CREATE POLICY tenant_users_self_update ON tenant_users
    FOR UPDATE TO app_user
    USING (tenant_id = get_current_tenant() AND (id = get_current_user_id() OR is_tenant_admin()));

-- Admins can manage all users in their tenant
CREATE POLICY tenant_users_admin_management ON tenant_users
    FOR ALL TO app_admin
    USING (tenant_id = get_current_tenant());

-- RLS Policies for contacts table
-- Basic tenant isolation
CREATE POLICY contacts_tenant_isolation ON contacts
    FOR ALL TO app_user, app_readonly, app_admin
    USING (tenant_id = get_current_tenant());

-- Additional policy for user-level access control (if needed)
-- This can be uncommented if you want to restrict users to only their own contacts
-- CREATE POLICY contacts_user_access ON contacts
--     FOR ALL TO app_user
--     USING (
--         tenant_id = get_current_tenant() AND 
--         (created_by = get_current_user_id() OR is_tenant_admin())
--     );

-- RLS Policies for leads table
-- Basic tenant isolation
CREATE POLICY leads_tenant_isolation ON leads
    FOR ALL TO app_user, app_readonly, app_admin
    USING (tenant_id = get_current_tenant());

-- Users can only modify leads assigned to them or that they created
CREATE POLICY leads_user_access ON leads
    FOR UPDATE TO app_user
    USING (
        tenant_id = get_current_tenant() AND 
        (assigned_to = get_current_user_id() OR created_by = get_current_user_id() OR is_tenant_admin())
    );

-- RLS Policies for activities table
-- Basic tenant isolation
CREATE POLICY activities_tenant_isolation ON activities
    FOR ALL TO app_user, app_readonly, app_admin
    USING (tenant_id = get_current_tenant());

-- Users can only modify activities they performed
CREATE POLICY activities_user_access ON activities
    FOR UPDATE TO app_user
    USING (
        tenant_id = get_current_tenant() AND 
        (performed_by = get_current_user_id() OR is_tenant_admin())
    );

-- Create a secure view for user context
CREATE OR REPLACE VIEW current_user_context AS
SELECT 
    tu.id as user_id,
    tu.tenant_id,
    tu.email,
    tu.first_name,
    tu.last_name,
    tu.role,
    tu.permissions,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.subscription_tier
FROM tenant_users tu
JOIN tenants t ON tu.tenant_id = t.id
WHERE tu.id = get_current_user_id()
  AND tu.tenant_id = get_current_tenant()
  AND tu.is_active = true;

-- Function to set user context (call this when user logs in)
CREATE OR REPLACE FUNCTION set_user_context(
    p_user_id UUID,
    p_tenant_id UUID,
    p_user_role TEXT DEFAULT 'user'
)
RETURNS VOID AS $$
BEGIN
    -- Verify user belongs to tenant
    IF NOT EXISTS (
        SELECT 1 FROM tenant_users 
        WHERE id = p_user_id 
          AND tenant_id = p_tenant_id 
          AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Invalid user/tenant combination';
    END IF;
    
    -- Set session variables
    PERFORM set_config('app.current_tenant', p_tenant_id::text, false);
    PERFORM set_config('app.current_user_id', p_user_id::text, false);
    PERFORM set_config('app.user_role', p_user_role, false);
    
    -- Log the context switch
    INSERT INTO activity_log (
        user_id, 
        tenant_id, 
        action, 
        details,
        created_at
    ) VALUES (
        p_user_id,
        p_tenant_id,
        'context_switch',
        jsonb_build_object('role', p_user_role),
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Activity log table for auditing
CREATE TABLE IF NOT EXISTS activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    tenant_id UUID,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for activity log
CREATE INDEX idx_activity_log_user_tenant ON activity_log(user_id, tenant_id);
CREATE INDEX idx_activity_log_created_at ON activity_log(created_at);
CREATE INDEX idx_activity_log_action ON activity_log(tenant_id, action);

-- Enable RLS on activity log
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Activity log can only be viewed by tenant users
CREATE POLICY activity_log_tenant_isolation ON activity_log
    FOR SELECT TO app_user, app_readonly, app_admin
    USING (tenant_id = get_current_tenant());

-- Only system can insert into activity log
CREATE POLICY activity_log_insert_system ON activity_log
    FOR INSERT TO app_user, app_admin
    WITH CHECK (tenant_id = get_current_tenant());

-- Test functions to verify RLS is working
CREATE OR REPLACE FUNCTION test_rls_isolation()
RETURNS TABLE(
    test_name TEXT,
    tenant_1_count BIGINT,
    tenant_2_count BIGINT,
    passed BOOLEAN
) AS $$
DECLARE
    tenant_1_id UUID;
    tenant_2_id UUID;
    user_1_id UUID;
    user_2_id UUID;
BEGIN
    -- Create test tenants
    INSERT INTO tenants (name, slug) VALUES ('Test Tenant 1', 'test-tenant-1') 
    RETURNING id INTO tenant_1_id;
    
    INSERT INTO tenants (name, slug) VALUES ('Test Tenant 2', 'test-tenant-2') 
    RETURNING id INTO tenant_2_id;
    
    -- Create test users
    INSERT INTO tenant_users (tenant_id, email, password_hash, first_name, last_name)
    VALUES (tenant_1_id, 'user1@test.com', 'hash1', 'User', 'One')
    RETURNING id INTO user_1_id;
    
    INSERT INTO tenant_users (tenant_id, email, password_hash, first_name, last_name)
    VALUES (tenant_2_id, 'user2@test.com', 'hash2', 'User', 'Two')
    RETURNING id INTO user_2_id;
    
    -- Create test contacts
    INSERT INTO contacts (tenant_id, first_name, last_name, email)
    VALUES 
        (tenant_1_id, 'Contact', 'One', 'contact1@test.com'),
        (tenant_1_id, 'Contact', 'Two', 'contact2@test.com'),
        (tenant_2_id, 'Contact', 'Three', 'contact3@test.com');
    
    -- Test tenant 1 isolation
    PERFORM set_user_context(user_1_id, tenant_1_id, 'user');
    
    SELECT 'Contacts Isolation - Tenant 1', 
           COUNT(*), 
           0::BIGINT,
           COUNT(*) = 2
    FROM contacts
    WHERE true; -- RLS should filter this
    
    RETURN NEXT;
    
    -- Test tenant 2 isolation
    PERFORM set_user_context(user_2_id, tenant_2_id, 'user');
    
    SELECT 'Contacts Isolation - Tenant 2', 
           0::BIGINT,
           COUNT(*),
           COUNT(*) = 1
    FROM contacts
    WHERE true; -- RLS should filter this
    
    RETURN NEXT;
    
    -- Cleanup
    DELETE FROM contacts WHERE tenant_id IN (tenant_1_id, tenant_2_id);
    DELETE FROM tenant_users WHERE id IN (user_1_id, user_2_id);
    DELETE FROM tenants WHERE id IN (tenant_1_id, tenant_2_id);
END;
$$ LANGUAGE plpgsql;

\\echo 'Row-Level Security policies created successfully!'
\\echo ''
\\echo 'Usage Examples:'
\\echo '-- Set user context (call this after user authentication)'
\\echo 'SELECT set_user_context('
\\echo '    ''user-uuid''::uuid,'
\\echo '    ''tenant-uuid''::uuid,'
\\echo '    ''admin'''
\\echo ');'
\\echo ''
\\echo '-- Check current context'
\\echo 'SELECT * FROM current_user_context;'
\\echo ''
\\echo '-- Test RLS isolation'
\\echo 'SELECT * FROM test_rls_isolation();'
\\echo ''
\\echo 'Next: Run 03-jsonb-fields.sql for custom fields setup'