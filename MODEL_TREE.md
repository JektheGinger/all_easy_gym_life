# Easy Gym Life Repository Model Tree

Generated from the current `all_easy_gym_life` project on June 21, 2026.

## Purpose and scope

This document maps how the Flutter application, Node/Express backend, PostgreSQL
schema, assets, platform runners, project configuration, and project
documentation relate to one another.

The repository contains 147 Git-tracked files. Platform-generated files are
grouped by responsibility where they have the same relationship to the Flutter
application. Local-only or untracked files are listed separately because they
are present in the working folder but are not part of the tracked repository.

Relationship labels used below:

- `loads`: reads a file at runtime
- `declares`: makes a dependency or asset available
- `calls`: sends a request to an API route
- `queries`: reads or writes database data
- `builds`: participates in producing a platform application
- `configures`: supplies build-time or runtime settings
- `documents`: explains or operationalizes another file or subsystem
- `planned`: described in documentation but not implemented in current code

## 1. Whole-system model

```text
User
 |
 v
Flutter application
 lib/main.dart
 |  loads frontend-safe configuration
 |  from assets/config/app.env
 |  or assets/config/app.env.example
 |
 |  POST /api/auth/login
 v
Node.js / Express backend
 backend/src/server.js
 |  reads backend/.env
 |  verifies passwords with bcryptjs
 |  signs and verifies JWTs with jsonwebtoken
 |
 |  parameterized SQL through pg
 v
PostgreSQL / Aurora PostgreSQL
 backend/sql/schema.sql
 |
 |  app_user records
 v
Role returned to Flutter
 |
 +--> business --> BusinessDashboard
 |
 +--> gim ------> GimUserDashboard

Planned extension:

Raspberry Pi vision worker
 raspberry_pi/
 |
 |  planned POST /api/vision/events
 v
Express backend --> database summaries --> Flutter business dashboard
```

The backend is the security boundary. Flutter does not directly connect to the
database, and backend secrets should never be placed in Flutter assets.

## 2. Runtime authentication sequence

```text
1. main()
   |
   +--> AppConfigLoader.load()
   |    |
   |    +--> assets/config/app.env, when present
   |    +--> assets/config/app.env.example, as fallback
   |
   +--> GimAccessApp
        |
        +--> LoginPage
             |
             +--> ApiAuthRepository.authenticate()
                  |
                  +--> POST {baseUrl}/api/auth/login
                       |
                       +--> backend/src/server.js
                            |
                            +--> SELECT app_user by email
                            +--> bcrypt.compare()
                            +--> jwt.sign()
                            |
                            +--> JSON: token + user + role
                                 |
                                 +--> AuthSession
                                      |
                                      +--> DashboardRouter
                                           |
                                           +--> BusinessDashboard
                                           +--> GimUserDashboard
```

The login page also has temporary demo-entry callbacks. These create local
`AuthSession` objects without calling Express:

```text
Enter Business Demo Dashboard --> local business AppUser --> BusinessDashboard
Enter Member Demo Dashboard ---> local gim AppUser -------> GimUserDashboard
```

## 3. Flutter source model

The entire application-specific Dart implementation currently lives in
`lib/main.dart` (3,981 lines). It has four logical layers.

### 3.1 Bootstrap and application state

```text
main()
 |
 +--> AppConfigLoader
 +--> GimAccessApp
      |
      +--> ApiAuthRepository
      +--> LoginAuditStore
      +--> AuthSession?
      +--> LoginPage when signed out
      +--> DashboardRouter when signed in
```

- `GimAccessApp` owns the active session and logout behavior.
- `LoginAuditStore` is in-memory only. It is not persisted to PostgreSQL.
- Demo sessions use placeholder tokens and do not authenticate with the server.

### 3.2 Authentication and configuration model

```text
AppConfigLoader --> AppConfig --> ApiAuthRepository
       |                |               |
       |                |               +--> package:http
       |                +--> baseUrl
       +--> rootBundle

API JSON --> userRoleFromApi() --> UserRole
API JSON --> AppUser + token --> AuthSession
errors -----------------------> AuthException
```

- `dart:convert` encodes login requests and decodes API responses.
- `package:http/http.dart` performs the login request.
- `package:flutter/services.dart` supplies `rootBundle` for configuration.
- Supported API roles are `business` and `gim`.
- The SQL schema also permits `developer_admin`, but Flutter currently rejects
  that role as unsupported.

