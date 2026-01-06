# TomOS-Apps (Swift iOS/iPadOS/macOS)

## What This Repo Is

Native Swift applications for ADHD-friendly task management across Apple platforms.

**Technology:** SwiftUI, AppKit (macOS menu bar), APNs push notifications
**Platforms:** iOS 16+, iPadOS 16+, macOS 13+
**Target User:** Tom Bragg - Senior Legal Counsel with ADHD workflow needs

## Repository Information

**Local Path:** `/Users/tombragg/Desktop/TomOS-Apps/`
**GitHub:** `github.com/braggy9/TomOS-Apps.git` (Private)
**Related Repo:** [TomOS API](/Users/tombragg/Desktop/Projects/TomOS/) - Vercel backend

## Current Status (Updated 2026-01-03)

### Completed
- ✅ iOS app with push notifications working
- ✅ macOS app with push notifications working
- ✅ Menu bar interface (macOS)
- ✅ APNs device registration for both platforms
- ✅ Local notification scheduler
- ✅ Notification action buttons (Complete, Snooze, View)
- ✅ macOS app installed in /Applications
- ✅ Auto-start on login configured
- ✅ Siri App Intents integration (iOS)
- ✅ Share Extension - "Add to TomOS" from any app
- ✅ Home Screen Widget - Small, Medium, Lock Screen
- ✅ Live Activities - Dynamic Island & Lock Screen (iOS 16.2+)
- ✅ Interactive Widget - Complete/Snooze from widget (iOS 17+)
- ✅ Focus Filters - Auto-filter tasks by Focus mode (iOS 16+)
- ✅ Calendar Sync - View events, create prep tasks (iOS 16+)

### Registered Devices
- **iOS:** `f757db2b408a19ec...`
- **macOS:** `025aeb1d4d823d33...`

## Project Structure

```
TomOS-Apps/
├── TomOS/
│   ├── TomOSApp.swift              # App entry point
│   ├── AppDelegate.swift           # APNs registration (iOS & macOS)
│   ├── ContentView.swift           # Main TabView
│   ├── BrainDumpView.swift         # Batch task entry
│   ├── SmartSurfaceView.swift      # AI recommendations
│   ├── QuickActionsView.swift      # Notification triggers
│   ├── MoreView.swift              # About/Info view
│   ├── MenuBarController.swift     # macOS menu bar + window management
│   ├── GlobalShortcutManager.swift # System-wide ⌘⌥ hotkeys
│   ├── QuickCaptureWindow.swift    # Floating quick capture (⌘⌥T)
│   ├── NotificationManager.swift   # Local notifications
│   ├── APIService.swift            # Backend communication
│   ├── AppIntents.swift            # Siri integration (iOS 16+)
│   ├── LiveActivityManager.swift   # Dynamic Island/Lock Screen (iOS 16.2+)
│   ├── FocusFilter.swift           # Focus mode integration (iOS 16+)
│   ├── CalendarManager.swift       # EventKit calendar sync
│   ├── TomOS.entitlements          # iOS entitlements
│   ├── TomOS.macOS.entitlements    # macOS entitlements
│   └── Assets.xcassets/            # App icons
├── TomOSShare/                     # Share Extension
│   ├── ShareViewController.swift   # Share sheet UI
│   ├── Info.plist
│   └── TomOSShare.entitlements
├── TomOSWidget/                    # Widget Extension (iOS 17+)
│   ├── TomOSWidget.swift           # All widget views
│   ├── Info.plist
│   ├── TomOSWidget.entitlements
│   └── Assets.xcassets/
├── TomOS.xcodeproj/
└── .env.local                      # Secrets (gitignored)
```

## Key Features

- **Quick Capture:** Add tasks via Siri/Shortcuts/Menu bar/⌘⌥T
- **Global Hotkeys:** System-wide ⌘⌥ shortcuts (1-5, T, M, Q) [macOS]
- **Push Notifications:** Native APNs integration (no third-party services)
- **Local Notifications:** Work offline with reminders
- **Menu Bar App:** macOS quick access with task count badge
- **Cross-Platform:** Shared codebase for iOS/iPadOS/macOS
- **Share Extension:** Add tasks from any app via share sheet [iOS]
- **Home Screen Widget:** Quick task view with 4 sizes [iOS 17+]
- **Interactive Widget:** Complete/Snooze tasks directly from widget [iOS 17+]
- **Live Activities:** Current task on Dynamic Island & Lock Screen [iOS 16.2+]
- **Focus Filters:** Auto-show tasks matching Focus mode [iOS 16+]
- **Calendar Sync:** View meetings, create prep tasks from calendar [iOS 16+]
- **Siri Integration:** "Add task to TomOS", "What should I work on?" [iOS]

## APNs Configuration

**Bundle ID:** `com.tomos.app`
**Team ID:** `89NX9R78Y7`
**Key ID:** `Z5X44X9KD7`
**Environment:** `development` (sandbox for testing)

### Important: macOS Entitlements Key

macOS uses a different entitlements key than iOS:
- **iOS:** `aps-environment`
- **macOS:** `com.apple.developer.aps-environment`

The `TomOS.macOS.entitlements` file must use the full key for push notifications to work.

## Backend Integration

**API Base URL:** `https://tomos-task-api.vercel.app`

