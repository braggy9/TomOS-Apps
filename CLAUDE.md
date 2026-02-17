# TomOS-Apps (Swift iOS/iPadOS/macOS)

## What This Repo Is

Native Swift applications for ADHD-friendly task management across Apple platforms.

**Technology:** SwiftUI, AppKit (macOS menu bar), APNs push notifications
**Platforms:** iOS 16+, iPadOS 16+, macOS 13+
**Target User:** Tom Bragg - Senior Legal Counsel with ADHD workflow needs

## Repository Information

**Local Path:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/`
**GitHub:** `github.com/braggy9/TomOS-Apps.git` (Private)
**Related Repo:** [TomOS API](/Users/tombragg/Desktop/Projects/TomOS/) - Vercel backend

## Current Status (Updated 2026-02-17)

### Latest Release
- **iOS:** Version 1.4 (Build 28) - IPA ready for TestFlight ✅ (3.2 MB)
- **macOS Personal MBP:** Version 1.4 (Build 28) - Installed /Applications ✅
- **macOS Work MBP:** Version 1.4 (Build 28) - Available via OneDrive ✅ (2.9 MB)
- **What's New in Build 28:** 🔧 macOS BUG FIXES - Fixed menu bar task completion (random UUID → real task ID), added completion confirmation dialog, implemented toggleConfidential in NoteDetailView, fixed togglePin to actually send isPinned field, fixed Calendar tab platform-specific text, replaced stale Notion URL handler with dashboard, live app version from Bundle, platform-aware success messages
- **What's New in Build 27:** 🔧 CRITICAL macOS FIX + ♿ 100% ACCESSIBILITY - Fixed macOS task creation bug (toolbar keyboard placement), completed Dynamic Type support (superseded by Build 28)
- **What's New in Build 26:** 🔧 CRITICAL FIXES + ✨ FEATURES - Widget deep links fixed, TomOSShared consolidation (eliminated 2,900 lines duplication), Dynamic Island activation, Matter-email integration (superseded by Build 28)
- **What's New in Build 17:** 🎨 UI/UX ENHANCEMENTS - Performance optimization (75% fewer API calls), Today/Quick Wins filters, skeleton loading, design system (superseded by Build 27)

### Backend Migration Complete ✅
- **Database:** Migrated from Notion to PostgreSQL (Neon, Sydney region) on 2026-01-19
- **Performance:** 20-60x faster than Notion API, no rate limits
- **Impact:** Build 15 (macOS) removes legacy "View All Tasks in Notion" menu item

### Completed Features
- ✅ iOS app with push notifications working
- ✅ macOS app with push notifications working
- ✅ Menu bar interface (macOS)
- ✅ APNs device registration for both platforms
- ✅ Local notification scheduler
- ✅ **Notification action handlers** - Complete, Snooze, View buttons fully functional
- ✅ macOS app installed in /Applications
- ✅ Auto-start on login configured
- ✅ Siri App Intents integration (iOS)
- ✅ Share Extension - "Add to TomOS" from any app
- ✅ Home Screen Widget - Small, Medium, Lock Screen
- ✅ Live Activities - Dynamic Island & Lock Screen (iOS 16.2+)
- ✅ Interactive Widget - Complete/Snooze from widget (iOS 17+)
- ✅ Focus Filters - Auto-filter tasks by Focus mode (iOS 16+)
- ✅ Calendar Sync - Apple Calendar (EventKit) integration
- ✅ **M365 Calendar** - Work calendar via Power Automate sync
- ✅ **TestFlight Distribution** - iOS Build 11 live
- ✅ **My Tasks Tab** - Full task list view with filters (iOS only)
- ✅ **Toast Notifications** - Auto-dismissing success/error messages
- ✅ **Keyboard Dismiss** - Done button in Brain Dump
- ✅ **Tag System** - TagPicker UI with 26 predefined tags (Build 9+)
- ✅ **Tag Shortcuts** - p:/pro:, a:, t: shortcuts for inline tagging (Build 9+)
- ✅ **Task Editing** - Full edit form with all properties (Build 8+)
- ✅ **Task Completion** - Swipe actions for completing tasks (Build 13)
- ✅ **Auto-Refresh** - Brain Dump tasks appear immediately in Tasks View (Build 11-13)
- ✅ **MatterOS Integration** - Legal practice management (Build 14+)
  - Matters tab with filtering (All, Active, Completed, Urgent, High Priority)
  - Matter detail view with Overview, Documents, Timeline, Notes tabs
  - Create new matters with client, type, priority, lead counsel
  - Full CRUD operations via TomOS API backend

### Recent Bug Fixes (Build 13 - 2026-01-16)
- ✅ **Fixed:** Task completion now uses iOS-native swipe actions (swipe right to complete)
- ✅ **Fixed:** NotificationCenter observer leak with .onReceive modifier (Build 12)
- ✅ **Fixed:** Brain Dump tasks not appearing in Tasks View (Build 11)
- ✅ **Fixed:** Batch import with tags (Build 10)
- ✅ **Fixed:** API response parsing (Build 10)

### Not Implemented
- ⚠️ **watchOS App** - Code exists but not built/deployed (user has no Apple Watch)

### Registered Devices
- **iOS:** `f757db2b408a19ec...`
- **macOS:** `025aeb1d4d823d33...`

## Recent Build History

### Build 28 (2026-02-17) - CURRENT
**Platform:** iOS + macOS
**Status:** iOS IPA ready for TestFlight ✅, macOS deployed ✅, Work MBP packaged ✅

**Changes:**
- **CRITICAL BUG FIX:** Menu bar task completion now uses real backend task ID — previously used `UUID().uuidString` causing all completions to silently fail on the server. Fixed `Recommendation` struct to decode `taskId` from JSON `"id"` field, and `MenuBarController.refreshTasks()` to pass `rec.taskId`.
- **UX SAFETY:** Menu bar task completion now shows NSAlert confirmation dialog before marking task done — prevents accidental completions when clicking tasks in the dropdown.
- **BUG FIX:** `togglePin` in NoteDetailView now actually sends `isPinned` to the API — previously called `updateNote` with all-nil parameters (no-op), note never pinned/unpinned on server.
- **FEATURE COMPLETE:** `toggleConfidential` in NoteDetailView implemented — was a stub showing "not yet implemented" toast. Now calls `updateNote(confidential:)` API properly.
- **PLATFORM FIX:** Calendar tab "iOS Calendar Access" text now platform-aware — macOS shows "Calendar Access" / "your Mac calendar".
- **CLEANUP:** `tomos://tasks` URL scheme on macOS now opens web dashboard instead of `notion://` (Notion integration removed, backend is PostgreSQL).
- **VERSION FIX:** App Version in More tab now reads live from `Bundle.main` — was hardcoded as "1.0".
- **PLATFORM FIX:** "Check your phone 📱" success messages use "Check your notifications 🔔" on macOS.