### 3.3 Navigation and dashboard model

```text
DashboardRouter
 |
 +--> UserRole.business
 |    |
 |    +--> BusinessDashboard
 |         |
 |         +--> _BusinessSidebar
 |         +--> _BusinessHeaderCard
 |         +--> _BusinessTbdCard
 |         +--> _BusinessActionCard
 |         +--> source filters
 |         +--> _BusinessContentPanel
 |              |
 |              +--> Home
 |              +--> Video Feed
 |              +--> Data Filter
 |              +--> Equipment Health
 |              +--> Insights
 |              +--> Gym Map
 |
 +--> UserRole.gim
      |
      +--> GimUserDashboard
           |
           +--> _MemberDashboardHeader
           +--> _MemberWelcomeStrip
           +--> responsive layout
                |
                +--> _MemberDashboardWide
                +--> _MemberDashboardStacked
                     |
                     +--> user information
                     +--> calendar
                     +--> planning
                     +--> today's workout
                     +--> schedule
                     +--> workout log
                     +--> focus card
```

Business dashboard values, equipment states, map zones, video placeholders,
and insights are currently representative UI data in `main.dart`. They are not
yet loaded from backend analytics endpoints.

### 3.4 Shared Flutter UI helpers

```text
Color system:          _EglPastels
Logo widget:           _EglLogoMark
Panel decoration:      _panelDecoration()
Member decoration:     _memberPanelDecoration()
Reusable business UI:  status badges, source chips, stat tiles, map markers
Reusable member UI:    pills, action cards, calendar tiles, chart painter
Legacy/shared cards:   _DashboardFrame, _ProfileCard, _ServerCard,
                       _ConfigPanel, _DemoAccountPanel
```

`_EglLogoMark` loads `Project Pictures/EGL Company Logo.png`.

## 4. Backend and database model

```text
Root package.json
 |
 +--> npm workspace: backend/
      |
      +--> backend/package.json
           |
           +--> start/dev --> backend/src/server.js
           +--> seed:demo --> backend/scripts/seed-demo-users.js

backend/.env
 |
 +--> server.js
 |    |
 |    +--> Express middleware
 |    |    +--> cors
 |    |    +--> morgan
 |    |    +--> express.json
 |    |
 |    +--> pg.Pool --> PostgreSQL
 |    +--> bcryptjs --> password verification
 |    +--> jsonwebtoken --> JWT creation and validation
 |
 +--> seed-demo-users.js
      |
      +--> pg.Client --> PostgreSQL
      +--> bcryptjs --> password hashing
```

### 4.1 Implemented routes

| Route | Implemented in | Database relationship | Flutter relationship |
|---|---|---|---|
| `GET /` | `backend/src/server.js` | None | Backend status page only |
| `GET /api/health` | `backend/src/server.js` | Executes `SELECT 1` | Not currently called by Flutter |
| `POST /api/auth/login` | `backend/src/server.js` | Reads `app_user` | Called by `ApiAuthRepository` |
| `GET /api/auth/me` | `backend/src/server.js` | Reads `app_user` by JWT subject | Not currently called by Flutter |
| `POST /api/vision/events` | Documentation only | Planned event storage | Planned dashboard input |

### 4.2 Current database schema

```text
app_user
 |
 +-- id              BIGINT identity primary key
 +-- email           unique login identifier
 +-- password_hash   bcrypt password hash
 +-- role            business | gim | developer_admin
 +-- display_name    frontend display value
 +-- is_active       account access switch
 +-- created_at      creation timestamp
 +-- updated_at      update timestamp
 |
 +-- index: idx_app_user_role
 +-- index: idx_app_user_active
```

`backend/scripts/seed-demo-users.js` inserts or updates four demo users and
depends on the `app_user` table created by `backend/sql/schema.sql`.

### 4.3 Planned data model

The local-only `TECHNICAL_KNOWLEDGE.md` and tracked project guides describe a
future expansion beyond the implemented `app_user` table:

```text
organizations 1 --> many locations
locations 1 ------> many equipment_assets
equipment_categories 1 --> many equipment_assets
equipment_assets 1 ------> many equipment_usage_logs
equipment_assets 1 ------> many maintenance events
locations 1 -------------> many vision_events
users 1 -----------------> many login_audit records
aggregates --------------> dashboard_metrics
```

