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

- System fully operational with all 6 phases complete
- Global keyboard shortcuts working:
  - ⌘⌥T - Quick Task Capture (floating window)
  - ⌘⌥1 - Brain Dump
  - ⌘⌥2 - What Should I Work On?
  - ⌘⌥3 - Send Morning Overview
  - ⌘⌥4 - Send EOD Summary
  - ⌘⌥5 - Open Dashboard
  - ⌘⌥M - Show Menu Bar Dropdown
  - ⌘⌥Q - Quit TomOS
- Requires Accessibility permissions for global shortcuts
- Consider: Widget support, Phase 7 feature consolidation

---

**This file stays local - commit your progress to `claude-progress.txt` instead!**