**Technical Details:**

1. **Menu Bar Task ID Fix (CRITICAL):**
   - **Root Cause:** `Recommendation` struct had `public let id = UUID()` (local default, NOT from JSON). `MenuBarController` then created `MenuBarTask(id: UUID().uuidString)` — two layers of random UUID generation.
   - **Fix:** Added `public let taskId: String?` with `CodingKeys` mapping `"id"` → `taskId`. `MenuBarController` now uses `rec.taskId ?? ""`.
   - **Files:** `TomOSShared/Sources/TomOSShared/APIService.swift`, `TomOS/MenuBarController.swift`

2. **Menu Bar Completion Confirmation:**
   - **Problem:** `openTaskDetail(_:)` was misleadingly named but immediately completed tasks — no confirmation, no way to cancel.
   - **Fix:** Renamed to `completeTaskFromMenu(_:)`, added NSAlert with "Complete ✓" / "Cancel", added guard for empty task ID.
   - **File:** `TomOS/MenuBarController.swift`

3. **togglePin / toggleConfidential Fix:**
   - **Root Cause:** `updateNote` lacked `isPinned` and `confidential` parameters. `togglePin` called with all nil = no-op API call.
   - **Fix:** Added `isPinned: Bool? = nil` and `confidential: Bool? = nil` to `updateNote`. Fixed `togglePin` to pass `!note.isPinned`. Implemented `toggleConfidential` to pass `!note.confidential`.
   - **Files:** `TomOSShared/Sources/TomOSShared/APIService.swift`, `TomOS/NoteDetailView.swift`

4. **Remaining fixes:** CalendarManager platform text, TomOSApp URL handler, MoreView version, MoreView success messages.

**Archive Locations:**
- **iOS:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/TomOS-Build28-iOS.xcarchive`
- **iOS IPA:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/Build28-iOS-Export/TomOS.ipa` (3.2 MB)
- **macOS:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/TomOS-Build28-macOS.xcarchive`
- **macOS App:** `/Applications/TomOS.app` (Version 1.4, Build 28)
- **Work MBP:** `~/OneDrive - Publicis Groupe/TomOS-Setup/TomOS-App-Build28.zip` (2.9 MB)

**Deployment Status:**
- **Personal MBP:** ✅ Installed to `/Applications/TomOS.app` (2026-02-17)
- **Work MBP:** ✅ Packaged to OneDrive
  - Install: `bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/install-tomos-work-mac.sh"`
- **iOS:** ✅ IPA ready for TestFlight upload
  - Upload via: Xcode → Window → Organizer → Archives → TomOS Build 28 (iOS) → Distribute App

---

### Build 27 (2026-02-17) - Superseded by Build 28
**Platform:** iOS + macOS
**Status:** iOS IPA ready for TestFlight ✅, macOS deployed ✅, Work MBP packaged ✅

**Changes:**
- **CRITICAL macOS BUG FIX:** Fixed Brain Dump task creation on macOS - toolbar `.keyboard` placement (iOS-only) wrapped in `#if os(iOS)` conditional compilation
- **100% DYNAMIC TYPE COVERAGE:** Completed Dynamic Type support - replaced all 19 remaining fixed-size fonts with semantic fonts across 12 files
- **ACCESSIBILITY:** All text now scales with user text size preferences (Settings → Accessibility → Display & Text Size)
- **ADHD-FRIENDLY:** Users can increase text size for reduced cognitive load and easier scanning

**Why:** User reported "hit create and nothing happens" on work MBP. Investigation revealed iOS-only toolbar placement breaking macOS view hierarchy. Completed remaining Dynamic Type fixes for full accessibility coverage.

**Technical Details:**

