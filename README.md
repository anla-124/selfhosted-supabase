# Self-Hosted Supabase for Dokploy

Dokploy-compatible Supabase stack backing the [pdf-search](https://github.com/anla-124/pdf-search/) app.

**Stack:** PostgreSQL 17 · pgvector · GoTrue · PostgREST · Realtime · Storage · Kong · Studio

---

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | All Supabase services, Dokploy-compatible, Postgres 17 |
| `.env.example` | Environment template — copy to `.env` |
| `volumes/api/kong.yml` | Kong API gateway routing |
| `volumes/db/init/01_pgvector.sql` | Safety-net extension init (runs on first DB start) |
| `.gitignore` | Excludes `.env` and data directories |

---

## Deployment

### 1. Clone and configure

```bash
git clone <this-repo>
cd selfhosted-supabase
cp .env.example .env
```

Edit `.env` — every value marked `change-me` must be replaced.

### 2. Generate secrets

```bash
# PostgreSQL password and JWT secret
openssl rand -hex 32   # POSTGRES_PASSWORD
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # SECRET_KEY_BASE
openssl rand -hex 32   # VAULT_ENC_KEY
openssl rand -hex 32   # PG_META_CRYPTO_KEY
openssl rand -hex 32   # DASHBOARD_PASSWORD
```

### 3. Generate ANON_KEY and SERVICE_ROLE_KEY

Both are HS256 JWTs signed with your `JWT_SECRET`. Run this Node.js script:

```js
// generate-keys.js
const jwt = require('jsonwebtoken');

const secret = 'YOUR_JWT_SECRET_HERE';
const now = Math.floor(Date.now() / 1000);
const exp = 1893456000; // year 2030

const anonKey = jwt.sign(
  { role: 'anon', iss: 'supabase', iat: now, exp },
  secret,
  { algorithm: 'HS256' }
);

const serviceKey = jwt.sign(
  { role: 'service_role', iss: 'supabase', iat: now, exp },
  secret,
  { algorithm: 'HS256' }
);

console.log('ANON_KEY=' + anonKey);
console.log('SERVICE_ROLE_KEY=' + serviceKey);
```

```bash
npm install jsonwebtoken
node generate-keys.js
```

Copy the output into `.env`.

### 4. Set SITE_URL correctly

> **Critical:** `SITE_URL` must be the pdf-search Next.js app URL, **not** the Supabase URL.
> Auth confirmation emails and OAuth redirects go to `SITE_URL/auth/callback`.

```env
SITE_URL=https://pdf-search.yourdomain.com
SUPABASE_PUBLIC_URL=https://supabase.yourdomain.com
API_EXTERNAL_URL=https://supabase.yourdomain.com
```

### 5. Deploy via Dokploy

1. In Dokploy: create a new **Compose** service and point it to this repo
2. Deploy — watch logs until all services are healthy:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}"
   ```
3. In Dokploy **Domains**, add a domain for the **kong** service → port `8000`
   - Domain: `supabase.yourdomain.com`
   - **Enable WebSocket support** (see WebSocket section below)

### 6. Run database setup

> **Wait** until the `storage` service is healthy before this step.
> `MASTER-DATABASE-SETUP.sql` references `storage.buckets` and `storage.objects`.

Open Studio (see [Studio Access](#studio-access)) → SQL Editor → paste and run `MASTER-DATABASE-SETUP.sql`.

If Studio later shows `Failed to fetch buckets` while `SELECT * FROM storage.buckets;` works in SQL, check whether `supabase_storage_admin` has `rolbypassrls = true`. If you add `BYPASSRLS` manually after deploy, restart the `storage` service so it reconnects with fresh role attributes.

### 7. Verify

```bash
# Auth health
curl https://supabase.yourdomain.com/auth/v1/health
# → {"status":"ok"}

# PostgREST OpenAPI
curl https://supabase.yourdomain.com/rest/v1/

# pgvector extension
# (run in Studio SQL editor)
SELECT extname FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp');
# → 2 rows
```

### 8. Configure pdf-search app

In the pdf-search repo, set these environment variables:

```env
NEXT_PUBLIC_SUPABASE_URL=https://supabase.yourdomain.com
NEXT_PUBLIC_SUPABASE_ANON_KEY=<ANON_KEY>
SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY>
```

---

## WebSocket Configuration for Realtime

Supabase Realtime uses WebSocket connections at `/realtime/v1/websocket`. Traefik must pass WebSocket upgrade headers through to Kong.

### Option A — Dokploy UI (recommended)

In Dokploy UI → Kong domain → **Advanced settings** → enable **WebSocket support** checkbox.

### Option B — Traefik labels (already in docker-compose.yml)

The `kong` service already has these labels:

```yaml
labels:
  traefik.http.middlewares.supabase-ws.headers.customrequestheaders.Upgrade: "websocket"
  traefik.http.middlewares.supabase-ws.headers.customrequestheaders.Connection: "Upgrade"
```

You still need to apply the `supabase-ws` middleware to the Kong router in your Traefik configuration or via Dokploy's domain advanced settings.

**Verify:** Upload a document in pdf-search and confirm the processing status updates live without page refresh.

---

## Studio Access

Studio grants full admin database access. **Do not expose it publicly in production.**

### Recommended: SSH tunnel

```bash
ssh -L 3000:<container-host>:3000 user@your-server
# Then open: http://localhost:3000
```

Replace `<container-host>` with the internal hostname of the studio container (or `localhost` if SSH-ing directly to the Docker host).

### Dev/staging only: Dokploy domain with IP allowlist

If you need browser access without SSH:

1. Add a Dokploy domain for the `studio` service → port `3000`
2. In the domain's Traefik advanced settings, add an IP allowlist middleware restricted to your IP

---

## SMTP

SMTP is optional for initial setup (`GOTRUE_MAILER_AUTOCONFIRM=true` allows signup without email verification), but **required for password reset**.

Set these in `.env`:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-user
SMTP_PASS=your-password
SMTP_ADMIN_EMAIL=admin@example.com
```

Once SMTP is working, consider setting `GOTRUE_MAILER_AUTOCONFIRM=false` in production.

---

## PostgreSQL Version

This stack uses **PostgreSQL 17** (`supabase/postgres:17.4.1.182`) to match the pdf-search app's `supabase/config.toml` (`major_version = 17`). This prevents `pg_dump` compatibility issues if you migrate from a managed Supabase instance.

---

## Upgrading

When upgrading service image versions:

1. Check the [Supabase self-hosting changelog](https://github.com/supabase/supabase/releases)
2. Update image tags in `docker-compose.yml`
3. For PostgreSQL major version upgrades, follow the [pg_upgrade docs](https://www.postgresql.org/docs/current/pgupgrade.html)