These entities are design direction only. They are not present in the current
tracked SQL schema.

## 5. Configuration and dependency relationships

### 5.1 Flutter dependency chain

```text
pubspec.yaml
 |
 +--> Flutter SDK
 +--> cupertino_icons
 +--> http
 +--> flutter_test
 +--> flutter_lints
 +--> declared Flutter assets
 |
 +--> resolved versions in pubspec.lock

analysis_options.yaml
 |
 +--> package:flutter_lints/flutter.yaml

.metadata
 |
 +--> Flutter project/tool migration metadata
```

### 5.2 Node dependency chain

```text
package.json
 |
 +--> npm workspace: backend
 +--> root scripts for backend and Flutter launch commands
 +--> concurrently development dependency
 |
 +--> package-lock.json

backend/package.json
 |
 +--> express
 +--> cors
 +--> morgan
 +--> dotenv
 +--> pg
 +--> bcryptjs
 +--> jsonwebtoken
 +--> nodemon
 |
 +--> resolved by root package-lock.json workspace data
```

### 5.3 Environment-file boundary

```text
Frontend-safe:
assets/config/app.env             local, ignored by Git
assets/config/app.env.example     tracked template and runtime fallback

Backend-secret:
backend/.env                      local, ignored by Git
backend/.env.example              tracked template
```

Important consistency note: the frontend template defaults to JWT issuer
`egl-auth-service`, while `backend/.env.example` currently says
`gim-auth-service`. The running backend and frontend should use the same issuer
when token-based profile requests are added.

## 6. Asset relationships

| Asset family | Declared or referenced by | Current status |
|---|---|---|
| `Project Pictures/EGL Company Logo.png` | `pubspec.yaml`, `lib/main.dart` | Active Flutter runtime asset |
| `assets/config/app.env` | `pubspec.yaml`, `AppConfigLoader` | Active when local file exists; ignored by Git |
| `assets/config/app.env.example` | `pubspec.yaml`, `AppConfigLoader` | Active fallback and tracked template |
| `Project Pictures/Updated EGL Company Logo.png` | No code reference | Tracked design alternative |
| `assets/egl_logo.png` | No `pubspec.yaml` declaration or code reference | Tracked but inactive |
| `assets/gym_map.png` | No `pubspec.yaml` declaration or code reference | Tracked but inactive |
| `web/favicon.png` | `web/index.html` | Active web browser icon |
| `web/icons/*.png` | `web/index.html`, `web/manifest.json` | Active web/PWA icons |
| Android `mipmap-*` icons | Android manifest/resource system | Active Android launcher icons |
| iOS app and launch images | iOS asset catalogs/project | Active iOS packaging assets |
| macOS app icons | macOS asset catalog/project | Active macOS packaging assets |
| Windows `app_icon.ico` | `Runner.rc` | Active Windows executable icon |

## 7. Platform runner relationships

All platform folders are adapters around the same Dart entry point and Flutter
asset bundle. They do not implement separate application business logic.

```text
lib/main.dart + pubspec.yaml
 |
 +--> web/
 |    +--> index.html starts flutter_bootstrap.js
 |    +--> manifest.json defines installable web metadata
 |    +--> favicon and PWA icons
 |
 +--> android/
 |    +--> Gradle configuration
 |    +--> AndroidManifest.xml
 |    +--> MainActivity.kt --> FlutterActivity
 |    +--> launch themes and launcher icons
 |
 +--> ios/
 |    +--> Xcode project/workspace
 |    +--> AppDelegate.swift and SceneDelegate.swift
 |    +--> Info.plist and storyboards
 |    +--> app/launch asset catalogs
 |
 +--> macos/
 |    +--> Xcode project/workspace
 |    +--> AppDelegate.swift and MainFlutterWindow.swift
 |    +--> xcconfig, plist, entitlements, menu, icons
 |
 +--> linux/
 |    +--> CMake build graph
 |    +--> GTK runner
 |    +--> generated plugin registrant files
 |
 +--> windows/
      +--> CMake build graph
      +--> Win32 runner
      +--> generated plugin registrant files
      +--> resources and executable manifest
```

### 7.1 Web file group

