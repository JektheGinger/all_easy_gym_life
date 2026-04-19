# Demo Runbook

This document is the shared playbook for how the team should run, present, and explain the project during a demo.

It is meant to make sure everyone is aligned on:

- what is being shown
- what credentials are being used
- what must be running before the demo starts
- who says what if something fails

## Demo Purpose

The goal of the demo is to show that:

1. Flutter can present a clean user-facing interface
2. Express can act as the backend authentication and data layer
3. role-based routing works
4. the system can be extended to include equipment analytics and camera-vision data

## What Is Live Versus Simulated

### Live

- frontend application flow
- backend route structure
- login request pattern
- role-based routing concept

### Simulated or Representative

- some dashboard values
- some seeded app accounts
- the full camera-vision event pipeline

This distinction is important so the team presents the product honestly and consistently.

## Demo Accounts

These are application-level public demo credentials, not database master credentials or infrastructure secrets.

### Business Demo Account

- Email: `owner@iron-temple.com`
- Password: `Business123!`
- Expected result:
  - routes to the business dashboard
  - used to explain operational/business analytics flow

### General GIM Demo Account

- Email: `member@gimlife.app`
- Password: `GimUser123!`
- Expected result:
  - routes to the general user dashboard
  - used to explain the standard user experience

### Optional Internal Admin Demo Account

Only include this later if an internal admin view exists.

## What Must Be Running Before The Demo

### Required

- backend API
- frontend web app
- correct environment configuration

### Nice To Have

- seeded demo accounts
- database connectivity confirmed
- backup browser tab already open
- fallback talking points if login fails

## Standard Demo Startup

From the project root:

```bash
npm install
npm run dev
```

Expected URLs:

- backend: `http://localhost:3000`
- frontend: `http://localhost:8080`

Open the frontend in the browser and confirm the login page is visible before the demo starts.

## Pre-Demo Checklist

Before presenting:

1. confirm `npm run dev` starts cleanly
2. confirm the login page loads
3. confirm the backend status page loads at `localhost:3000`
4. test the business demo login once
5. test the general demo login once
6. keep credentials ready in a note
7. keep one backup terminal visible

## Suggested Demo Flow

### 1. Quick System Intro

Say:

`Flutter is our frontend, Express is our backend, and the database stores users, roles, and future operational or camera-derived metrics.`

### 2. Show The Login Page

Explain:

- one frontend experience
- role-based logic
- backend-driven authentication

### 3. Business Dashboard Demo

Use the business demo account.

Explain:

- business users receive a different interface
- this is where equipment analytics, occupancy, warranty alerts, or business metrics would appear

### 4. General User Dashboard Demo

Use the general user demo account.

Explain:

- general users are routed differently
- the same backend decides what they should see
- frontend adapts based on role

### 5. Camera-Vision Future Path

Explain:

- Raspberry Pi devices can run lightweight Python vision processing
- they would send structured event summaries to the backend
- the backend would store and aggregate those results
- Flutter would visualize the output in the dashboards

## Demo Talking Points

Good short explanations:

- `This is a single frontend with role-based routing.`
- `The backend determines which dashboard the user receives.`
- `The architecture is modular, so camera-vision workers can be added without rewriting the frontend.`
- `We are using a path that can scale from demo mode into a more production-ready deployment.`

## What Not To Claim During The Demo

Avoid saying:

- the system is fully production-ready
- the camera-vision pipeline is already complete
- the hosting/security architecture is final
- all dashboard metrics are already live operational data

Safer phrasing:

- `This demonstrates the platform direction and working architecture.`
- `This shows the intended user flow and backend structure.`
- `This is the foundation for the analytics and camera-vision layer we are building next.`

## If Something Goes Wrong

### If The Frontend Loads But Login Fails

Say:

`The UI is running correctly. The failure is likely in backend connectivity or seeded demo data, not the frontend structure itself.`

Then check:

1. is backend running?
2. is the database reachable?
3. are demo accounts seeded?

### If The Browser Port Changes

Say:

`When Flutter is run directly in Chrome it can choose a temporary port. Our standard shared workflow uses localhost:8080 to keep it stable.`

### If The Camera-Vision Piece Is Asked About

Say:

`For the current phase, we are demonstrating the platform pathway. The Raspberry Pi vision worker is designed to feed structured events into the same backend so that future analytics can be displayed in the same dashboards.`

## Demo-Day Roles

Suggested split:

- Presenter 1
  - explains the problem and architecture
- Presenter 2
  - drives the login and dashboard flow
- Presenter 3
  - explains the Raspberry Pi / analytics expansion path
- Support person
  - watches terminals and backend health during the demo

## Team Reminder

- do not expose real secrets during the demo
- do not use database master credentials live
- use app-level demo credentials only
- keep one stable workflow: `npm run dev`
