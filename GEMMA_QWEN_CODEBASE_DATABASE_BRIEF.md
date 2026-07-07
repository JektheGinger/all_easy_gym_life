# Gemma/Qwen Codebase and Database Brief

Use this document as the first context file for Gemma 4, smaller Gemma models, Qwen3.6 models, or any coding assistant before asking it to run tests, create code, edit files, or change the database. It is written to separate implemented facts from planned direction.

## 0. Read This First

Project name: Easy Gym Life (EGL)

Repository folder:

```text
all_easy_gym_life/
```

Current stack:

- Frontend: Flutter and Dart
- Backend: Node.js and Express
- Database: PostgreSQL or Aurora PostgreSQL
- Authentication: bcrypt password hashes and JWT tokens
- Future worker direction: Raspberry Pi or Python camera-vision worker sending structured event summaries to the backend

Critical rule:

```text
Flutter must not connect directly to PostgreSQL and must not contain backend secrets.
Flutter calls Express. Express talks to PostgreSQL.
```

## 1. Current System Shape

The implemented runtime shape is:

```text
User
  -> Flutter app in lib/main.dart
  -> POST /api/auth/login
  -> Express backend in backend/src/server.js
  -> PostgreSQL app_user table
  -> JWT + role returned to Flutter
  -> DashboardRouter chooses business or member dashboard
```

The planned camera-vision shape is:

```text
Raspberry Pi or Python vision worker
  -> POST /api/vision/events
  -> Express backend validation
  -> PostgreSQL event and metric tables
  -> Flutter dashboard charts and alerts
```

`POST /api/vision/events` is not implemented yet. It exists in documentation only.

## 2. Source Files That Matter Most

Read these before making changes:

```text
lib/main.dart
backend/src/server.js
backend/sql/schema.sql
backend/scripts/seed-demo-users.js
pubspec.yaml
package.json
backend/package.json
assets/config/app.env.example
backend/.env.example
README.md
PROJECT_GUIDE.md
backend/BACKEND_GUIDE.md
raspberry_pi/README.md
```

Useful existing docs:

- `FIRST_READ_THIS.md`: beginner-friendly architecture and setup explanation
- `PROJECT_GUIDE.md`: primary local setup guide
- `backend/BACKEND_GUIDE.md`: backend endpoints and planned vision event contract
- `DEMO_RUNBOOK.md`: demo flow and demo credentials
- `STAKEHOLDER_OVERVIEW.md`: product/status framing for non-developers
- `MODEL_TREE.md`: untracked/generated source relationship map present in the working tree
- `TECHNICAL_KNOWLEDGE.md`: local-only design reference ignored by Git

Generated or dependency folders usually should not be edited:

```text
.dart_tool/
build/
node_modules/
backend/node_modules/
android/
ios/
macos/
linux/
windows/
web/
```

Platform folders are mostly Flutter-generated runners and packaging files. Edit them only for platform-specific build, icon, permission, or packaging tasks.

## 3. Flutter Frontend

Main file:

```text
lib/main.dart
```

The app-specific Flutter implementation currently lives in one large Dart file. It contains bootstrap, configuration loading, authentication, login UI, business dashboard UI, member dashboard UI, and reusable widgets.

Important classes and functions:

```text
main()
GimAccessApp
ApiAuthRepository
AppConfigLoader
AppConfig
LoginPage
DashboardRouter
BusinessDashboard
GimUserDashboard
LoginAuditStore
AppUser
AuthSession
UserRole
```

Authentication flow in Flutter:

```text
LoginPage
  -> _submit()
  -> GimAccessApp._login()
  -> ApiAuthRepository.authenticate(email, password)
  -> POST {config.baseUrl}/api/auth/login
  -> AuthSession(token, AppUser)
  -> DashboardRouter
```

Supported Flutter roles:

```text
business
gim
```

Important mismatch:

```text
backend/sql/schema.sql allows developer_admin,
but lib/main.dart userRoleFromApi() currently rejects developer_admin.
```

If adding an admin role, update both frontend routing and backend authorization behavior deliberately.

Configuration loading:

```text
AppConfigLoader loads assets/config/app.env if present.
If that file is missing, it falls back to assets/config/app.env.example.
```