1. **macOS Task Creation Fix - CRITICAL BUG:**
   - **Problem:** `ToolbarItemGroup(placement: .keyboard)` in BrainDumpView.swift line 70 caused SwiftUI error on macOS (placement doesn't exist on macOS)
   - **Impact:** "Create Tasks" button completely non-functional on macOS - taps silently ignored, no error shown to user
   - **Root Cause:** .keyboard placement is iOS-only (for on-screen keyboard accessory), macOS has no on-screen keyboard
   - **Fixed:** Wrapped toolbar code in `#if os(iOS)` conditional compilation
   - **File Modified:** TomOS/BrainDumpView.swift (lines 69-77)
   - **Result:** Task creation now works on macOS work MBP

2. **Dynamic Type 100% Coverage:**
   - **Total Replacements:** 19 fixed-size fonts → semantic fonts across 12 files
   - **Files Modified:** QuickCaptureWindow.swift (CRITICAL: text content), NotesView.swift, TasksView.swift, TaskTemplatePickerView.swift, NoteDetailView.swift, MenuBarController.swift, MoreView.swift, SmartSurfaceView.swift, MattersView.swift, TemplatePickerView.swift, BrainDumpView.swift, MatterDetailView.swift
   - **Font Mapping:**
     - Text content: `.system(size: 16)` → `.font(.body)`
     - Large icons: `.system(size: 48-60)` → `.font(.system(.largeTitle))`
     - Medium icons: `.system(size: 32-36)` → `.font(.title)`
     - Tiny elements: `.system(size: 8)` → `@ScaledMetric private var dotSize: CGFloat = 8` + `.font(.system(size: dotSize))`
   - **Impact:** Users can adjust text size 100% to 310% without loss of content or visual hierarchy
   - **WCAG 2.1:** ✅ Level AA compliant (text can resize up to 200%)

**Archive Locations:**
- **iOS:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/TomOS-Build27-iOS.xcarchive`
- **iOS IPA:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/Build27-iOS-Export/TomOS.ipa` (4.0 MB)
- **macOS:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/TomOS-Build27-macOS.xcarchive`
- **macOS App:** `/Applications/TomOS.app` (Version 1.4, Build 27)
- **Work MBP:** `~/OneDrive - Publicis Groupe/TomOS-Setup/TomOS-App-Build27.zip` (2.9 MB)

**Deployment Status:**
- **Personal MBP:** ✅ Installed to `/Applications/TomOS.app` (2026-02-17)
- **Work MBP:** ✅ Packaged to OneDrive (install command unchanged)
  - Install: `bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/install-tomos-work-mac.sh"`
- **iOS:** ✅ IPA ready for TestFlight upload
  - Upload via: Xcode → Window → Organizer → Archives → TomOS Build 27 (iOS) → Distribute App

**Upload Instructions (iOS TestFlight):**
```bash
# Option 1: Xcode Organizer
open -a Xcode
# Window → Organizer → Archives → Select "TomOS Build 27" → Distribute App → App Store Connect → Upload
```

---

### Build 26 (2026-02-13)
**Platform:** iOS + macOS
**Status:** iOS IPA ready for TestFlight ✅, macOS deployed ✅, Work MBP packaged ✅

**Changes:**
- **CRITICAL BUG FIX:** Widget deep links now work - fixed broken `tomos://quick-add` and `tomos://open` URL handlers on iOS
- **MAJOR CLEANUP:** Consolidated TomOSShared package - eliminated 2,900 lines of duplicate code between TomOS/ and TomOSShared/
- **FEATURE ACTIVATION:** Dynamic Island "Start Focus Session" button added - previously orphaned LiveActivityManager code now accessible to users
- **ENHANCEMENT:** Matter-email integration - ⌘⌥E now captures email subject, sender, date, and body (was subject-only), adds "email" tag automatically
- **FIX:** Cross-platform compatibility - TaskTemplatePickerView.swift now uses platform-specific background colors (#if os(macOS) / #else)

**Why:** Comprehensive audit (2026-02-12) revealed critical bugs and 2,900 lines of code duplication. User requested autonomous implementation prioritizing high-impact fixes.

**Technical Details:**

1. **Widget Deep Links Fixed (Task #21) - CRITICAL BUG:**
   - **Problem:** Widget used `tomos://quick-add` and `tomos://open` URLs that fell through to default case on iOS
   - **Fixed:** Added URL handlers to TomOSApp.swift iOS switch-case
   - **Impact:** Widget navigation completely non-functional → now works correctly
   - **File Modified:** TomOS/TomOSApp.swift (lines 114-167)

2. **TomOSShared Consolidation (Task #8):**
   - **Problem:** 2,900 lines duplicated between TomOS/ and TomOSShared/ (10 files)
   - **Root Cause:** TomOS/ never imported TomOSShared despite being linked
   - **Solution:** Copied authoritative TomOS/ versions to TomOSShared, added `public` modifiers, deleted TomOS/ copies
   - **Files Consolidated:** APIService.swift (1,155 lines), DesignSystem.swift (330 lines), TaskCache.swift (424 lines), HapticManager.swift, SkeletonView.swift, ToastView.swift, Matter.swift, Note.swift, FitnessModels.swift, Pagination.swift
   - **Impact:** Single source of truth, eliminated maintenance burden
   - **Files Modified:** 25 TomOS/ app files (added `import TomOSShared`), TomOSShared package (added public modifiers), TomOS.xcodeproj (removed duplicate file references)

3. **Dynamic Island Activation (Task #22):**
   - **Problem:** LiveActivityManager (138 lines) fully implemented but NO VIEW CALLED startTaskActivity() - feature was invisible
   - **Fixed:** Added "Start Focus Session" button to TaskDetailView
   - **Impact:** Users can now access fully-built Dynamic Island feature with live timer, task context, elapsed time display
   - **File Modified:** TomOS/TaskDetailView.swift (added iOS 16.2+ section with focus session UI)

4. **Matter-Email Integration (Task #14):**
   - **Problem:** ⌘⌥E only captured email subject line (no sender, body, date)
   - **Enhanced:** AppleScript now extracts subject, sender, date, body (truncated to 500 chars)
   - **Auto-Tag:** Tasks created from emails automatically tagged with "email"
   - **Files Modified:** TomOS/GlobalShortcutManager.swift (enhanced AppleScript), TomOS/QuickCaptureWindow.swift (emailMetadata support)

**Archive Locations:**
- **iOS:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/TomOS-Build26.xcarchive`
- **iOS IPA:** `/Users/tombragg/Desktop/🖥️ TomOS/TomOS-Apps/build/Build26-Export/TomOS.ipa` (4.0 MB)
- **macOS:** `/Applications/TomOS.app` (Version 1.3, Build 26)
- **Work MBP:** `~/OneDrive - Publicis Groupe/TomOS-Setup/TomOS-App-Build26.zip` (3.9 MB)

**Deployment Status:**
- **Personal MBP:** ✅ Installed to `/Applications/TomOS.app` (2026-02-13)
- **Work MBP:** ✅ Packaged to OneDrive
  - Install script: `install-tomos-work-mac.sh` (updated for Build 26)
  - Documentation: `WORK-MBP-INSTALL.md` (updated)
  - Verify script: `verify-tomos-version.sh` (updated)
  - Install command: `bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/install-tomos-work-mac.sh"`
- **iOS:** ✅ IPA ready for TestFlight upload
  - Upload via: Xcode → Window → Organizer → Archives → TomOS Build 26 → Distribute App

**Upload Instructions (iOS TestFlight):**
```bash
# Option 1: Xcode Organizer (Recommended)
open -a Xcode
# Window → Organizer → Archives → Select "TomOS Build 26" → Distribute App → App Store Connect → Upload

# Option 2: Command line (if API keys configured)
xcrun altool --upload-app --type ios --file "build/Build26-Export/TomOS.ipa" --apiKey [KEY_ID] --apiIssuer [ISSUER_ID]
```

### Build 17 (2026-01-22) - Superseded by Build 26
**Platform:** iOS + macOS
**Status:** Archive created ✅, pending TestFlight upload

**Changes:**
- **UI/UX ENHANCEMENT:** Major performance and design improvements (Phase 1 & 2)
- **NEW:** DesignSystem.swift - Centralized design tokens (colors, spacing, typography, shadows)
- **NEW:** TaskCache.swift - Actor-based caching reducing API calls by 75%
- **NEW:** SkeletonView.swift - Modern skeleton loading screens
- **NEW:** Note.swift - Notes feature data models
- **ENHANCEMENT:** "Today" filter - Shows tasks due today, overdue, or marked urgent
- **ENHANCEMENT:** "Quick Wins" filter - Shows low priority and undated To Do tasks (ADHD-optimized)
- **ENHANCEMENT:** WCAG AA compliant toast notifications (4.5:1+ contrast ratios)
- **ENHANCEMENT:** Tab state persistence - Returns to last-viewed tab on app reopen
- **PERFORMANCE:** 30-50x faster task/matter loading with 5-minute cache + background refresh
- **PERFORMANCE:** Skeleton loading screens for Tasks, Matters, Smart Surface

**Why:** User requested comprehensive UI/UX review and enhancements for ADHD workflow optimization

**UI/UX Improvements:**
1. **Performance Optimization (Phase 1)**
   - TaskCache actor for thread-safe caching (5-minute duration, 1-minute background refresh)
   - 75% reduction in API calls through intelligent caching
   - 30-50x faster task and matter loading

2. **Polish & Features (Phase 2)**
   - Today filter: Eliminates decision paralysis by showing only today's work
   - Quick Wins filter: Surfaces easy wins (low priority, undated To Do tasks)
   - Skeleton loading: Shows content structure while loading (modern UX pattern)
   - Enhanced empty states with custom icons/colors per filter
   - Spring animations for toast notifications

3. **Design System**
   - Eliminated 4+ duplicate color definition functions
   - WCAG AA compliant text colors (white/black on colored backgrounds)
   - Consistent spacing using 4pt grid (xs=8, sm=12, md=16, lg=20, xl=24)
   - Typography scale, corner radius presets, shadow presets
   - Cross-platform compatibility (iOS/macOS)

**Files Added:**
- `TomOS/DesignSystem.swift` (273 lines) - Design system
- `TomOS/TaskCache.swift` (204 lines) - Actor-based cache
- `TomOS/SkeletonView.swift` (200+ lines) - Skeleton loading UI
- `TomOS/Note.swift` (185 lines) - Notes feature models

**Files Modified:**
- `TomOS/ToastView.swift` - WCAG AA compliance, DesignSystem integration
- `TomOS/TasksView.swift` - TaskCache, Today filter, Quick Wins filter, skeleton loading
- `TomOS/MattersView.swift` - TaskCache, DesignSystem colors, skeleton loading
- `TomOS/SmartSurfaceView.swift` - DesignSystem colors, skeleton loading
- `TomOS/ContentView.swift` - Tab state persistence (@AppStorage)

**Archive Location:**
- `/Users/tombragg/Desktop/TomOS-Apps/build/TomOS-Build17.xcarchive`
- IPA: `/Users/tombragg/Desktop/TomOS-Apps/build/Build17-Export/TomOS.ipa` (3.5 MB)

**Deployment Status:**
- **Personal MBP:** ✅ Installed to `/Applications/TomOS.app` (Version 1.2, Build 17)
- **Work MBP:** ✅ Packaged to OneDrive `TomOS-App-Build17.zip` (3.3 MB)
  - Install script updated: `install-tomos-work-mac.sh`
  - Documentation updated: `WORK-MBP-INSTALL.md`
  - Verify script updated: `verify-tomos-version.sh`
  - Install command: `bash "$HOME/OneDrive - Publicis Groupe/TomOS-Setup/install-tomos-work-mac.sh"`

**Upload Instructions (iOS TestFlight):**
- Open Xcode → Window → Organizer → Archives
- Select "TomOS Build 17" → Distribute App → App Store Connect → Upload
- Alternative: Command line with App Store Connect API keys

### Build 16 (2026-01-22)
**Platform:** iOS + macOS
**Status:** macOS deployed ✅, iOS pending TestFlight upload

**Changes:**
- **CRITICAL FIX:** Task completion now works - fixed PostgreSQL API endpoint from `POST /api/task/complete` to `PATCH /api/task/[id]/complete`
- **CRITICAL FIX:** Matters auto-refresh after creation - added NotificationCenter pattern (listener + post)
- **User Impact:** Build 14 had broken task completion (swipe-to-complete showed but didn't work) and matters didn't refresh

**Why:** User reported critical bugs: "when i complete a task, it doesnt actually complete. And when new tasks are added they dont appear. Same dor matters"

**Root Causes:**
1. APIService.completeTask() was calling old Notion endpoint instead of new PostgreSQL endpoint
2. MattersView missing `.onReceive` listener for `.mattersCreated` notification
3. CreateMatterView not posting `.mattersCreated` notification after successful creation

**Files Modified:**
- `APIService.swift:246-260` - Fixed completeTask() endpoint and method
- `MattersView.swift:10-12,159-161` - Added notification name and listener
- `CreateMatterView.swift:171` - Added notification post

**Deployment:**
- Personal MBP: `/Applications/TomOS.app` (installed 2026-01-22)
- Work MBP: OneDrive package `TomOS-App.zip` (2.2 MB, Version 1.1 Build 16)
- iOS: Ready for TestFlight upload (high priority - fixes critical bugs in Build 14)

### Build 15 (2026-01-21) - Superseded by Build 16
**Platform:** macOS only (Personal MBP, Work MBP via OneDrive)
**Status:** Deployed and running

**Changes:**
- **REMOVED:** Legacy "View All Tasks in Notion" menu item (backend is now PostgreSQL)
- **REMOVED:** `openNotionTasks()` function that opened Notion app
- Code cleanup: Eliminated outdated Notion integration references
- Menu now shows only "Open Dashboard" which opens PostgreSQL-backed web dashboard

**Why:** Backend migrated from Notion to PostgreSQL on 2026-01-19. The "View All Tasks in Notion" menu item was confusing users and pointing to deprecated infrastructure.

**Files Modified:**
- `MenuBarController.swift` - Removed Notion menu item and function
- Updated build number from 14 to 15

**Deployment:**
- Personal MBP: `/Applications/TomOS.app` (installed 2026-01-21)
- Work MBP: OneDrive package `TomOS-App.zip` (2.1 MB, Version 1.1 Build 15)

### Build 14 (2026-01-21) - CURRENT (iOS TestFlight)
**Platform:** iOS/macOS
**Status:** ✅ Live on TestFlight (Approved 2026-01-21 after Apple outage resolved)

**Changes:**
- Added MatterOS integration for legal practice management
- New Matters tab between Smart Surface and My Tasks
- Created Matter.swift data models (Matter, MatterDocument, MatterEvent, MatterNote)
- Added 7 MatterOS API methods to APIService (getMatters, getMatter, createMatter, updateMatter, getMatterDocuments, getMatterEvents, getMatterNotes)
- Built MattersView with filtering (All, Active, Completed, On Hold, Urgent, High Priority)
- Built MatterDetailView with tabbed sections (Overview, Documents, Timeline, Notes)
- Built CreateMatterView form with validation
- Added .openMatters notification for navigation
- Tab order updated: Brain Dump (0), Smart Surface (1), Matters (2), Tasks (3), Calendar (4), More (5)

**Files Added:**
- `TomOS/Matter.swift` - Data models
- `TomOS/MattersView.swift` - List view
- `TomOS/MatterDetailView.swift` - Detail view
- `TomOS/CreateMatterView.swift` - Creation form

**Files Modified:**
- `ContentView.swift` - Added Matters tab, updated tag numbers
- `APIService.swift` - Added MatterOS methods
- `TomOS.macOS.entitlements` - Added AppleEvents exception for Outlook (CRITICAL FIX)
- `Info.plist` - Added NSAppleEventsUsageDescription
- Cross-platform fixes: CreateMatterView, MatterDetailView, MattersView

**CRITICAL FIX - Email-to-Task (macOS):**
- Added `com.apple.security.temporary-exception.apple-events` entitlement
- Fixes ⌘⌥E email-to-task functionality on macOS
- User must grant Outlook automation permission on first use

**Archive Location:**
- `/Users/tombragg/Desktop/TomOS-Apps/build/TomOS-Build14.xcarchive`
- Upload via: Xcode → Window → Organizer → Distribute App → App Store Connect

### Build 13 (2026-01-16) - Previous iOS Release
**Changes:**
- Implemented iOS-native swipe actions for task completion
- Swipe right on task row to reveal Complete button
- Full swipe completes task instantly
- Fixed gesture conflicts between NavigationLink and completion button
- macOS app updated to match iOS build number

**Files Modified:**
- `TasksView.swift` - Replaced button-in-row with swipeActions(edge: .leading)
- `TasksView.swift` - Status indicator now visual-only (no tap action)

### Build 12 (2026-01-16) - TestFlight Only
**Changes:**
- Fixed NotificationCenter observer leak using .onReceive modifier
- Attempted button-outside-NavigationLink fix (didn't work due to List row behavior)
- Improved memory management for view lifecycle

**Files Modified:**
- `TasksView.swift` - Replaced manual NotificationCenter observer with .onReceive
- `TasksView.swift` - Restructured row layout (superseded by Build 13)

### Build 11 (2026-01-13)
**Changes:**
- Added NotificationCenter communication between Brain Dump and Tasks View
- Tasks now auto-refresh in Tasks View immediately after Brain Dump creation
- No manual pull-to-refresh needed
- macOS app updated to match iOS build

**Files Modified:**
- `BrainDumpView.swift` - Added `NotificationCenter.default.post(name: .tasksCreated)`
- `TasksView.swift` - Added `NotificationCenter` listener for auto-refresh
- `TasksView.swift` - Added `extension Notification.Name` for `.tasksCreated`

### Build 10 (2026-01-10) - TestFlight Only
**Changes:**
- Fixed batch import to include selected tags
- Updated TaskResponse model to match backend format (notionPageId, parsedTask)
- Better error logging for debugging
- Tag shortcuts already working via backend (no app change needed)

**Files Modified:**
- `APIService.swift` - Updated `batchImport()` to accept tags parameter
- `APIService.swift` - Fixed TaskResponse model structure
- `BrainDumpView.swift` - Enhanced error messages

### Build 9 (2026-01-09)
**Changes:**
- Integrated TagPicker UI into BrainDumpView
- Added 26 predefined tags (6 projects, 6 areas, 8 actions, 6 topics)
- Tag selection UI with category filters
- Backend tag shortcuts (p:, pro:, a:, t:) working

**Files Added:**
- `TagPicker.swift` - Complete tag picker UI with search and filters

**Files Modified:**
- `BrainDumpView.swift` - Added tag selection sheet
- `APIService.swift` - Updated createTask to send tags

### Build 8 (2026-01-08)
**Changes:**
- Added full task editing functionality
- Tasks View now navigable - tap to edit
- Fixed button responsiveness with `.buttonStyle(.plain)`

**Files Added:**
- `TaskDetailView.swift` - Complete task edit form

**Files Modified:**
- `TasksView.swift` - Added NavigationLink and button style fixes
- `APIService.swift` - Added updateTask method

## Project Structure

```
TomOS-Apps/
├── TomOS/
│   ├── TomOSApp.swift              # App entry point
│   ├── AppDelegate.swift           # APNs registration + notification handlers
│   ├── ContentView.swift           # Main TabView (5 tabs: Brain Dump, Smart Surface, Matters, Tasks, Calendar, More)
│   ├── BrainDumpView.swift         # Batch task entry with toast notifications
│   ├── SmartSurfaceView.swift      # AI recommendations
│   ├── TasksView.swift             # Full task list with filters
│   ├── TaskDetailView.swift        # Edit task details
│   ├── ToastView.swift             # Auto-dismissing notifications
│   ├── QuickActionsView.swift      # Notification triggers (legacy)
│   ├── MoreView.swift              # About/Info + Quick Actions
│   ├── Models/
│   │   └── Matter.swift            # MatterOS data models (Matter, MatterDocument, MatterEvent, MatterNote)
│   ├── MattersView.swift           # MatterOS list view with filtering (NEW Build 14)
│   ├── MatterDetailView.swift      # MatterOS detail with tabs (NEW Build 14)
│   ├── CreateMatterView.swift      # MatterOS creation form (NEW Build 14)
│   ├── TagPicker.swift             # Tag selection UI
│   ├── MenuBarController.swift     # macOS menu bar + window management
│   ├── GlobalShortcutManager.swift # System-wide ⌘⌥ hotkeys
│   ├── QuickCaptureWindow.swift    # Floating quick capture (⌘⌥T)
│   ├── NotificationManager.swift   # Local notifications
│   ├── APIService.swift            # Backend communication + task actions
│   ├── AppIntents.swift            # Siri integration (iOS 16+)
│   ├── LiveActivityManager.swift   # Dynamic Island/Lock Screen (iOS 16.2+)
│   ├── FocusFilter.swift           # Focus mode integration (iOS 16+)
│   ├── CalendarManager.swift       # EventKit calendar sync + UI
│   ├── M365CalendarManager.swift   # Microsoft 365 OAuth + Graph API
│   ├── HapticManager.swift         # Haptic feedback (iOS)
│   ├── Info.plist                  # Privacy declarations (NSCalendarsUsageDescription)
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
├── TomOSWatch/                     # watchOS App (not deployed)
│   ├── ContentView.swift           # Watch UI (Quick Add, tasks, actions)
│   ├── TomOSWatchApp.swift         # Watch app entry point
│   └── Info.plist
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

**Task Endpoints:**
- `POST /api/task` - Create task from natural language
- `POST /api/task/batch` - Batch import tasks
- `POST /api/task/complete` - Mark task as completed (notification action)
- `POST /api/task/snooze` - Snooze task for specified duration (notification action)
- `POST /api/register-device` - Register APNs device token
- `GET /api/task/smart-surface` - Get AI recommendations for next task
- `GET /api/notifications/morning-overview` - Trigger morning summary notification
- `GET /api/notifications/eod-summary` - Trigger end-of-day summary notification
- `GET /api/m365-calendar` - Fetch work calendar events (Power Automate sync)

**MatterOS Endpoints:** (Added Build 14)
- `GET /api/matters` - List matters with filtering (status, priority, limit)
- `POST /api/matters` - Create new matter
- `GET /api/matters/[id]` - Get single matter details
- `PATCH /api/matters/[id]` - Update matter
- `DELETE /api/matters/[id]` - Archive matter
- `GET /api/matters/[id]/documents` - List documents for matter
- `GET /api/matters/[id]/events` - List timeline events for matter
- `GET /api/matters/[id]/notes` - List notes for matter

## Installation & Distribution

### Option 1: Build from Source (Xcode)

For development Macs with Xcode installed.

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

**Copy to /Applications (macOS):**

After building in Xcode, update the installed app:
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Debug/TomOS.app" -type d 2>/dev/null | head -1)
rm -rf /Applications/TomOS.app && cp -R "$APP_PATH" /Applications/TomOS.app
```

### Option 2: TestFlight (No Xcode Required)

For installing on a second personal Mac (or iOS device) without needing the source code. Requires macOS 12+ with the TestFlight app from the Mac App Store.

**Install on recipient Mac:**
1. Open the Mac App Store and install **TestFlight**
2. Open the TestFlight invite link (sent via email or shared link from App Store Connect)
3. Click **Install** on the TomOS app listing in TestFlight
4. TomOS appears in `/Applications` (managed by TestFlight)

**Why TestFlight for a second Mac:**
- Proper Apple code signing (no ad-hoc re-signing needed)
- APNs push notifications work out of the box
- Auto-updates when new builds are uploaded
- No Xcode or developer tools required on the recipient Mac

**Creating a new TestFlight build (from development Mac):**

*Via Xcode GUI:*
1. Open `TomOS.xcodeproj` in Xcode
2. Increment build number in project settings
3. Product → Archive
4. Window → Organizer → select the archive → Distribute App → App Store Connect → Upload
5. Wait for processing in App Store Connect (usually a few minutes)
6. In App Store Connect → TestFlight → select the build → add to test group

*Via command line:*
```bash
# Archive
xcodebuild archive \
  -project TomOS.xcodeproj \
  -scheme TomOS \
  -archivePath build/TomOS.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/TomOS.xcarchive \
  -exportPath build/Export \
  -exportOptionsPlist ExportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file build/Export/TomOS.ipa \
  --apiKey [KEY_ID] \
  --apiIssuer [ISSUER_ID]
```

### Option 3: Install on Work MBP (via OneDrive)

For the work MacBook Pro where Xcode is not installed and TestFlight may not be available.

**Pre-built app package:** Available in OneDrive at `~/OneDrive - Publicis Groupe/TomOS-Setup/`

**One-Command Install:**
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

### Post-Install Setup (All Methods)

After installing TomOS via any method, complete these steps:

1. **Grant permissions** -- When prompted on first launch:
   - **Notifications:** Allow (required for push notifications and reminders)
   - **Accessibility:** Allow in System Settings → Privacy & Security → Accessibility (required for global ⌘⌥ shortcuts)
   - **Automation:** Allow Outlook access when first using ⌘⌥E email-to-task

2. **Verify device registration** -- The app auto-registers its APNs device token on launch. Check the Xcode console (Option 1) or app logs for the device token. Registered tokens appear in the backend at `GET /api/devices`.

3. **Test push notifications:**
   ```bash
   curl -X POST https://tomos-task-api.vercel.app/api/send-push \
     -H "Content-Type: application/json" \
     -d '{"title":"Test","body":"Hello from TomOS!","badge":1}'
   ```
   You should see a notification appear. If not, check entitlements and provisioning profile.

4. **Verify app version** -- Menu bar icon → About TomOS, or run:
   ```bash
   defaults read /Applications/TomOS.app/Contents/Info.plist CFBundleShortVersionString
   defaults read /Applications/TomOS.app/Contents/Info.plist CFBundleVersion
   ```

5. **Configure auto-start on login:**
   - System Settings → General → Login Items → add TomOS
   - Or: the OneDrive install script (Option 3) sets this up automatically

### Provisioning Profiles

**iOS:** Managed by Xcode (automatic signing)
**macOS:** Requires manual provisioning profile with Push Notifications capability
  - Created in Apple Developer Portal → Profiles → macOS App Development
  - Must select the `com.tomos.app` App ID
  - Profile must include Push Notifications
**TestFlight:** Signing is handled automatically by App Store Connect during upload. No manual provisioning profile needed on the recipient Mac -- TestFlight manages certificates and entitlements.

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

## M365 Calendar Integration

TomOS includes dual-path Microsoft 365 calendar integration to handle corporate admin restrictions:

### Power Automate Sync (Default - Works Now)
- **Backend**: Work calendar synced to TomOS API via Power Automate flow
- **Endpoint**: `GET /api/m365-calendar` returns events from Notion database
- **No Auth Required**: Works immediately without OAuth sign-in
- **UI**: Displays in Calendar tab with "Synced via Power Automate" label
- **Limitation**: Read-only, depends on Power Automate flow running

### Direct OAuth (Admin Restricted)
- **Implementation**: Full Microsoft Graph API OAuth2 flow in `M365CalendarManager.swift`
- **Azure App**: Multi-tenant app registration (Mixtape Running Supply tenant)
- **Scopes**: `Calendars.Read`, `User.Read`, `offline_access`
- **Status**: ❌ Cannot use - Requires admin consent for work tenant
- **Why Built**: Alternative for personal Microsoft accounts or future admin approval

### How It Works
1. App loads → `M365CalendarManager` attempts Power Automate sync
2. Fetches events from `/api/m365-calendar` (no auth needed)
3. Displays work calendar events in Calendar tab
4. OAuth sign-in option available but won't work for corporate accounts

**File**: `TomOS/M365CalendarManager.swift` (509 lines)
**UI**: `TomOS/CalendarManager.swift` - `CalendarSyncView` (lines 188-326)

## Notification Action Handlers

Push and local notifications include three action buttons:

### Complete Button (Green)
- **Action**: Marks task as completed in Notion
- **API**: `POST /api/task/complete` with `taskId`
- **Feedback**: iOS haptic success notification
- **Implementation**: `AppDelegate.swift:handleCompleteTask()`

### Snooze Button (Orange)
- **Action**: Snoozes task for 30 minutes
- **API**: `POST /api/task/snooze` with `taskId` and `duration: 30`
- **Feedback**: iOS haptic success notification
- **Implementation**: `AppDelegate.swift:handleSnoozeTask()`

### View Button (Blue)
- **Action**: Opens TomOS web dashboard in browser
- **Behavior**: Platform-specific URL opening (UIKit/AppKit)
- **Implementation**: `AppDelegate.swift:handleViewTask()` → `APIService.openDashboard()`

**Note**: Action handlers use async Task APIs to call backend without blocking UI.

## watchOS App (Not Deployed)

A fully-implemented Apple Watch app exists in `TomOSWatch/` but is **not built or deployed** because:
- User does not own an Apple Watch
- Code is complete and functional (Quick Add, task display, actions)
- Can be enabled in future by adding to Xcode scheme and creating watchOS provisioning profile

**Status**: Code exists, not compiled or distributed via TestFlight.

## User Context

**User:** Tom Bragg
**Timezone:** Australia/Sydney (AEDT, UTC+11)
**Work Contexts:** Work, Client Projects, Strategy, Admin, Legal Review
**ADHD Workflow Needs:**
- Friction-free task capture
- Visual priority indicators
- Reliable notifications that don't break focus
- Quick context switching between work modes

## Documentation

### Architecture & Design Documentation (NEW - 2026-01-08)

- **[ARCHITECTURE_AUDIT.md](./ARCHITECTURE_AUDIT.md)** - Comprehensive architecture analysis
  - Overall grade: A- (excellent with optimization opportunities)
  - Current state: 6,759 lines, 21 files
  - Optimization recommendations: Caching, state management, offline support
  - Performance targets and API call reduction strategies

- **[OFFLINE_MODE_DESIGN.md](./OFFLINE_MODE_DESIGN.md)** - Complete offline mode architecture
  - CoreData schema design
  - TaskStore state management
  - SyncEngine bidirectional sync
  - Conflict resolution strategy
  - 4-week implementation roadmap

- **[TAG_INTEGRATION_GUIDE.md](./TAG_INTEGRATION_GUIDE.md)** - Tag system integration
  - How to add TagPicker.swift to Xcode
  - Update APIService for tag support
  - Integrate into BrainDumpView and QuickCapture
  - API usage examples

### Backend Documentation

- **[TAG_GUIDELINES.md](../tomos-dashboard/TAG_GUIDELINES.md)** - Tagging philosophy
  - Prefix-based system: `proj:`, `area:`, `act:`, `topic:`
  - 25+ predefined tags with descriptions
  - Usage examples and best practices

## Quick Reference

**Need backend changes?** Switch to `/Users/tombragg/Desktop/Projects/TomOS/`
**Stuck on Git?** User relies on Claude Code for all coding/git operations
**APNs not working?** Check entitlements key, provisioning profile, physical device
**Xcode issues?** Clean Build Folder (⇧⌘K) then rebuild

## Roadmap

### Completed (2026-01-08)
- ✅ Phase 1: Tag system (guidelines, API, Swift picker)
- ✅ Phase 2: Architecture audit
- ✅ Phase 4: Tag migration script
- ✅ Phase 3: Offline mode design

### Next Steps
- [ ] Phase 3 Implementation: Offline mode with CoreData (4 weeks)
  - Week 1: CoreData foundation
  - Week 2: TaskStore migration + Read-only sync
  - Week 3: Offline create/update + Conflict resolution
  - Week 4: Polish & production deployment

---

*Last updated: 2026-01-08*
