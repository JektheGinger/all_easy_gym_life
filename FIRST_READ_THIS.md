# First Read This

This file is the quickest way for a new developer or collaborator to understand how this project works, what tools it uses, what needs to be installed, and how to run it successfully.

It is written for people who may be using:

- macOS
- Windows
- Linux
- or a separate compute device such as a Raspberry Pi for camera-vision processing

## What This Project Is

This project is a role-based application with:

- a `Flutter` frontend
- a `Node.js / Express` backend
- a relational database layer

The basic idea is:

- business-affiliated users log in and go to a business dashboard
- general GIM users log in and go to a general user dashboard
- the backend decides which dashboard to return based on stored credentials and roles

## What Flutter Is

Flutter is a UI framework made by Google for building apps from one codebase.

Instead of writing:

- one app in Swift for iPhone
- another in Kotlin for Android
- another in JavaScript for web

you write one Flutter app in `Dart`, and Flutter can run it across multiple platforms.

In practical terms for this project:

- Flutter builds the screens, forms, buttons, dashboards, and visuals
- Flutter does not directly talk to the database
- Flutter calls the backend API and displays what the backend returns

## What Each Tool Does

### Flutter

- Builds the frontend application
- Runs in Chrome for the current demo workflow
- Can later target macOS, iOS, Android, Windows, and Linux

### Dart

- The programming language used by Flutter
- You will mostly interact with it indirectly through Flutter commands and Flutter source files

### Node.js

- The runtime that executes the backend JavaScript code
- Needed so the Express API can run

### Express

- A backend web framework for Node.js
- Used here to create login routes, issue JWTs, and connect to the database

### npm

- Node’s package manager
- Installs backend dependencies and runs project scripts

### PostgreSQL / Aurora PostgreSQL

- The relational database layer for production or demo hosting
- Stores users, roles, metrics, equipment data, and future camera/vision results

### JWT

- JSON Web Tokens
- Used by the backend to represent authenticated app sessions
- The backend signs and validates these tokens
- The frontend receives and uses them, but should not create them

## Supported Machine Roles

Different teammates may interact with this project from different kinds of machines:

- `developer laptop`
  - runs Flutter, Node, and general setup commands
- `demo laptop`
  - runs the frontend and backend for presentations
- `database host`
  - Aurora PostgreSQL in AWS, or another managed database service
- `camera / sensor implementation`
  - a Raspberry Pi or similar device that captures or processes machine vision events

The key idea is that not every machine has to do everything.

## Light Overview Of How Everything Interacts

At a high level:

```text
Flutter frontend -> Express backend -> PostgreSQL database
```

The normal request flow is:

1. user opens the Flutter app
2. Flutter displays the login screen
3. user enters email and password
4. Flutter sends credentials to Express
5. Express validates the user in the database
6. Express returns a JWT and user role
7. Flutter routes the user to the correct dashboard

## Role-Based Dashboard Plan

The intended role behavior is:

- `business user`
  - registered business or affiliated organizational account
  - should see the business dashboard
  - dashboard may include operational metrics, equipment insights, warranty alerts, or usage analytics

- `general GIM user`
  - standard end user
  - should see the general dashboard
  - dashboard may include personal-facing features, usage data, gym activity, rewards, or check-in information

- `developer/admin`
  - internal support role
  - intended for maintenance and advanced tools if needed later

The backend is responsible for making this distinction. Flutter simply renders the correct screen based on the returned role.

## How Camera Vision Fits Into This

Camera vision should not be treated as frontend logic.

The better design is:

1. cameras or sensors capture data
2. a processing service or backend component interprets that data
3. processed events or summaries are stored in the database
4. Express exposes API endpoints for those summaries
5. Flutter reads those endpoints and turns them into charts, alerts, and dashboard visuals

So the frontend should receive:

- processed counts
- event summaries
- occupancy or usage metrics
- warnings or recommendations

The frontend should not be responsible for heavy vision computation or raw database access.

### Raspberry Pi Camera-Vision Role

If a Raspberry Pi 3 or 5 is used for camera vision, it should ideally act like a worker or edge device.

The cleanest model is:

1. Raspberry Pi captures or processes vision input
2. Pi sends processed events or summaries to the backend API
3. backend validates and stores those records
4. frontend displays the aggregated results

Examples of data the Pi might send:

- occupancy estimates
- machine usage detections
- alert events
- confidence scores
- timestamps and camera identifiers

The Pi should not usually:

- connect directly to the frontend
- hold frontend secrets
- connect directly to the database unless there is a very deliberate secure design