```text
web/index.html
 +--> web/favicon.png
 +--> web/icons/Icon-192.png
 +--> web/manifest.json
      +--> Icon-192.png
      +--> Icon-512.png
      +--> Icon-maskable-192.png
      +--> Icon-maskable-512.png
```

The web title and description still use the generated name `gym_map_demo`.

### 7.2 Android file group

```text
android/settings.gradle.kts
 +--> locates Flutter SDK
 +--> includes app module

android/build.gradle.kts
android/gradle.properties
android/gradle/wrapper/gradle-wrapper.properties
 +--> configure Gradle build environment

android/app/build.gradle.kts
 +--> Flutter source at repository root
 +--> applicationId com.example.gym_map_demo
 +--> version values from Flutter

android/app/src/main/AndroidManifest.xml
 +--> MainActivity.kt
 +--> launcher icons
 +--> launch/normal themes

debug/profile manifests
 +--> platform-specific development overlays
```

### 7.3 iOS file group

```text
ios/Flutter/*.xcconfig
 +--> Flutter build settings

ios/Runner.xcodeproj + ios/Runner.xcworkspace
 +--> Xcode build graph and schemes
 +--> Runner source, plist, storyboards, and assets

AppDelegate.swift + SceneDelegate.swift
 +--> Flutter engine/application lifecycle

Info.plist
 +--> app identity, version variables, scenes, orientations

RunnerTests.swift
 +--> native iOS test target placeholder
```

### 7.4 macOS file group

```text
macos/Flutter/*.xcconfig
 +--> Flutter build settings

GeneratedPluginRegistrant.swift
 +--> generated plugin registration

Runner.xcodeproj + Runner.xcworkspace
 +--> Xcode build graph and scheme

Runner/Configs/*.xcconfig
 +--> product identity, modes, and compiler warnings

AppDelegate.swift + MainFlutterWindow.swift
 +--> native lifecycle and Flutter window

Info.plist + entitlements
 +--> app metadata and sandbox capabilities

RunnerTests.swift
 +--> native macOS test target placeholder
```

### 7.5 Linux file group

```text
linux/CMakeLists.txt
 +--> linux/flutter/CMakeLists.txt
 +--> linux/runner/CMakeLists.txt
 +--> generated_plugins.cmake

linux/runner/main.cc
 +--> my_application.cc/.h
 +--> GTK window hosting Flutter

generated_plugin_registrant.cc/.h
 +--> generated native plugin registration
```

### 7.6 Windows file group

```text
windows/CMakeLists.txt
 +--> windows/flutter/CMakeLists.txt
 +--> windows/runner/CMakeLists.txt
 +--> generated_plugins.cmake

windows/runner/main.cpp
 +--> flutter_window.cpp/.h
 +--> win32_window.cpp/.h
 +--> utils.cpp/.h

Runner.rc
 +--> resource.h
 +--> resources/app_icon.ico

runner.exe.manifest
 +--> Windows DPI/runtime metadata

generated_plugin_registrant.cc/.h
 +--> generated native plugin registration
```

## 8. Documentation relationship tree

```text
README.md
 |
 +--> directs newcomers to FIRST_READ_THIS.md
 |
 +--> FIRST_READ_THIS.md
 |    +--> explains complete architecture and installation
 |    +--> points developers to PROJECT_GUIDE.md
 |    +--> points backend work to backend/BACKEND_GUIDE.md
 |
 +--> STAKEHOLDER_OVERVIEW.md
 |    +--> non-technical product and status framing
 |
 +--> PROJECT_GUIDE.md
 |    +--> frontend/backend setup
 |    +--> environment templates
 |    +--> local ports and emulator host rules
 |
 +--> DEMO_RUNBOOK.md
 |    +--> startup sequence
 |    +--> demo credentials
 |    +--> presentation claims and fallback steps
 |
 +--> backend/BACKEND_GUIDE.md
 |    +--> backend setup and implemented routes
 |    +--> planned vision-event contract
 |
 +--> raspberry_pi/README.md
      +--> planned edge worker role
      +--> planned event payload
      +--> planned POST /api/vision/events relationship
```

`TECHNICAL_KNOWLEDGE.md` is present locally and expands the planned relational
model, but `.gitignore` excludes it from Git. It is therefore a local design
reference rather than a shared tracked project document.

## 9. Complete tracked-file inventory

The following tree includes every tracked file, with repetitive platform image
families compacted using counts and filename patterns.

