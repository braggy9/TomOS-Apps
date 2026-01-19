# Personal Notes (TomOS-Apps)

This file is gitignored - use it for your private notes, todos, and context that shouldn't be committed.

## Current Focus

All core features complete! Both iOS and macOS push notifications working.

## Completed Tasks

- [x] iOS push notifications working
- [x] macOS push notifications working
- [x] Menu bar interface
- [x] App installed in /Applications
- [x] Auto-start on login
- [x] Notification action buttons
- [x] Local notification scheduler
- [x] Global keyboard shortcuts (⌘⌥ pattern) - Phase 6 COMPLETE

## Registered Devices

- **iOS:** f757db2b408a19ec...
- **macOS:** 025aeb1d4d823d33...

## Key Fix: macOS Entitlements

macOS requires `com.apple.developer.aps-environment` (not just `aps-environment`) in the entitlements file. This was the root cause of macOS push notification failures.

## macOS Provisioning Profile

Created manually in Apple Developer Portal:
- Type: macOS App Development
- App ID: com.tomos.app
- Includes Push Notifications capability

## Testing Notes

- APNs requires physical device (not Simulator)
- Notification permission must be granted
- Check Xcode console for device token
- Test push: `curl -X POST https://tomos-task-api.vercel.app/api/send-push -H "Content-Type: application/json" -d '{"title":"Test","body":"Hello!","badge":1}'`

## Update App in Applications

After Xcode changes:
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Debug/TomOS.app" -type d 2>/dev/null | head -1)
rm -rf /Applications/TomOS.app && cp -R "$APP_PATH" /Applications/TomOS.app
```

## Context for Next Session

### Build 14 - MatterOS Integration Complete (2026-01-19)

**✅ Completed Tonight:**
1. **MatterOS iOS Integration**
   - Created Matter.swift data models (Matter, MatterDocument, MatterEvent, MatterNote)
   - Built MattersView with filtering (All, Active, Completed, On Hold, Urgent, High)
   - Built MatterDetailView with tabbed sections (Overview, Documents, Timeline, Notes)
   - Built CreateMatterView form with validation
   - Added Matters tab to iOS app (between Smart Surface and My Tasks)
   - All 7 MatterOS API methods integrated

2. **Email-to-Task Fix (macOS) - CRITICAL FIX**
   - **Root Cause:** Missing AppleEvents entitlement for Outlook access
   - **Fixed:** Added `com.apple.security.temporary-exception.apple-events` to macOS entitlements
   - **Fixed:** Added NSAppleEventsUsageDescription to Info.plist
   - **Status:** ⌘⌥E email-to-task now has proper permissions
   - **Action Required:** User must grant permission when first using ⌘⌥E

3. **Cross-Platform Compatibility**
   - Made all MatterOS views work on both iOS and macOS
   - Wrapped iOS-only modifiers (.textInputAutocapitalization, .navigationBarTitleDisplayMode)
   - Fixed toolbar placements for macOS (navigation/automatic vs topBarLeading/topBarTrailing)
   - Both iOS and macOS builds succeed

4. **Documentation Updates**
   - Updated CLAUDE.md with Build 14 details
   - Documented MatterOS integration
   - Added MatterOS API endpoints section
   - Three commits pushed to GitHub

**Updated macOS app** in /Applications with email-to-task fix

### Global Keyboard Shortcuts
- ⌘⌥T - Quick Task Capture (floating window)
- ⌘⌥E - Email to Task (Outlook) - **NOW FIXED**
- ⌘⌥1 - Brain Dump
- ⌘⌥2 - What Should I Work On?
- ⌘⌥3 - Send Morning Overview
- ⌘⌥4 - Send EOD Summary
- ⌘⌥5 - Open Dashboard
- ⌘⌥M - Show Menu Bar Dropdown
- ⌘⌥Q - Quit TomOS

**Requires Permissions:**
- Accessibility (for global shortcuts)
- Automation (for Outlook/AppleEvents) - **NEW**

### Next Steps (User's Priority List)
- [ ] Test email-to-task functionality (⌘⌥E) - verify permission prompt works
- [ ] Consider linking email-to-task to MatterOS (e.g., attach email to matter)
- [ ] Review and enhance iOS/macOS app functionality
- [ ] Consider easy ways to add tasks in iOS
- [ ] Build web dashboard (lower priority)
- [ ] Deploy Build 14 to TestFlight

---

**This file stays local - commit your progress to `claude-progress.txt` instead!**
