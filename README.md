# Still

A quiet, native macOS focus timer. Built with SwiftUI; runs locally without a browser, account, network connection, or third-party packages.

## Run

Open **build/Still.app** in Finder. You can drag the app to Applications if you like.

To rebuild from source with Apple's command line tools (Swift 6 or newer):

```sh
bash scripts/build.sh
open build/Still.app
```

Requires macOS 14 or later. The build script creates a locally signed app for the machine's architecture.

## Use

- Choose Focus or Rest, pick a preset, or set a custom duration from 1 to 180 minutes.
- Begin, pause, or continue with the main button or **Space**. **⌘R** resets the current session.
- Running sessions show their countdown in the macOS menu bar, even with the window closed. Click it to pause, resume, reset, or reopen Still. Paused sessions keep their time visible with a pause icon; the menu bar entry disappears after completion or reset.
- The ring slowly empties as time passes. A soft halo rotates while running; Reduce Motion disables decorative motion.
- The finish time appears below the countdown. Pausing holds the remaining time; resuming updates the finish time.
- Use the sun and moon to switch themes. The speaker menu controls and previews the gentle chime. Appearance and sound preferences are saved.

The timer uses an absolute deadline, so background delays don't accumulate. Closing the window keeps your timer running; click the Dock icon to reopen it. If the Mac sleeps, the timer accounts for elapsed time and rings when the app resumes. Audio cannot play while the computer is asleep. Quitting the app (⌘Q) discards the current session.

## Check

```sh
bash scripts/test.sh
```

Tests cover timer state transitions, pause/resume, delayed callbacks, one-time completion, duration bounds, and restart behavior.
The standalone test runner uses the Swift compiler and does not require full Xcode or XCTest.
