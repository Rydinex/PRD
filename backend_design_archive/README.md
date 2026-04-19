# Rydinex API Scaffold

Node.js + Express + pg backend wired to Postgres SQL functions, now serving frontend dashboards on the same domain.

## 1) Setup

1. Copy `.env.example` to `.env`
2. Set `DATABASE_URL`
3. Install deps:

```bash
npm install
```

## 2) Run

```bash
npm run dev
```

Server starts on `PORT` (default `3000`).

## 3) Health

- `GET /api/health`

## 4) Frontend Dashboards (same server)

- `GET /` (web dashboard launcher)
- `GET /web-dashboard`
- `GET /admin-dashboard` (admin session required)
- `GET /rider-app`
- `GET /driver-app` (driver/admin session required)

Browser test with session query token:

- `/admin-dashboard?sessionToken=<token>`
- `/driver-app?sessionToken=<token>`

## 5) Example Endpoints

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/ride-requests`
- `GET /api/ride-requests/:requestId/quote?market=chicago&weather=rain`
- `GET /api/ride-requests/:requestId/match-top?market=chicago&weather=rain&top=3`

## 6) Required SQL

Run these files on Postgres first:

1. `database/schema_postgres_postgis.sql`
2. `database/seed_postgres_postgis.sql`
3. `database/postgis_distance_fare_toolkit.sql`
4. `database/postgis_pricing_function_by_market.sql`
5. `database/postgis_match_quote_top3.sql`
6. `database/postgres_button_actions.sql`

## 7) Railway

- Deploy from project root (contains `railway.json`)
- `railway.json` runs:
	- Build: `npm --prefix backend install`
	- Start: `node backend/src/server.js`
- Add env var `DATABASE_URL`
