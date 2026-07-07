# Security Audit Plan — Easy Gym Life Backend

## Intent

Identify and remediate security vulnerabilities in the Express.js backend API (`all_easy_gym_life/backend/`) that handles authentication, JWT issuance, and PostgreSQL database access for the Easy Gym Life Flutter app.

## Non-Goals

- Frontend (Flutter) security analysis.
- Infrastructure/cloud security (AWS Aurora, CI/CD pipelines).
- Performance optimization.
- Adding new API features.

## Scope

| Area | Files |
|------|-------|
| Express server | `backend/src/server.js` |
| Database schema | `backend/sql/schema.sql` |
| Seed script | `backend/scripts/seed-demo-users.js` |
| Dependencies | `backend/package.json` |
| Environment config | `backend/.env.example`, `.gitignore` |

---

## Findings

### CRITICAL

#### C1 — Hardcoded Demo Credentials in Seed Script
**File:** [`seed-demo-users.js`](backend/scripts/seed-demo-users.js:18)  
Plain-text passwords (`Business123!`, `EGLUser123!`) are embedded in source code. If this script runs in production or the repo is exposed, credentials are leaked.

**Risk:** Credential exposure, unauthorized access.  
**Fix:** Remove hardcoded passwords. Pass credentials via environment variables or a secure secrets manager. Add a guard to prevent running in production (`NODE_ENV !== 'production'`).

#### C2 — Open CORS Origin in Production
**File:** [`server.js`](backend/src/server.js:44)  
`origin: process.env.CLIENT_ORIGIN || true` allows any origin when `CLIENT_ORIGIN` is unset.

**Risk:** Cross-origin abuse, token theft via malicious sites.  
**Fix:** Default to a strict origin list. Never fallback to `true`. Validate `CLIENT_ORIGIN` at startup.

#### C3 — SSL Bypass on Database Connection
**File:** [`server.js`](backend/src/server.js:39)  
`rejectUnauthorized: false` disables certificate validation when `DB_SSL=true`.

**Risk:** Man-in-the-middle attacks on database traffic.  
**Fix:** Use `rejectUnauthorized: true` in production. Provide proper CA certificates. Only allow `rejectUnauthorized: false` in explicit local-dev mode with a warning.

---

### HIGH

#### H1 — No Rate Limiting on Authentication Endpoints
**File:** [`server.js`](backend/src/server.js:149)  
`POST /api/auth/login` has no rate limiting.

**Risk:** Brute-force password attacks, credential stuffing.  
**Fix:** Add `express-rate-limit` on `/api/auth/*` routes (e.g., 10 requests per 15 minutes per IP).

#### H2 — No Input Validation on Email/Password
**File:** [`server.js`](backend/src/server.js:150)  
Email is only `.trim().toLowerCase()`. No format validation. Password has no length or complexity check.

**Risk:** Injection attacks, prototype pollution via malformed inputs.  
**Fix:** Validate email format (regex or a library like `validator`). Enforce minimum password length (8+ chars).

#### H3 — Missing Global Error Handler
**File:** [`server.js`](backend/src/server.js:282)  
No Express error-handling middleware (`(err, req, res, next)`). Unhandled exceptions may leak stack traces.

**Risk:** Information disclosure (stack traces, internal paths).  
**Fix:** Add a global error handler that returns generic messages in production and logs details server-side.

#### H4 — JWT Algorithm Not Explicitly Pinned
**File:** [`server.js`](backend/src/server.js:191) and [`server.js`](backend/src/server.js:269)  
`jwt.sign()` and `jwt.verify()` do not specify `algorithms: ['HS256']`.

**Risk:** JWT algorithm confusion attacks (e.g., `none` algorithm).  
**Fix:** Explicitly pass `{ algorithms: ['HS256'] }` to `jwt.verify()`.

---

### MEDIUM

#### M1 — Database Password Empty String Default
**File:** [`server.js`](backend/src/server.js:25)  
`password: process.env.DB_PASSWORD || ''` allows empty password fallback.

**Risk:** Accidental connections with no authentication.  
**Fix:** Use `requireEnv('DB_PASSWORD')` instead of silent fallback.

#### M2 — No Request Body Size Limit
**File:** [`server.js`](backend/src/server.js:48)  
`express.json()` has no size limit.

**Risk:** Denial of service via large payloads.  
**Fix:** Add `express.json({ limit: '1mb' })`.

#### M3 — Password Hash Column Too Short
**File:** [`schema.sql`](backend/sql/schema.sql:4)  
`password_hash VARCHAR(255)` may be too short for future algorithms (Argon2id hashes can exceed 255 chars).