```text
all_easy_gym_life/
|
+-- .gitignore
+-- .metadata
+-- README.md
+-- FIRST_READ_THIS.md
+-- PROJECT_GUIDE.md
+-- DEMO_RUNBOOK.md
+-- STAKEHOLDER_OVERVIEW.md
+-- analysis_options.yaml
+-- pubspec.yaml
+-- pubspec.lock
+-- package.json
+-- package-lock.json
|
+-- lib/
|   +-- main.dart
|
+-- assets/
|   +-- config/
|   |   +-- app.env.example
|   +-- egl_logo.png
|   +-- gym_map.png
|
+-- Project Pictures/
|   +-- EGL Company Logo.png
|   +-- Updated EGL Company Logo.png
|
+-- backend/
|   +-- .env.example
|   +-- BACKEND_GUIDE.md
|   +-- package.json
|   +-- src/server.js
|   +-- scripts/seed-demo-users.js
|   +-- sql/schema.sql
|
+-- raspberry_pi/
|   +-- README.md
|
+-- web/
|   +-- index.html
|   +-- manifest.json
|   +-- favicon.png
|   +-- icons/
|       +-- Icon-192.png
|       +-- Icon-512.png
|       +-- Icon-maskable-192.png
|       +-- Icon-maskable-512.png
|
+-- android/ (19 tracked files)
|   +-- .gitignore
|   +-- settings.gradle.kts
|   +-- build.gradle.kts
|   +-- gradle.properties
|   +-- gradle/wrapper/gradle-wrapper.properties
|   +-- app/build.gradle.kts
|   +-- app/src/debug/AndroidManifest.xml
|   +-- app/src/profile/AndroidManifest.xml
|   +-- app/src/main/AndroidManifest.xml
|   +-- app/src/main/kotlin/com/example/gym_map_demo/MainActivity.kt
|   +-- app/src/main/res/drawable/launch_background.xml
|   +-- app/src/main/res/drawable-v21/launch_background.xml
|   +-- app/src/main/res/values/styles.xml
|   +-- app/src/main/res/values-night/styles.xml
|   +-- app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
|       +-- ic_launcher.png (5 files)
|
+-- ios/ (40 tracked files)
|   +-- .gitignore
|   +-- Flutter/AppFrameworkInfo.plist
|   +-- Flutter/Debug.xcconfig
|   +-- Flutter/Release.xcconfig
|   +-- Runner.xcodeproj/project.pbxproj
|   +-- Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
|   +-- Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata
|   +-- Runner.xcodeproj/project.xcworkspace/xcshareddata/
|   |   +-- IDEWorkspaceChecks.plist
|   |   +-- WorkspaceSettings.xcsettings
|   +-- Runner.xcworkspace/contents.xcworkspacedata
|   +-- Runner.xcworkspace/xcshareddata/
|   |   +-- IDEWorkspaceChecks.plist
|   |   +-- WorkspaceSettings.xcsettings
|   +-- Runner/AppDelegate.swift
|   +-- Runner/SceneDelegate.swift
|   +-- Runner/Info.plist
|   +-- Runner/Runner-Bridging-Header.h
|   +-- Runner/Base.lproj/Main.storyboard
|   +-- Runner/Base.lproj/LaunchScreen.storyboard
|   +-- Runner/Assets.xcassets/AppIcon.appiconset/
|   |   +-- Contents.json
|   |   +-- Icon-App-*.png (15 files)
|   +-- Runner/Assets.xcassets/LaunchImage.imageset/
|   |   +-- Contents.json
|   |   +-- README.md
|   |   +-- LaunchImage.png
|   |   +-- LaunchImage@2x.png
|   |   +-- LaunchImage@3x.png
|   +-- RunnerTests/RunnerTests.swift
|
+-- macos/ (28 tracked files)
|   +-- .gitignore
|   +-- Flutter/Flutter-Debug.xcconfig
|   +-- Flutter/Flutter-Release.xcconfig
|   +-- Flutter/GeneratedPluginRegistrant.swift
|   +-- Runner.xcodeproj/project.pbxproj
|   +-- Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
|   +-- Runner.xcodeproj/project.xcworkspace/xcshareddata/
|   |   +-- IDEWorkspaceChecks.plist
|   +-- Runner.xcworkspace/contents.xcworkspacedata
|   +-- Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
|   +-- Runner/AppDelegate.swift
|   +-- Runner/MainFlutterWindow.swift
|   +-- Runner/Info.plist
|   +-- Runner/DebugProfile.entitlements
|   +-- Runner/Release.entitlements
|   +-- Runner/Base.lproj/MainMenu.xib
|   +-- Runner/Configs/
|   |   +-- AppInfo.xcconfig
|   |   +-- Debug.xcconfig
|   |   +-- Release.xcconfig
|   |   +-- Warnings.xcconfig
|   +-- Runner/Assets.xcassets/AppIcon.appiconset/
|   |   +-- Contents.json
|   |   +-- app_icon_{16,32,64,128,256,512,1024}.png
|   +-- RunnerTests/RunnerTests.swift
|
+-- linux/ (10 tracked files)
|   +-- .gitignore
|   +-- CMakeLists.txt
|   +-- flutter/CMakeLists.txt
|   +-- flutter/generated_plugin_registrant.cc
|   +-- flutter/generated_plugin_registrant.h
|   +-- flutter/generated_plugins.cmake
|   +-- runner/CMakeLists.txt
|   +-- runner/main.cc
|   +-- runner/my_application.cc
|   +-- runner/my_application.h
|
+-- windows/ (18 tracked files)
    +-- .gitignore
    +-- CMakeLists.txt
    +-- flutter/CMakeLists.txt
    +-- flutter/generated_plugin_registrant.cc
    +-- flutter/generated_plugin_registrant.h
    +-- flutter/generated_plugins.cmake
    +-- runner/CMakeLists.txt
    +-- runner/main.cpp
    +-- runner/flutter_window.cpp
    +-- runner/flutter_window.h
    +-- runner/win32_window.cpp
    +-- runner/win32_window.h
    +-- runner/utils.cpp
    +-- runner/utils.h
    +-- runner/Runner.rc
    +-- runner/resource.h
    +-- runner/runner.exe.manifest
    +-- runner/resources/app_icon.ico
```

