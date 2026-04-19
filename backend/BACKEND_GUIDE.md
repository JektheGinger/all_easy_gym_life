# Backend

If you are new to the project, read `../FIRST_READ_THIS.md` first and then return here for backend-specific steps.

This folder contains the Node.js and Express API for the Flutter app.

## What it does

- accepts login requests from Flutter
- checks the user in Aurora PostgreSQL / PostgreSQL
- compares hashed passwords with `bcryptjs`
- signs JWTs on the server
- returns the user's role so Flutter knows which dashboard to open

## Why this lives in its own folder

Flutter and Node use different toolchains:

- Flutter uses `pubspec.yaml`
- Node uses `package.json`

Keeping the backend in `backend/` prevents npm and Flutter from stepping on each other.

## Install

```bash
cd backend
npm install
cp .env.example .env
```

Important: `JWT_SECRET` is required. The backend no longer falls back to an insecure development default.

## Run

```bash
npm run dev
```

## Main endpoints

- `GET /api/health`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/vision/events` (planned)

## Notes

The JWT secret belongs here on the server, not in the Flutter app.

The backend uses parameterized SQL queries to reduce SQL injection risk when handling request data.

## Planned Vision Event Endpoint

The backend will likely need a route for Raspberry Pi or Python-based vision workers to submit structured events.

Proposed route:

```text
POST /api/vision/events
```

### Why this route matters

This gives the camera-vision side a clear integration target:

- the Pi team knows what to send
- the backend team knows what to validate
- the frontend team knows what derived data can later appear in dashboards

### First-Draft Request Body

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

### Suggested Required Fields

- `cameraId`
- `locationId`
- `eventType`
- `humanCount`
- `confidenceScore`
- `eventTimestamp`

### Suggested Optional Fields

- `equipmentCode`
- `activityLabel`
- `metadata`

### Suggested Validation Rules

- `cameraId` must be a non-empty string
- `locationId` must be a non-empty string
- `eventType` must be a known event label
- `humanCount` must be an integer greater than or equal to `0`
- `confidenceScore` must be a number between `0` and `1`
- `eventTimestamp` must be a valid ISO timestamp
- `metadata` should be a small JSON object, not a large raw payload

### Suggested First-Phase Event Types

- `human_presence_detected`
- `human_activity_detected`
- `occupancy_snapshot`
- `zone_traffic_update`

### Suggested Success Response

```json
{
  "message": "Vision event accepted.",
  "eventId": "generated-event-id"
}
```

### Suggested Error Response

```json
{
  "message": "Invalid vision event payload."
}
```

### Practical Recommendation

For the first implementation, the backend should accept lightweight event summaries, not raw video frames.

That means:

- better performance
- lower storage overhead
- simpler validation
- easier demo readiness
