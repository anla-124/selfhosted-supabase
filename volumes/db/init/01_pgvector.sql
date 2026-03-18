-- The supabase/postgres image ships with vector and uuid-ossp already available.
-- This is a no-op safety net; MASTER-DATABASE-SETUP.sql also runs CREATE EXTENSION IF NOT EXISTS.
-- Run MASTER-DATABASE-SETUP.sql only AFTER the storage service is healthy.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
