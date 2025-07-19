-- Initialize PostgreSQL with extensions and sample data
-- This script runs automatically when the container starts

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create replication user for replica setup
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';
    END IF;
END $$;

-- Create application roles
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user LOGIN PASSWORD 'app_password';
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly LOGIN PASSWORD 'readonly_password';
    END IF;
END $$;

-- Grant basic permissions
GRANT CONNECT ON DATABASE mastery_lab TO app_user, app_readonly;
GRANT USAGE ON SCHEMA public TO app_user, app_readonly;

-- Create a sample table to test replication
CREATE TABLE IF NOT EXISTS lab_status (
    id SERIAL PRIMARY KEY,
    component VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert initial status
INSERT INTO lab_status (component, status, message) VALUES 
    ('PostgreSQL Primary', 'healthy', 'Primary database initialized successfully'),
    ('Extensions', 'loaded', 'uuid-ossp, pgcrypto, vector, pg_stat_statements loaded'),
    ('Replication User', 'created', 'Replication user ready for replica setup')
ON CONFLICT DO NOTHING;

-- Create a function to check lab status
CREATE OR REPLACE FUNCTION get_lab_status()
RETURNS TABLE(
    component TEXT,
    status TEXT,
    message TEXT,
    last_updated TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ls.component::TEXT,
        ls.status::TEXT,
        ls.message::TEXT,
        ls.created_at
    FROM lab_status ls
    ORDER BY ls.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create a simple health check function
CREATE OR REPLACE FUNCTION health_check()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'database', current_database(),
        'version', version(),
        'current_time', NOW(),
        'extensions', (
            SELECT json_agg(extname)
            FROM pg_extension
            WHERE extname IN ('uuid-ossp', 'pgcrypto', 'vector', 'pg_stat_statements')
        ),
        'status', 'healthy'
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Log successful initialization
INSERT INTO lab_status (component, status, message) VALUES 
    ('Database Initialization', 'completed', 'PostgreSQL Mastery Lab ready for exercises!');
