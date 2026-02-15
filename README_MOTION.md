# MotionKit Integration

## Core Components
- `PitchInsights/Utilities/MotionKit/MotionTypes.swift`
  - `MotionEvent`, `MotionPayload`, `MotionScope`, `MotionSettings`
- `PitchInsights/Utilities/MotionKit/FeedbackController.swift`
  - Sound + Haptics orchestration (settings-aware)
- `PitchInsights/Utilities/MotionEngine.swift`
  - Global event pipeline, queue/throttle, toast/banner/progress state
- `PitchInsights/Utilities/MotionKit/MotionPresenter.swift`
  - Global overlay renderer (`MotionOverlayLayer`) + inline highlight modifiers

## Root Wiring
- `PitchInsights/PitchInsightsApp.swift`
  - Uses `MotionEngine.shared` as environment object
  - Adds one global overlay: `MotionOverlayLayer()`

## Where to emit events
Use the helper methods in:
- `PitchInsights/State/AppDataStore+Motion.swift`

Recommended hooks in action flows:
- success create: `motionCreate(...)`
- success update: `motionUpdate(...)`
- success delete: `motionDelete(...)`
- running task: `motionProgress(...)` and `motionClearProgress()`
- errors: `motionError(error, scope: ..., title: ...)`

## Current module hooks
Already wired in store actions:
- Kader/Spieler (`AppDataStore.swift`)
- Kalender + Analyse (`AppDataStore.swift`)
- Trainingsplanung (`AppDataStore+Training.swift`)
- Dateien (`AppDataStore+Files.swift`)
- Messenger (`AppDataStore+Messenger.swift`)
- Mannschaftskasse (`AppDataStore+Cash.swift`)
- Verwaltung (`AppDataStore+Admin.swift`)
- Settings/Bootstrap/Auth session (`AppDataStore+Settings.swift`, `AppSessionStore.swift`, `AppDataStore.swift`)

## Settings
UI controls are in:
- `PitchInsights/Views/Modules/Settings/FeedbackSettingsView.swift`

Persisted keys:
- `MotionSettings.storageKey` (`UserDefaults`)

Available controls:
- Animation intensity (`subtle`, `normal`, `strong`)
- Sounds on/off
- Haptics on/off
- Reduce Motion respect on/off

## Adding new events
1. Pick a scope (`MotionScope`) for the module.
2. Emit from the success/failure point in the existing action flow.
3. Include a stable `contextId` when possible (UUID/string) for inline highlight.
4. Use `motionError(...)` for all failures to avoid silent errors.