The preferred pattern is:

```text
Raspberry Pi -> Express API -> Database -> Flutter dashboard
```

## What Needs To Be Installed

This section includes beginner paths for macOS, Windows, and Linux.

### 1. Git

Git is needed to clone and update the repository.

Check whether it is installed:

```bash
git --version
```

If not, the Git project lists several macOS options, including Xcode Command Line Tools and Homebrew:

- https://git-scm.com/install/mac

The easiest macOS command is often:

```bash
xcode-select --install
```

For Windows, Git’s official installer page is:

- https://git-scm.com/install/windows

One official option listed there is:

```powershell
winget install --id Git.Git -e --source winget
```

For Linux, install Git with your distro package manager.

Ubuntu or Debian:

```bash
sudo apt-get update -y
sudo apt-get install -y git
```

Fedora:

```bash
sudo dnf install git
```

### 2. Homebrew

Homebrew is optional, but it makes installing developer tools much easier.

Official install docs:

- https://brew.sh/
- https://docs.brew.sh/Installation

Install command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, verify:

```bash
brew --version
```

Windows and Linux do not use Homebrew as the normal default for this project, so this section is mainly for macOS.

### 3. Node.js

Node.js is required for the backend.

Official downloads:

- https://nodejs.org/en/download
- Node.js recommends using an `LTS` release for production-style work

You can install it with Homebrew:

```bash
brew install node
```

On Windows, use the official Node.js installer or downloads page:

- https://nodejs.org/en/download

On Linux, use the official Node.js guidance or your distro package manager. Use an `LTS` release for this project.

Verify:

```bash
node -v
npm -v
```

### 4. Flutter

Flutter is required for the frontend.

Official install docs:

- https://docs.flutter.dev/get-started/install/macos
- troubleshooting: https://docs.flutter.dev/get-started/install/help

Official install pages by platform:

- macOS: https://docs.flutter.dev/get-started/install/macos
- Windows/manual install overview: https://docs.flutter.dev/install/manual
- Linux: https://docs.flutter.dev/get-started/install/linux

Flutter also provides target-platform setup guides:

- Windows desktop: https://docs.flutter.dev/platform-integration/windows/setup
- Linux desktop: https://docs.flutter.dev/platform-integration/linux/setup
- macOS desktop: https://docs.flutter.dev/platform-integration/macos/setup

If you prefer the quick macOS path, Flutter’s docs also support setup through VS Code or manual SDK installation.

One common Homebrew-based approach is:

```bash
brew install --cask flutter
```

Then verify:

```bash
flutter --version
flutter doctor
```

If `flutter` is not found after install, use Flutter’s official PATH troubleshooting guide:

- https://docs.flutter.dev/get-started/install/help

For Windows and Linux, the same verification commands apply after installation:

```bash
flutter --version
flutter doctor
```

### 5. Optional Tools

- `Google Chrome Dev`
  - useful if you want a separate browser for development
- `VS Code`
  - recommended editor for Flutter and Node work
- `Xcode`
  - only required if you want macOS/iOS native targets
  - not required for the current Chrome/web workflow
- `Visual Studio`
  - required for native Windows desktop Flutter builds
  - not the same thing as VS Code
- Linux desktop build tools
  - Flutter’s Linux docs require packages such as `clang`, `cmake`, `ninja-build`, `pkg-config`, and `libgtk-3-dev` if you want native Linux desktop builds

## What You Do Not Need To Install Separately

- Express is installed through `npm install`
- most backend dependencies are installed from `package.json`
- Flutter packages are installed through `flutter pub get`

## Beginner Setup Order

Use this order if you are starting from scratch:

1. install Git
2. install Homebrew
3. install Node.js
4. install Flutter
5. clone the repository
6. install project dependencies
7. run the backend
8. run the frontend

If the person is only helping with camera-vision processing on a Raspberry Pi, they may not need the full Flutter toolchain. In that case they would usually need:

- Git
- Node.js or Python, depending on the worker implementation
- access to the backend API
- environment configuration for the worker process

## Project Setup Steps

From the project root:

```bash
cd "/path/to/all_easy_gym_life"
```

Install root and backend dependencies:

```bash
npm install
```

If Flutter dependencies are not installed yet:

```bash
flutter pub get
```

On Windows, run the same commands in PowerShell or Command Prompt from the project folder.

On Linux, run the same commands in your terminal from the project folder.

## Local Run Order

For the simplest local workflow:

```bash
npm run dev
```

