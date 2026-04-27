# Easy Gym Life Flutter Demo

For new contributors, start with `FIRST_READ_THIS.md` before using this guide.

This Flutter app provides a role-aware login flow that sends authenticated users to one of two dashboards:

- Registered business accounts go to the business dashboard.
- Member users go to the member dashboard.

## Project structure

- `lib/`: Flutter frontend
- `backend/`: Node.js + Express API
- `assets/config/app.env`: frontend-facing config values
- `FIRST_READ_THIS.md`: beginner-friendly onboarding guide
- `backend/BACKEND_GUIDE.md`: backend-only guide

The intended split is:

- Flutter handles the UI and user experience.
- Express handles login, JWT creation and verification, and database access.
- Aurora PostgreSQL stores users and roles so the backend can tell Flutter which dashboard to show.

## Environment setup

The app reads non-sensitive config from `assets/config/app.env`. A starter template lives at `assets/config/app.env.example`.

Example values:

```env
APP_NAME=Easy Gym Life (EGL)
API_SCHEME=http
API_HOST=localhost
API_PORT=3000
DB_NAME=easy_gym_life
DB_USER=app_user
JWT_ISSUER=egl-auth-service
BUSINESS_PORTAL_LABEL=Business Dashboard
GIM_PORTAL_LABEL=Easy Gym Life (EGL) Member Dashboard
```

Important: do not place a real JWT signing secret in the Flutter client. Keep signing and token issuance on the backend.

## Public Demo Accounts

- Business demo: `owner@iron-temple.com` / `Business123!`
- Member demo: `member@easygymlife.app` / `EGLUser123!`

These are intentionally public demo-only application accounts. Do not reuse them for real environments.

## Current Frontend Preview State

The server-side authentication flow is still being completed.

To keep frontend progress unblocked, the login screen currently includes:

- `Enter Business Demo Dashboard`
  - opens the business-facing operations dashboard with tabs for home, video, data filter, equipment health, insights, and gym map
- `Enter Member Demo Dashboard`
  - opens the lighter member-facing dashboard focused on workouts, planning, scheduling, calendar-style activity, and consistency-style metrics

These are temporary demo-entry paths, not the final production authentication behavior.

## Run

```bash
flutter pub get
flutter run
```

Important: in this project, the backend and frontend are separate processes.

- `npm run dev` starts the Node/Express backend on `http://localhost:3000`
- `flutter run` starts the Flutter frontend

If you open `http://localhost:3000/` in your browser, you should now see a backend status page, not the full Flutter app UI.

For the simplest local workflow, use:

```bash
npm install
npm run dev
```

Then run Flutter separately with either:

```bash
flutter pub get
flutter run
```

or, for a fixed frontend web URL:

```bash
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 8080
```

`localhost` is not tied to one specific machine. It always means "this same computer" for whoever is running the project, so each teammate can run the app independently with the same URL pattern.

## Important Flutter web URL note

There are three different kinds of local URLs you may see during Flutter web development:

- the actual Flutter app URL
- the Dart VM service URL
- the Flutter DevTools URL

Only the first one is the app you should use in the browser.

If you run:

```bash
flutter run -d chrome
```

Flutter may choose a random local app port such as `http://localhost:52036`. That is normal, and it can change every time you restart the app.

In that case:

- use the browser tab that Flutter opened
- or copy the app URL from the browser address bar
- do not use the VM service or DevTools URL as the app URL

For a stable teammate-friendly URL, prefer:

```bash
flutter run -d web-server --web-hostname localhost --web-port 8080
```

That keeps the frontend on:

```text
http://localhost:8080
```

and the backend on:

```text
http://localhost:3000
```

So the recommended team rule is:

- use `npm run dev` for the backend
- use `flutter run -d web-server --web-hostname localhost --web-port 8080` when you want a stable frontend local URL
- only use `flutter run -d chrome` directly if you are okay with Flutter picking a temporary port

## Backend setup

The backend was added in `backend/` so `npm install` should be run there, not in the Flutter root.

You can now also run npm from the project root because the root `package.json` is configured as a workspace that includes `backend/`.

```bash
cd backend
npm install
cp .env.example .env
```

Create the Aurora PostgreSQL user table:

```bash
psql -h YOUR_HOST -p 5432 -U YOUR_USER -d YOUR_DATABASE -f backend/sql/schema.sql
```

Seed demo accounts:

```bash
npm run seed:demo
npm run dev
```

Or from the project root:

```bash
npm install
npm run dev
```

If you want to run only one side, you can still use:

```bash
npm run dev:backend
npm run dev:frontend
```

If you run Flutter on an Android emulator, change `API_HOST` in `assets/config/app.env` from `localhost` to `10.0.2.2`.

## Why `npm install` was not working

If you run `npm install` in the Flutter project root, npm does not find a Node backend there. In this project that can leave behind an almost-empty `package-lock.json`, but it does not create a usable Express app. The fix is to keep the Node server in its own folder with its own `package.json`, then run npm commands inside that folder.

## Architecture direction

For the business-to-business setup you described, this split is the right foundation:

- Flutter: login UI, dashboards, charts, mobile and desktop presentation
- Node/Express: authentication, JWT signing, role routing, APIs, database access
- Database and storage: user records, analytics, logs, camera/vision outputs, processed events

That means camera vision or data collection should write to backend-managed services first, and Flutter should read summarized results back through APIs instead of trying to own raw processing logic on-device.

## Security notes for Git sharing

Making the workflow easier with `npm run dev` does not reduce security by itself. The main things that matter are:

- do not commit real secrets
- keep `backend/.env` out of Git
- keep `assets/config/app.env` limited to non-sensitive client config
- keep JWT signing secrets only on the backend

For teammates, commit `.env.example` files and setup docs, not real credentials.