## 10. Local-only and generated working files

These files are present in the current working folder but are not part of the
tracked 147-file tree:

- `assets/config/app.env`: ignored local frontend configuration
- `backend/.env`: ignored backend credentials and secret configuration, if
  created
- `TECHNICAL_KNOWLEDGE.md`: ignored local architecture reference
- `test_opencode.txt`: currently untracked
- `.dart_tool/`, `build/`, `node_modules/`, and similar generated directories:
  ignored dependency/build output when present

## 11. Current gaps and relationship risks

1. `POST /api/vision/events` is documented but not implemented.
2. Dashboard analytics are representative constants in `lib/main.dart`, not
   backend responses.
3. `GET /api/health` and `GET /api/auth/me` are implemented but unused by the
   current Flutter code.
4. `developer_admin` is allowed by SQL but unsupported by Flutter role parsing.
5. `assets/egl_logo.png`, `assets/gym_map.png`, and the updated company logo are
   tracked but not wired into Flutter.
6. Web and native platform metadata still use generated `gym_map_demo` and
   `com.example` identifiers rather than final Easy Gym Life branding.
7. The frontend configuration exposes database name and user values in the UI
   model. They are not secrets in the template, but the frontend does not need
   database connection details to call the API.
8. There is no tracked Dart test directory; native runner test files are still
   template placeholders.
9. `LoginAuditStore` is session-memory UI state and is separate from the
   planned persistent `login_audit` database entity.

## 12. Recommended modular target tree

The current single-file Flutter implementation works for a prototype, but the
natural future file relationship would be:

```text
lib/
+-- main.dart
+-- app/
|   +-- app.dart
|   +-- router.dart
+-- config/
|   +-- app_config.dart
+-- auth/
|   +-- data/api_auth_repository.dart
|   +-- models/app_user.dart
|   +-- models/auth_session.dart
|   +-- presentation/login_page.dart
+-- business/
|   +-- presentation/business_dashboard.dart
|   +-- widgets/
+-- member/
|   +-- presentation/member_dashboard.dart
|   +-- widgets/
+-- shared/
    +-- theme/
    +-- widgets/

backend/src/
+-- server.js
+-- config/
+-- middleware/authenticate-token.js
+-- routes/
|   +-- auth.js
|   +-- health.js
|   +-- vision.js
+-- services/
+-- repositories/
```

This is a recommendation, not a description of the current repository.

