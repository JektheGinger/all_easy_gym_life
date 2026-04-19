# Raspberry Pi Guide

This folder is reserved for everything related to the Raspberry Pi camera-vision side of the project.

The reason for separating it from Flutter is simple:

- Flutter is the frontend application
- Express is the backend API
- Raspberry Pi is a separate worker or edge-processing system

That means the Raspberry Pi side can evolve independently without forcing the frontend codebase to absorb camera-processing logic.

## Intended Role

The Raspberry Pi system is intended to:

- capture camera input
- run lightweight Python-based computer-vision processing
- identify humans in the gym
- estimate traffic and occupancy
- identify basic movement/workout-like actions such as push-ups or sit-ups
- send processed events or summaries to the backend API

The Raspberry Pi should not:

- directly serve as the frontend
- directly expose the database to users
- store unnecessary sensitive media long term unless there is a clear retention reason

## Recommended Architecture

```text
Raspberry Pi (Python vision worker)
        ->
Express API
        ->
Aurora PostgreSQL
        ->
Flutter dashboards
```

## Folder Purpose

This folder can later contain:

- Python worker code
- camera input adapters
- event payload definitions
- local Pi setup notes
- test scripts
- deployment notes specific to Raspberry Pi hardware

## Suggested Future Structure

```text
raspberry_pi/
- README.md
- requirements.txt
- worker/
- sample_payloads/
- scripts/
- docs/
```

## Suggested Event Output

A likely event output shape for the Pi side is:

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

## What The Vision Team Should Aim For First

Since the current goal is feasibility and demo readiness, the first version of the Raspberry Pi pipeline should aim for lightweight, useful, and explainable outputs rather than perfect computer vision.

Recommended first-phase goals:

1. identify that a human is present
2. estimate how many humans are present in a zone
3. classify a small set of simple activity labels
4. send compact event summaries to the backend

Recommended first-phase activity labels:

- `standing`
- `walking`
- `push_up`
- `sit_up`
- `unknown_exercise`

Recommended first-phase non-goals:

- precise individual identity recognition
- heavy facial recognition
- raw video archival for normal dashboard use
- high-volume frame uploads to the backend

This keeps the system lighter, more privacy-conscious, and more realistic for a Raspberry Pi.

## What Data Is Most Important To Collect

For the current project scope, the most useful fields are:

- `cameraId`
- `locationId`
- `zone`
- `eventType`
- `humanCount`
- `activityLabel`
- `confidenceScore`
- `eventTimestamp`
- `equipmentCode` when relevant

This is useful because it supports:

- occupancy estimates
- traffic summaries
- simple workout detection
- dashboard metrics
- future analytics without requiring raw media to be stored all the time

## Notes On Human Detection And Models

The Raspberry Pi side may eventually need a lightweight model that can identify a human or basic pose structure.

That is likely a separate learning and implementation step for the vision side of the team.

For now, the important architectural point is:

- the Pi team does not need to solve every vision problem immediately
- they only need to produce structured event data that fits the backend contract

That means the first target is not:

`build a perfect full vision system`

The first target is:

`produce lightweight, structured human-activity event summaries reliably`

## First-Draft Backend Contract

The current recommended target for the vision side is a backend route like:

```text
POST /api/vision/events
```

The purpose of this route would be:

- accept structured camera-vision events from Raspberry Pi workers
- validate the payload
- store the event
- optionally update derived metrics later

## Integration Principle

The Raspberry Pi side should send structured data to the backend API.

The backend should:

- validate the payload
- store the event
- update aggregated metrics if needed
- expose the data to Flutter through dashboard endpoints

That keeps the system modular and makes it easier for different teammates to work without stepping on one another.
