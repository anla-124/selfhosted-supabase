-- The supabase/postgres image ships with vector and uuid-ossp already available.
-- This is a no-op safety net that ensures the extensions exist on first DB start.
-- pgvector is optional — remove it if your app does not use vector search.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
