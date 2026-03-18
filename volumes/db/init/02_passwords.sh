#!/bin/bash
# Reset internal Supabase role passwords to match POSTGRES_PASSWORD.
# Runs during first-time DB initialization (docker-entrypoint-initdb.d).
# At this point postgres accepts local connections without a password.
set -e
psql -v ON_ERROR_STOP=1 --username postgres --dbname postgres <<-EOSQL
  ALTER ROLE supabase_auth_admin    WITH PASSWORD '$POSTGRES_PASSWORD';
  ALTER ROLE supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';
  ALTER ROLE authenticator          WITH PASSWORD '$POSTGRES_PASSWORD';
  ALTER ROLE supabase_admin         WITH PASSWORD '$POSTGRES_PASSWORD';
EOSQL
