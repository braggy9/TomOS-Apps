# Related Repositories

## TomOS Ecosystem

The TomOS system is split across two repositories:

### 1. TomOS-Apps (THIS REPO)

**Purpose:** Native Swift applications
**Technology:** SwiftUI, AppKit, APNs
**Platforms:** iOS, iPadOS, macOS
**Local Path:** `/Users/tombragg/Desktop/TomOS-Apps/`
**GitHub:** `github.com/braggy9/TomOS-Apps.git` (Private)

**Current Status:** ✅ Fully operational - both iOS and macOS push notifications working

**What it does:**
- User interface and interaction
- APNs device registration (iOS and macOS)
- Local notifications (offline mode)
- Menu bar app (macOS)
- Quick task capture via Siri/Shortcuts
- Auto-start on login (macOS installed in /Applications)

### 2. TomOS (Backend API)

**Purpose:** Serverless API backend
**Technology:** Next.js 14, TypeScript, Vercel
**Deployment:** `https://tomos-task-api.vercel.app`
**Local Path:** `/Users/tombragg/Desktop/Projects/TomOS/`
**GitHub:** `github.com/braggy9/TomOS.git` (Public)

**Current Status:** ✅ Fully operational - APNs sending to both devices

**What it does:**
- Task creation and management
- APNs push notification sending (to iOS and macOS)
- Notion database integration
- Google Calendar sync
- AI-powered task parsing (Claude claude-sonnet-4-5-20250929)
- 15-minute reminder notifications
- GitHub Actions for scheduled notifications

## How They Work Together

```
iOS/macOS App (TomOS-Apps)
  ↓ User creates task via Siri
  ↓ POST /api/task
Backend API (TomOS)
  ↓ Parse natural language
  ↓ Create task in Notion
  ↓ POST /api/send-push
  ↓ Query Notion for device tokens
  ↓ Send APNs push notification
iOS/macOS App
  ↓ Receive push notification
  ↓ Display with action buttons
```

## When Working in This Repo

**If you need to:**
- Add a UI feature → Work here (TomOS-Apps)
- Add keyboard shortcuts → Work here
- Update notification handling → Work here
- Fix Swift/Xcode issues → Work here

**If you need to:**
- Add/modify API endpoints → Switch to `/Users/tombragg/Desktop/Projects/TomOS/`
- Change APNs sending logic → Switch to backend repo
- Update Notion integration → Switch to backend repo
- Modify task parsing → Switch to backend repo

## Switching Repos in Claude Code

```bash
# Currently in TomOS-Apps, need to work on backend
cd /Users/tombragg/Desktop/Projects/TomOS
claude-code

# Currently in backend, need to work on Swift app
cd /Users/tombragg/Desktop/TomOS-Apps
claude-code
```

## Common Cross-Repo Workflows

### Adding a New Task Type

1. **Backend (TomOS):** Add parsing logic in `/api/task/route.ts`
2. **Backend:** Update Notion property if needed
3. **Frontend (TomOS-Apps):** Update UI to handle new type
4. **Frontend:** Update notification handling if needed

### Testing APNs End-to-End

1. **Frontend:** Run app, get device token
2. **Backend:** Verify device registered in Notion
3. **Backend:** Send test push via `/api/send-push`
4. **Frontend:** Verify notification received

### Deploying a Feature

1. **Frontend:** Commit and push to TomOS-Apps repo
2. **Frontend:** Build and test on device
3. **Backend:** Commit and push to TomOS repo
4. **Backend:** Auto-deploys to Vercel

## Archive Location

**Old/Deprecated Files:** `/Users/tombragg/Desktop/TomOS-Archive/`

Contains:
- Old menu bar apps (TomOSAI, TomOSCapture)
- Legacy documentation
- iOS Shortcuts
- Setup guides from previous iterations
