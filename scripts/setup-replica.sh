#!/bin/bash
# Setup script for PostgreSQL replica
# This script configures the standby server

set -e

echo "Starting PostgreSQL replica setup..."

# Wait for primary to be available
until pg_isready -h postgres-primary -p 5432 -U replicator; do
  echo "Waiting for primary PostgreSQL to be ready..."
  sleep 2
done

echo "Primary PostgreSQL is ready. Starting base backup..."

# Create base backup from primary
pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U replicator -v -P -W

echo "Base backup completed. Configuring standby..."

# Configure recovery settings for standby
cat >> /var/lib/postgresql/data/postgresql.conf << EOF

# Standby configuration
standby_mode = 'on'
primary_conninfo = 'host=postgres-primary port=5432 user=replicator application_name=replica1'
trigger_file = '/tmp/postgresql.trigger'

# Hot standby settings
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
max_standby_archive_delay = -1

# Replica-specific logging
log_line_prefix = '[REPLICA] %t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

EOF

echo "Standby configuration completed successfully!"
echo "Starting PostgreSQL in standby mode..."