**Risk:** Future migration blocked by column width.  
**Fix:** Increase to `VARCHAR(512)` or `TEXT`.

#### M4 — No `updated_at` Trigger
**File:** [`schema.sql`](backend/sql/schema.sql:9)  
`updated_at` defaults to `NOW()` but has no trigger to auto-update on row changes.

**Risk:** Stale timestamps, audit trail gaps.  
**Fix:** Add a PostgreSQL trigger function to set `updated_at = NOW()` on UPDATE.

#### M5 — Seed Script Uses UPSQL Without Existence Check
**File:** [`seed-demo-users.js`](backend/scripts/seed-demo-users.js:47)  
`ON CONFLICT ... DO UPDATE` always overwrites. Running in production could reset real user passwords.

**Risk:** Data destruction in production.  
**Fix:** Add `INSERT ... ON CONFLICT DO NOTHING` for safety, or require explicit `--force` flag for updates.

---

### LOW

#### L1 — Verbose Backend Status Page
**File:** [`server.js`](backend/src/server.js:50)  
Root endpoint exposes endpoint list and internal workflow details.

**Risk:** Information disclosure aiding attackers.  
**Fix:** Remove or minimize the HTML status page in production.

#### L2 — Missing `helmet` HTTP Security Headers
**File:** [`server.js`](backend/src/server.js:42)  
No `helmet` middleware for security headers (X-Frame-Options, CSP, etc.).

**Risk:** Clickjacking, MIME sniffing, XSS amplification.  
**Fix:** Add `helmet` middleware.

#### L3 — Morgan Dev Logging in Production
**File:** [`server.js`](backend/src/server.js:47)  
`morgan('dev')` runs regardless of `NODE_ENV`.

**Risk:** Verbose logs exposing request details.  
**Fix:** Use `morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev')`.

---

## Ordered Remediation Steps

| # | Finding | Priority | Target File |
|---|---------|----------|-------------|
| 1 | C1 — Hardcoded credentials | Critical | `seed-demo-users.js` |
| 2 | C2 — Open CORS | Critical | `server.js` |
| 3 | C3 — SSL bypass | Critical | `server.js` |
| 4 | H1 — Rate limiting | High | `server.js`, `package.json` |
| 5 | H2 — Input validation | High | `server.js` |
| 6 | H3 — Error handler | High | `server.js` |
| 7 | H4 — JWT algorithm pinning | High | `server.js` |
| 8 | M1 — DB password default | Medium | `server.js` |
| 9 | M2 — Body size limit | Medium | `server.js` |
| 10 | M3 — Password hash column width | Medium | `schema.sql` |
| 11 | M4 — `updated_at` trigger | Medium | `schema.sql` |
| 12 | M5 — Seed script safety | Medium | `seed-demo-users.js` |
| 13 | L1 — Status page info leak | Low | `server.js` |
| 14 | L2 — Helmet headers | Low | `server.js`, `package.json` |
| 15 | L3 — Logging level | Low | `server.js` |

---

## Acceptance Criteria

- [ ] No plain-text passwords in source code.
- [ ] CORS defaults to a strict origin (not `true`).
- [ ] SSL connections enforce certificate validation in production.
- [ ] Rate limiter active on `/api/auth/*`.
- [ ] Email format and password length validated.
- [ ] Global error handler suppresses stack traces.
- [ ] JWT verify explicitly uses `HS256`.
- [ ] `DB_PASSWORD` is required (no empty fallback).
- [ ] Request body limited to 1 MB.
- [ ] `password_hash` column is `VARCHAR(512)` or wider.
- [ ] `updated_at` auto-updates via trigger.
- [ ] Seed script cannot run in production without explicit override.
- [ ] `helmet` middleware installed.
- [ ] Logging adapts to `NODE_ENV`.

---

## Constraints

- Backend uses Node.js with Express, PostgreSQL via `pg`.
- No framework changes (stay on Express).
- Minimal new dependencies preferred (`express-rate-limit`, `helmet`, `validator`).
- Changes must not break the existing Flutter app API contract.

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Rate limiting blocks legitimate users | Start with generous limits; tune based on traffic. |
| Strict CORS breaks local Flutter dev | Allow `http://localhost:*` as additional origin in dev. |
| SSL cert changes break DB connection | Test cert chain before deploying. |

---

## Handoff Notes

After approval, switch to **Code mode** to implement the 15 remediation steps in priority order. Each step is a targeted, independent change. Steps 1-7 (Critical + High) should be completed before steps 8-15.
