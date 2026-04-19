# Stakeholder Overview

This file is meant for first-time collaborators who may not be working directly in the code every day.

It is especially useful for:

- sales
- marketing
- entrepreneurship or product leads
- advisors
- first-time technical collaborators

## What This Project Is

This project is a role-based platform with:

- a Flutter frontend
- a Node.js / Express backend
- a PostgreSQL-compatible database direction
- a future path for Raspberry Pi camera-vision event ingestion

The core demo idea is:

- business-affiliated users log in and see a business dashboard
- general GIM users log in and see a general user dashboard
- the backend determines which dashboard to return based on credentials and user role

## What Works Today

The project currently demonstrates:

- a frontend login experience
- backend-driven authentication flow
- role-based routing logic
- a structured documentation and onboarding setup
- a path for future camera-vision integration

## Current State Of The Project

This is still a prototype and early demo-stage system.

That means:

- the architecture is real
- the app flow is real
- the demo accounts are intentional
- some dashboard content is still placeholder or simulated
- the camera-vision system is planned and documented, but not fully implemented end-to-end yet

## What Is Real Versus Simulated

### Real

- Flutter frontend structure
- Express backend structure
- login request flow
- role-based dashboard routing
- local development workflow
- database direction and schema planning

### Simulated or Early-Stage

- some dashboard metrics
- some seeded demo users
- camera-vision integration
- production hosting and infrastructure hardening

## Value This Demo Shows

This demo is meant to prove:

- the platform can differentiate user types
- a business-facing dashboard and a user-facing dashboard can coexist in one system
- the architecture can support future analytics and camera-driven operational insights
- the team has a feasible technical structure, not just a loose concept

## How To Describe The Product Simply

Use a short explanation like this:

`This is a role-based gym platform where Flutter handles the user experience, Express handles the logic, and the backend can later ingest camera-vision and operational data to generate business and user dashboards.`

## What Not To Claim Yet

Until more is built, avoid claiming:

- fully production-ready infrastructure
- final camera-vision accuracy
- completed investor-scale analytics
- native mobile/desktop readiness on every platform
- finalized AWS deployment and operational security hardening

A safer phrasing is:

`The current version demonstrates the architecture, role-based experience, and future data-ingestion path.`

## Current Risks Or Complications

Important realities for the team to understand:

- the backend still needs valid environment configuration
- the database and hosting direction are still evolving
- demo data is not the same thing as production data
- camera-vision work depends on future model and pipeline decisions
- some visuals are still representative rather than fully data-driven

## What Sales And Marketing Should Know

- focus on the workflow and value, not infrastructure details
- describe the problem being solved before describing the technical stack
- do not frame public demo credentials as secure real-user credentials
- do not claim that camera vision is fully complete if it is still in planned/integration phase

## What Entrepreneurship / Product Leads Should Know

- the project is already structured enough to coordinate a team
- the next major milestone is a more complete backend-connected dashboard experience
- a hosted database and backend will improve demo credibility
- the investor-facing story should focus on:
  - differentiated user roles
  - business analytics potential
  - camera-driven operational intelligence
  - scalable multi-platform frontend direction

## What Developers Should Know At A Glance

- frontend: Flutter / Dart
- backend: Node.js / Express
- auth: JWT
- database direction: Aurora PostgreSQL / PostgreSQL
- camera vision direction: Raspberry Pi + Python worker sending structured events to the backend

## What Not To Share Publicly

- real backend secrets
- real database credentials
- master database account information
- production JWT secrets
- private architecture notes if they are intentionally kept outside Git

## Best Supporting Docs

- `FIRST_READ_THIS.md`
  - best technical catch-up file
- `DEMO_RUNBOOK.md`
  - best demo and presentation coordination file
- `PROJECT_GUIDE.md`
  - best project setup and development file
