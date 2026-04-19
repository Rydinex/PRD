# Rydinex.com Full-Stack Deployment

This setup serves frontend dashboards and backend API from one Railway service.

## What is live on one domain

- `/` -> Web dashboard launcher
- `/web-dashboard` -> Web dashboard launcher
- `/admin-dashboard` -> Admin dashboard hub
- `/rider-app` -> Rider app hub
- `/driver-app` -> Driver app hub
- `/api/*` -> Backend API

## Session-protected routes

- `/admin-dashboard` requires admin session
- `/driver-app` requires driver or admin session
- Protected API routes require one of:
   - `Authorization: Bearer <session_token>`
   - `x-session-token: <session_token>`

For browser testing of protected dashboards, use query token:

- `https://rydinex.com/admin-dashboard?sessionToken=<admin_session_token>`
- `https://rydinex.com/driver-app?sessionToken=<driver_session_token>`

## Railway settings

1. Deploy repository/folder containing this project root.
2. Railway uses `railway.json` at root:
   - Build command: `npm --prefix backend install`
   - Start command: `npm --prefix backend start`
3. Add environment variables:
   - `MONGO_URI` = your MongoDB Atlas URL
   - `REDIS_URL` or `REDIS_URI` = your Upstash/Redis URL
   - `STRIPE_SECRET_KEY` = your Stripe secret key
   - `JWT_SECRET` = your JWT signing key
   - `PORT` is optional (Railway injects it)

## Domain setup for rydinex.com

1. In Railway service -> Settings -> Domains -> Add Custom Domain.
2. Add `rydinex.com` (and optionally `www.rydinex.com`).
3. At your DNS provider, point records exactly as Railway instructs.
4. Wait for SSL issuance and status = Active.

## Verify after deploy

1. `https://rydinex.com/`
2. `https://rydinex.com/admin-dashboard`
3. `https://rydinex.com/rider-app`
4. `https://rydinex.com/driver-app`
5. `https://rydinex.com/api/health`
6. `https://rydinex.com/DEPLOY_CHECK.txt`

## Database SQL run order

1. `database/schema_postgres_postgis.sql`
2. `database/seed_postgres_postgis.sql`
3. `database/postgis_distance_fare_toolkit.sql`
4. `database/postgis_pricing_function_by_market.sql`
5. `database/postgis_match_quote_top3.sql`
6. `database/postgres_button_actions.sql`
7. `database/rider_all_in_one_postgres.sql`