Frontend-safe config keys:

```text
APP_NAME
API_SCHEME
API_HOST
API_PORT
DB_NAME
DB_USER
JWT_ISSUER
BUSINESS_PORTAL_LABEL
GIM_PORTAL_LABEL
```

Do not put real `JWT_SECRET`, database passwords, or infrastructure credentials in `assets/config/app.env`.

Current UI status:

- Login screen is real.
- Backend login call is implemented.
- Business and member demo-entry buttons create local sessions without contacting Express.
- Business dashboard content is representative static UI data.
- Member dashboard content is representative static UI data.
- Business dashboard has tabs for home, video, data filter, equipment health, insights, and gym map.
- Camera/video/vision panels are placeholders and not connected to live event data.

## 4. Backend API

Main backend file:

```text
backend/src/server.js
```

Backend dependencies:

```text
express
cors
morgan
dotenv
pg
bcryptjs
jsonwebtoken
nodemon
```

Implemented routes:

| Method | Route | Status | Purpose |
|---|---|---|---|
| GET | `/` | Implemented | HTML backend status page |
| GET | `/api/health` | Implemented | Runs `SELECT 1` against PostgreSQL |
| POST | `/api/auth/login` | Implemented | Validates email/password and returns JWT + user |
| GET | `/api/auth/me` | Implemented | Validates bearer token and returns user profile |
| POST | `/api/vision/events` | Planned only | Future Raspberry Pi event ingestion |

Backend environment variables:

```text
PORT
CLIENT_ORIGIN
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
DB_SSL
JWT_SECRET
JWT_EXPIRES_IN
JWT_ISSUER
```

`JWT_SECRET` is required by `server.js`. The backend intentionally does not fall back to an insecure default secret.

Security boundary:

- The backend owns JWT signing and verification.
- The backend owns database credentials.
- SQL queries in `server.js` and the seed script use parameterized queries.
- Passwords are compared with `bcrypt.compare()`.
- Demo passwords in docs are public demo credentials only.

Important consistency note:

```text
assets/config/app.env.example uses JWT_ISSUER=egl-auth-service
backend/.env.example uses JWT_ISSUER=gim-auth-service
server.js defaults to egl-auth-service
```

When using `/api/auth/me`, make sure backend token issuer settings are consistent.

## 5. Current Database Schema

Implemented schema file:

```text
backend/sql/schema.sql
```

Only one table is currently implemented:

```sql
CREATE TABLE app_user (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'gim' CHECK (role IN ('business', 'gim', 'developer_admin')),
  display_name VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_app_user_role ON app_user(role);
CREATE INDEX idx_app_user_active ON app_user(is_active);
```

Current database facts:

- `app_user.email` is the unique login identifier.
- `app_user.password_hash` stores bcrypt hashes.
- `app_user.role` drives which dashboard Flutter displays.
- `app_user.is_active=false` blocks login and profile lookup.
- There is no implemented login audit table.
- There are no implemented organization, location, equipment, vision, metric, or notification tables yet.

Seed file:

```text
backend/scripts/seed-demo-users.js
```

Seed users:

| Email | Password | Role | Display name |
|---|---|---|---|
| `owner@iron-temple.com` | `Business123!` | `business` | Iron Temple Admin |
| `ops@fitdistrict.io` | `Business123!` | `business` | Fit District Operations |
| `member@easygymlife.app` | `EGLUser123!` | `gim` | Jordan Member |
| `welcome@easygymlife.app` | `EGLUser123!` | `gim` | Taylor Welcome |

The seed script upserts by email and rewrites password hash, role, display name, and active status.

## 6. Planned Database Direction

These tables are planned or suggested in docs, not implemented in `schema.sql`:

```text
roles
users or app_user expansion
login_audit
organizations
locations
memberships
equipment_categories
equipment_assets
equipment_usage_logs
equipment_maintenance_events
equipment_daily_metrics
vision_events
vision_metrics
dashboard_metrics
notifications
```

Recommended relationship direction:

```text
organizations 1 -> many locations
locations 1 -> many equipment_assets
equipment_categories 1 -> many equipment_assets
equipment_assets 1 -> many equipment_usage_logs
equipment_assets 1 -> many maintenance events
locations 1 -> many vision_events
users/app_user 1 -> many login_audit records
metric aggregate tables -> dashboard API responses
```

Preferred camera event payload shape for future route:

```json
{
  "cameraId": "CAM-001",
  "locationId": "LOC-001",
  "eventType": "human_activity_detected",
  "equipmentCode": "PTRM1001",
  "humanCount": 4,
  "activityLabel": "push_up",
  "confidenceScore": 0.91,
  "eventTimestamp": "2026-04-19T21:15:00Z",
  "metadata": {
    "zone": "cardio_floor",
    "poseMode": "stick_figure_mesh",
    "modelVersion": "vision-v1"
  }
}
```

Planned event labels:

```text
human_presence_detected
human_activity_detected
occupancy_snapshot
zone_traffic_update
```

Do not store raw video in the first implementation unless a privacy, retention, storage, and security design is approved.

## 7. Local Commands

Install dependencies:

```bash
npm install
flutter pub get
```

Run backend from root:

```bash
npm run dev
```

Run backend directly:

```bash
cd backend
npm run dev
```

Run frontend web on a stable port:

```bash
flutter run -d web-server --web-hostname localhost --web-port 8080
```

Seed demo users:

```bash
npm run backend:seed
```

Apply current schema:

```bash
psql -h YOUR_HOST -p 5432 -U YOUR_USER -d YOUR_DATABASE -f backend/sql/schema.sql
```

Common local URLs:

```text
Backend: http://localhost:3000
Frontend: http://localhost:8080 when using the web-server command
```

For Android emulator API calls, use `10.0.2.2` instead of `localhost` in frontend config.

## 8. Before Testing or Coding

Before running tests or writing code, perform this checklist:

1. Read `git status --short`.
2. Do not revert unrelated user changes.
3. Identify whether the requested work is frontend, backend, database, docs, or platform runner work.
4. For frontend work, read the relevant region of `lib/main.dart` and preserve the current single-file style unless asked to refactor.
5. For backend work, read `backend/src/server.js`, `backend/package.json`, and `backend/.env.example`.
6. For database work, read `backend/sql/schema.sql`, `backend/scripts/seed-demo-users.js`, and the planned schema notes above.
7. Do not add secrets to tracked files.
8. Do not make Flutter connect directly to PostgreSQL.
9. Do not claim planned camera-vision features are implemented.
10. If adding API endpoints, decide the request body, response shape, validation, and database table before coding.

## 9. Good Change Patterns

Frontend:

- Keep role routing centralized around `DashboardRouter`.
- Keep config loading in `AppConfigLoader`.
- Use `ApiAuthRepository` for backend auth calls.
- Treat demo buttons as temporary preview paths.
- If moving widgets out of `main.dart`, do it intentionally and update imports carefully.

Backend:

- Keep secrets in `backend/.env`.
- Use parameterized SQL.
- Return JSON errors with a `message` field.
- Keep JWT signing in Express only.
- Add auth middleware to protected routes.

Database:

- Use migrations or explicit SQL files for schema changes.
- Keep demo seed data separate from schema creation.
- Prefer normalized entities for users, organizations, locations, equipment, and events.
- Add indexes for role, active status, foreign keys, event timestamps, and dashboard query filters.

Testing:

- Use `flutter analyze` for Dart lint/static checks.
- Use `flutter test` if Flutter tests exist or are added.
- Use backend route tests if a test framework is added later.
- `GET /api/health` is a runtime database connectivity check, not a unit test.

## 10. Known Gaps and Risks

- No automated tests are present in the current source tree.
- Frontend role support and SQL role check are not fully aligned because SQL allows `developer_admin`.
- Dashboard metrics are static, representative UI data.
- No implemented tables exist for equipment, locations, organizations, camera events, or metrics.
- No implemented endpoint exists for camera-vision event ingestion.
- `backend/.env.example` issuer differs from the frontend example issuer.
- `assets/config/app.env` and `backend/.env` are intentionally ignored by Git and may exist locally with machine-specific values.
- The project has generated/dependency folders in the working directory; do not treat them as source.

