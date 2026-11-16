# CLAUDE.md — Glasses → Google Drive (iOS, Meta Wearables DAT)

## What this repo is
An iOS app (fork of Meta's `CameraAccess` sample from `facebook/meta-wearables-dat-ios`)
that captures photos from **Ray-Ban Meta Gen 2** glasses via the Meta Wearables
Device Access Toolkit (DAT) and saves each photo into a **Google Drive folder**
picked once through the iOS Files app (security-scoped bookmark — no OAuth).

Full plan, phases and acceptance criteria: **`PLAN.md`**. Always read it first and
work on the first phase that is not marked done.

## Owner
- Senior Java developer, new to Swift/iOS — explain iOS-specific decisions briefly.
- Communicate with the owner **in Bulgarian**; code, identifiers, commit messages and
  comments in **English**.
- The owner has **only an iPhone** (no Mac). Every step he must do himself has to be
  doable on the iPhone, or explicitly marked as "needs a PC once".

## Hard constraints
- **Zero cost**: no paid Apple Developer account, no paid services.
- Installation is via **SideStore** with a free Apple ID → the app is re-signed on
  device. Therefore:
  - The CI build is **unsigned** (`CODE_SIGNING_ALLOWED=NO`).
  - Do **not** add entitlements/capabilities that a free account can't get
    (push notifications, App Groups, iCloud, HealthKit, NFC, etc.).
  - Max 3 sideloaded apps (SideStore counts as one).
- DAT runs in **Developer Mode** (no `META_APP_ID` needed) until Phase 3.

## You cannot build locally
This environment is Linux; `xcodebuild` is unavailable. The only build is GitHub
Actions (`.github/workflows/build-ipa.yml`, `macos-26` runner). Loop for every change:

1. Commit on a branch, push, open/update a PR (or push to `main` when the owner says so).
2. `gh run watch` (or `gh run list --limit 3` + `gh run view <id>`).
3. On failure: `gh run view <id> --log-failed`, and if needed download the
   `build-log` artifact (`gh run download <id> -n build-log`). Fix, push, repeat.
4. A change is "done" only when CI is green. Tell the owner where to get the `.ipa`
   (rolling release `latest-build`, asset `GlassesToDrive.ipa`).

Never claim a Swift change compiles without a green CI run.

## Code layout
- `CameraAccess/CameraAccess/ViewModels/CameraViewModel.swift` — DAT session/stream
  lifecycle, photo capture (`stream.capturePhoto(format: .jpeg)`), `handlePhotoData`
  saves to Drive.
- `CameraAccess/CameraAccess/ViewModels/DriveFolderStore.swift` — folder bookmark +
  coordinated write into the File Provider (Google Drive).
- `CameraAccess/CameraAccess/Views/CameraView.swift` — UI, incl. `driveFolderButton`.
- The app target uses **explicit file references** (only the test targets use
  synchronized groups). Every new `.swift` file in the app must be added to
  `project.pbxproj` in 4 places: PBXBuildFile, PBXFileReference, its PBXGroup
  `children`, and the app target's Sources build phase (see `DriveFolderStore.swift`).

## Swift / DAT conventions
- Swift 6 strict concurrency: view models are `@MainActor @Observable`; SDK publishers
  call back off-main → hop with `Task { @MainActor in ... }` like the existing code.
- Keep `ListenerToken`s in a `ListenerTokenBag` for the lifetime of the listener.
- For DAT API questions use the official docs
  (https://wearables.developer.meta.com/docs/develop/) and the skills in
  `facebook/meta-wearables-dat-ios/plugins/mwdat-ios/skills/` (camera-streaming,
  camera-capture, inputs, voice-invocations, session-lifecycle). Do not guess API
  names — check them.
- Keep changes small and focused; don't refactor Meta's sample beyond what a phase needs.
