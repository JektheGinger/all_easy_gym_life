# Human Codebase Overview - Delimited

This file gives humans a chunked overview of the Easy Gym Life codebase. Each section is wrapped with clear delimiters so reviewers can skim, copy, or hand off one part at a time.

<<<BEGIN SECTION: QUICK ORIENTATION>>>

Easy Gym Life is an early-stage role-based gym platform prototype.

The app has three main layers:

- Flutter frontend: user interface, login page, dashboards, charts/placeholders, role-based screen selection
- Express backend: authentication, JWT creation/verification, PostgreSQL access
- PostgreSQL/Aurora PostgreSQL: currently only stores application users, with planned expansion for equipment, locations, metrics, and camera events

The core flow is:

```text
Flutter login screen
  -> Express login route
  -> PostgreSQL app_user lookup
  -> JWT + role response
  -> Flutter routes to business or member dashboard
```

The important boundary is simple:

```text
Frontend does not talk directly to the database.
Backend does.
```

<<<END SECTION: QUICK ORIENTATION>>>

<<<BEGIN SECTION: CURRENT IMPLEMENTATION STATUS>>>

Implemented:

- Flutter app in `lib/main.dart`
- Login form with backend POST to `/api/auth/login`
- Temporary demo buttons for business and member dashboards
- Business dashboard UI with operational tabs
- Member dashboard UI with workout/planning/schedule style cards
- Express backend in `backend/src/server.js`
- PostgreSQL connection through `pg`
- Password validation through `bcryptjs`
- JWT signing and verification through `jsonwebtoken`
- `app_user` table schema
- Demo user seed script
- Setup, demo, stakeholder, backend, and Raspberry Pi documentation

Planned, not yet implemented:

- Real dashboard metrics endpoints
- Equipment inventory tables
- Equipment usage and maintenance tables
- Organization/location tables
- Login audit persistence
- Camera-vision event ingestion route
- Raspberry Pi worker code
- Production deployment hardening
- Automated test suite

<<<END SECTION: CURRENT IMPLEMENTATION STATUS>>>

<<<BEGIN SECTION: IMPORTANT FILES>>>

Most important source files:

```text
lib/main.dart
backend/src/server.js
backend/sql/schema.sql
backend/scripts/seed-demo-users.js
```

Most important config files:

```text
pubspec.yaml
package.json
backend/package.json
analysis_options.yaml
assets/config/app.env.example
backend/.env.example
```

Most important docs:

```text
README.md
FIRST_READ_THIS.md
PROJECT_GUIDE.md
DEMO_RUNBOOK.md
STAKEHOLDER_OVERVIEW.md
backend/BACKEND_GUIDE.md
raspberry_pi/README.md
```

Generated or dependency folders to usually avoid editing:

```text
.dart_tool/
build/
node_modules/
backend/node_modules/
```

Platform runner folders:

```text
android/
ios/
macos/
linux/
windows/
web/
```

These platform folders are mostly generated Flutter scaffolding. They matter for packaging and platform settings, but most product behavior is in `lib/main.dart` and `backend/src/server.js`.

<<<END SECTION: IMPORTANT FILES>>>

<<<BEGIN SECTION: FRONTEND OVERVIEW>>>

Frontend framework: Flutter

Language: Dart

Main file:

```text
lib/main.dart
```

The current app-specific Flutter code is concentrated in one large file. It includes app startup, config loading, authentication, login UI, business dashboard UI, member dashboard UI, shared card widgets, and small custom painters.

Key frontend objects:

- `main()`: loads config and starts the app
- `GimAccessApp`: owns active session state
- `AppConfigLoader`: loads frontend-safe config from asset env files
- `ApiAuthRepository`: sends login requests to Express
- `LoginPage`: login UI and demo-entry buttons
- `DashboardRouter`: chooses dashboard by role
- `BusinessDashboard`: business-facing dashboard shell
- `GimUserDashboard`: member-facing dashboard shell
- `LoginAuditStore`: in-memory recent-login list for UI display

Frontend roles currently supported:

```text
business
gim
```

Important detail:

The database schema also allows `developer_admin`, but Flutter currently does not support routing that role. Adding admin support requires a deliberate frontend and backend update.

Demo buttons:

- `Enter Business Demo Dashboard`: creates a local business session without the backend
- `Enter Member Demo Dashboard`: creates a local member session without the backend

These are preview paths, not production authentication.

<<<END SECTION: FRONTEND OVERVIEW>>>

<<<BEGIN SECTION: BACKEND OVERVIEW>>>

Backend framework: Express

Runtime: Node.js

Main file:

```text
backend/src/server.js
```

Implemented routes:

```text
GET  /
GET  /api/health
POST /api/auth/login
GET  /api/auth/me
```

Planned route:

```text
POST /api/vision/events
```

What the backend does today:

- Loads environment variables with `dotenv`
- Connects to PostgreSQL using `pg.Pool`
- Serves a backend status page at `/`
- Checks DB connectivity at `/api/health`
- Validates login requests at `/api/auth/login`
- Compares submitted passwords against bcrypt hashes
- Signs JWTs with a backend-only secret
- Verifies bearer tokens for `/api/auth/me`
- Uses parameterized SQL queries

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

Backend secrets belong in:

```text
backend/.env
```

Never place backend secrets in:

```text
assets/config/app.env
```

<<<END SECTION: BACKEND OVERVIEW>>>

<<<BEGIN SECTION: DATABASE OVERVIEW>>>

Current implemented schema file:

```text
backend/sql/schema.sql
```

Current implemented table:

```text
app_user
```

Columns:

```text
id              BIGINT identity primary key
email           unique login identifier
password_hash   bcrypt password hash
role            business | gim | developer_admin
display_name    display name returned to frontend
is_active       account enabled/disabled flag
created_at      creation timestamp
updated_at      update timestamp
```

Indexes:

```text
idx_app_user_role
idx_app_user_active
```

Current database responsibility:

- Store application users
- Store password hashes
- Store roles for dashboard routing
- Store active/inactive status

Not currently implemented in SQL:

- Organizations
- Locations
- Memberships
- Equipment assets
- Equipment usage logs
- Maintenance events
- Camera events
- Dashboard metrics
- Notifications
- Login audit history

<<<END SECTION: DATABASE OVERVIEW>>>

<<<BEGIN SECTION: DEMO USERS>>>

Demo seed script:

```text
backend/scripts/seed-demo-users.js
```

Seeded accounts:

```text
owner@iron-temple.com / Business123!
ops@fitdistrict.io / Business123!
member@easygymlife.app / EGLUser123!
welcome@easygymlife.app / EGLUser123!
```

Roles:

```text
owner@iron-temple.com      -> business
ops@fitdistrict.io         -> business
member@easygymlife.app     -> gim
welcome@easygymlife.app    -> gim
```

These are public demo application credentials, not database credentials and not production user credentials.

<<<END SECTION: DEMO USERS>>>

<<<BEGIN SECTION: PLANNED DATA MODEL>>>

The intended future model is larger than the current database.

Likely future entities:

```text
roles
users or expanded app_user
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

Likely relationships:

```text
organizations 1 -> many locations
locations 1 -> many equipment assets
equipment categories 1 -> many equipment assets
equipment assets 1 -> many usage logs
equipment assets 1 -> many maintenance events
locations 1 -> many vision events
users 1 -> many login audit rows
metrics tables -> dashboard API responses
```

Camera-vision design principle:

Store processed event summaries first, not raw video. Raw video storage should require a specific privacy, retention, and security decision.

Example future vision event:

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
    "poseMode": "stick_figure_mesh"
  }
}
```

<<<END SECTION: PLANNED DATA MODEL>>>

<<<BEGIN SECTION: LOCAL DEVELOPMENT COMMANDS>>>

Install dependencies:

```bash
npm install
flutter pub get
```

Run backend from project root:

```bash
npm run dev
```

Run frontend on stable local web URL:

```bash
flutter run -d web-server --web-hostname localhost --web-port 8080
```

Seed demo users:

```bash
npm run backend:seed
```

Apply database schema:

```bash
psql -h YOUR_HOST -p 5432 -U YOUR_USER -d YOUR_DATABASE -f backend/sql/schema.sql
```

Expected local URLs:

```text
Backend: http://localhost:3000
Frontend: http://localhost:8080 when using the stable web command
```

Flutter may use a random port when run with `flutter run -d chrome`.

<<<END SECTION: LOCAL DEVELOPMENT COMMANDS>>>

<<<BEGIN SECTION: ENVIRONMENT AND SECRETS>>>

Frontend-safe config:

```text
assets/config/app.env
assets/config/app.env.example
```

Backend-secret config:

```text
backend/.env
backend/.env.example
```

Ignored local files:

```text
assets/config/app.env
backend/.env
TECHNICAL_KNOWLEDGE.md
node_modules/
backend/node_modules/
build/
.dart_tool/
```

Do not commit:

- Real JWT secrets
- Real database passwords
- Database master credentials
- Production infrastructure secrets

Known config mismatch:

```text
assets/config/app.env.example: JWT_ISSUER=egl-auth-service
backend/.env.example: JWT_ISSUER=gim-auth-service
server.js default: egl-auth-service
```

Use one issuer value consistently when testing JWT profile routes.

<<<END SECTION: ENVIRONMENT AND SECRETS>>>

<<<BEGIN SECTION: BEFORE CODING OR TESTING>>>

Before changing anything:

1. Check `git status --short`.
2. Read the relevant source file, not only docs.
3. Preserve unrelated user changes.
4. Keep secrets out of tracked files.
5. Keep Flutter separated from direct database access.
6. Be clear about current implementation versus planned features.
7. If changing roles, update frontend, backend, and schema assumptions together.
8. If adding database tables, document relationships and seed behavior.
9. If adding backend routes, define validation and response shape before coding.
10. If adding dashboard data, prefer backend API responses over hardcoded frontend data.

Useful validation commands:

```bash
flutter analyze
flutter test
python3 -m py_compile tools/render_model_tree_pdf.py
```

There is no complete automated test suite in the current project. Add focused tests when changing behavior with meaningful risk.

<<<END SECTION: BEFORE CODING OR TESTING>>>

<<<BEGIN SECTION: CURRENT RISKS AND WATCHPOINTS>>>

Main watchpoints:

- `lib/main.dart` is large and currently owns many responsibilities.
- Dashboard values are mostly representative, not backend-driven.
- `developer_admin` exists in SQL but is unsupported in Flutter routing.
- `/api/vision/events` is planned but not implemented.
- No SQL tables exist yet for equipment, camera events, organizations, locations, metrics, or audit logs.
- No test suite is present beyond generated native test placeholders.
- Backend requires a valid `JWT_SECRET`.
- Local env files are intentionally ignored and may differ between machines.
- Generated folders are present in the working tree and should not be confused with source.

Best next engineering milestones:

- Align JWT issuer examples.
- Add frontend support or explicit rejection handling for `developer_admin`.
- Add backend tests for auth routes.
- Add first dashboard metrics endpoint.
- Add first equipment or vision-event schema migration.
- Replace static dashboard values with API-backed summaries.

<<<END SECTION: CURRENT RISKS AND WATCHPOINTS>>>