This starts:

- backend on `http://localhost:3000`
- frontend on `http://localhost:8080`

Then open:

```text
http://localhost:8080
```

If you run Flutter directly with:

```bash
flutter run -d chrome
```

Flutter may choose a temporary app port such as:

```text
http://localhost:52036
```

That changing port is normal.

### Cross-Platform Local Run Notes

#### macOS

- easiest current workflow: web/Chrome
- command:

```bash
npm run dev
```

#### Windows

- easiest current workflow: web/browser
- command:

```powershell
npm run dev
```

#### Linux

- easiest current workflow: web/browser
- command:

```bash
npm run dev
```

## Important Running Notes

- The backend must be running or login will fail
- The frontend and backend are separate processes
- The Flutter app URL is not the same thing as the Dart VM service URL
- The DevTools URL is not the same thing as the frontend app URL

## If You Need To Run Things Separately

Backend only:

```bash
npm run dev:backend
```

Frontend only:

```bash
npm run dev:frontend
```

Chrome Dev specific:

```bash
npm run dev:chrome-dev
```

If someone wants to run Flutter manually instead of using the npm helper:

```bash
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 8080
```

## Database Notes

For local demo work, the backend still needs working database credentials and schema setup.

Longer term, the likely production-style direction is:

- AWS Aurora PostgreSQL
- backend-managed credentials
- app-specific DB user
- master account kept private and not used by the app

The frontend should never hold direct database credentials.

## Integration Notes For Camera-Vision Contributors

If someone is building the camera-vision side, their job should focus on producing structured events rather than building dashboard UI.

A good integration contract would look like:

```json
{
  "cameraId": "CAM-001",
  "locationId": "LOC-001",
  "eventType": "machine_usage_detected",
  "equipmentCode": "PTRM1001",
  "confidenceScore": 0.93,
  "eventTimestamp": "2026-04-19T21:15:00Z",
  "metadata": {
    "durationSeconds": 120,
    "zone": "Cardio"
  }
}
```

That can then be:

1. validated by Express
2. stored in PostgreSQL
3. rolled into dashboard metrics
4. displayed in Flutter

## Security Basics

The most important rules are:

- never commit real secrets to Git
- keep `backend/.env` private
- keep JWT signing secrets only on the backend
- do not let Flutter connect directly to the database
- use least-privilege DB accounts

## Where To Read More

- `PROJECT_GUIDE.md`
  - full project workflow and local dev guidance
- `backend/BACKEND_GUIDE.md`
  - backend-specific guide
- `TECHNICAL_KNOWLEDGE.md`
  - local-only deep architecture and schema thinking

## Questions That Would Help The Next Revision

If you want this guide to become even more specific, the most useful questions to answer are:

1. Will camera vision send data directly to Express, or through a separate processing service first?
2. Will the initial investor demo use local development only, or AWS-hosted backend plus database?
3. Will Windows and Linux users only access the web version, or do you want native desktop support documented too?
4. Will Raspberry Pi workers use Python, Node.js, or another runtime?
5. Do you want beginner instructions for AWS Aurora setup included here, or kept in a separate deployment guide?

## Common Questions

### Why do I need both Flutter and Node?

Because they solve different parts of the app:

- Flutter = frontend UI
- Node/Express = backend logic and API

### Why is `npm run dev` not enough by itself in some cases?

Because Flutter and Node are separate systems. In this repo, `npm run dev` has been set up to help launch both together for local development, but Flutter still has to exist on the machine.

### Why does the app URL change sometimes?

If you use `flutter run -d chrome`, Flutter often chooses a temporary localhost port for that session.

### Why can’t the app log in even though the screen loads?

Because the frontend can render without the backend, but authentication depends on the Express API being live and reachable.

### Does the frontend ever connect directly to the database?

No. It should always go through the backend.

### Do we still need JWT if we use AWS?

Usually yes, unless you replace app authentication with a managed identity system such as Cognito. Aurora alone does not replace app-session tokens.

### Does everyone need Xcode?

No. Not if they are only running the Chrome/web workflow.

### Does everyone need Homebrew?

No, but it makes installation much easier on macOS.

### What should I do first if something is broken?

Check these in order:

1. `node -v`
2. `npm -v`
3. `flutter --version`
4. `flutter doctor`
5. `npm install`
6. `flutter pub get`
7. `npm run dev`

### What is the easiest way to explain the system to someone new?

Use this sentence:

`Flutter shows the app, Express handles the logic, and PostgreSQL stores the data.`