**Endpoints Used:**
- `POST /api/task` - Create task from natural language
- `POST /api/task/batch` - Batch import tasks
- `POST /api/register-device` - Register APNs device token
- `GET /api/notifications/morning-overview` - Morning summary
- `GET /api/notifications/eod-summary` - End of day summary

## Build & Run

**iOS/iPadOS:**
```bash
open TomOS.xcodeproj
# Select physical device (APNs doesn't work in Simulator)
# Cmd+R to build and run
```

**macOS:**
```bash
open TomOS.xcodeproj
# Select "My Mac" target
# Cmd+R to build and run
```

## Update macOS App in Applications

After building in Xcode, update the installed app:
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Debug/TomOS.app" -type d 2>/dev/null | head -1)
rm -rf /Applications/TomOS.app && cp -R "$APP_PATH" /Applications/TomOS.app
```

## Install on Work MBP (No Xcode)

**Pre-built app package:** Available in OneDrive at `~/OneDrive - Publicis Groupe/TomOS-Setup/`

### One-Command Install:
```bash
bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/install-tomos-work-mac.sh"
```

**What it does:**
- Extracts pre-built `TomOS.app` from zip
- Installs to `~/Applications/TomOS.app` (no admin rights needed)
- Re-signs app with ad-hoc signature for work Mac
- Removes quarantine attributes
- Sets up auto-start on login
- Launches the app

**Included Features:**
- ⌘⌥E - Email to Task (Outlook integration)
- ⌘⌥T - Quick Task Capture
- ⌘⌥1-5 - Brain Dump, Smart Surface, Notifications, Dashboard
- ⌘⌥M - Menu Bar, ⌘⌥Q - Quit
- Full push notification support
- Share Extension
- Menu bar with task counts

**Prerequisites:**
- OneDrive syncing the `TomOS-Setup` folder
- Grant Accessibility permission when prompted (for global shortcuts)

**Uninstall old version first:**
```bash
bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/uninstall-old-tomoscapture.sh"
```

## Provisioning Profiles

**iOS:** Managed by Xcode (automatic signing)
**macOS:** Requires manual provisioning profile with Push Notifications capability
  - Created in Apple Developer Portal → Profiles → macOS App Development
  - Must select the `com.tomos.app` App ID
  - Profile must include Push Notifications

## Development Phases

✅ **Phase 1:** Build fixes (deprecated APIs)
✅ **Phase 2:** APNs device registration
✅ **Phase 3:** Local notification scheduler
✅ **Phase 4:** macOS menu bar support
✅ **Phase 5:** macOS push notifications working
✅ **Phase 6:** Global keyboard shortcuts (⌘⌥ pattern)
✅ **Phase 7:** iOS Siri App Intents integration
✅ **Phase 8:** iOS Share Extension ("Add to TomOS")
✅ **Phase 9:** iOS Home Screen & Lock Screen Widget
⏳ **Phase 10:** Feature consolidation from old apps

## Global Keyboard Shortcuts

All shortcuts use ⌘⌥ (Command + Option) pattern:

| Shortcut | Action |
|----------|--------|
| ⌘⌥T | Quick Task Capture (floating window) |
| ⌘⌥1 | Brain Dump |
| ⌘⌥2 | What Should I Work On? |
| ⌘⌥3 | Send Morning Overview |
| ⌘⌥4 | Send EOD Summary |
| ⌘⌥5 | Open Dashboard |
| ⌘⌥M | Show Menu Bar Dropdown |
| ⌘⌥Q | Quit TomOS |

**Implementation Files:**
- `GlobalShortcutManager.swift` - System-wide hotkey detection
- `QuickCaptureWindow.swift` - Floating quick capture window
- `MenuBarController.swift` - Window management for shortcuts

**Note:** Requires Accessibility permissions on macOS for global hotkeys to work.

## iOS Siri Commands

The App Intents framework enables Siri voice commands on iOS 16+:

| Siri Command | Action |
|--------------|--------|
| "Add [task] to TomOS" | Quick task capture via voice |
| "Open brain dump in TomOS" | Navigate to Brain Dump view |
| "What should I work on?" | Get AI-recommended next task |
| "Send my morning overview" | Trigger morning notification |
| "Send EOD summary" | Trigger end-of-day summary |

**Implementation:** `TomOS/AppIntents.swift`

## iOS Widget

Home Screen and Lock Screen widgets showing top task:

| Widget Size | Features |
|-------------|----------|
| Small (2x2) | Top task + Quick Add button |
| Medium (4x2) | Top task + Quick Add + task count |
| Circular (Lock Screen) | Quick Add tap target |
| Rectangular (Lock Screen) | Top task preview |

**Implementation:** `TomOSWidget/TomOSWidget.swift`
**Minimum iOS:** 17.0 (for containerBackground API)

## User Context

**User:** Tom Bragg
**Timezone:** Australia/Sydney (AEDT, UTC+11)
**Work Contexts:** Work, Client Projects, Strategy, Admin, Legal Review
**ADHD Workflow Needs:**
- Friction-free task capture
- Visual priority indicators
- Reliable notifications that don't break focus
- Quick context switching between work modes

## Quick Reference

**Need backend changes?** Switch to `/Users/tombragg/Desktop/Projects/TomOS/`
**Stuck on Git?** User relies on Claude Code for all coding/git operations
**APNs not working?** Check entitlements key, provisioning profile, physical device
**Xcode issues?** Clean Build Folder (⇧⌘K) then rebuild

---

*Last updated: 2026-01-03*
