# RestBell

RestBell is a small macOS menu bar timer for alternating work and eye breaks. It uses Swift, AppKit, and SwiftUI with no external dependencies.

## Screenshots

<img src="docs/screenshots/menu-bar.png" alt="RestBell menu bar timer with 24 minutes and 59 seconds left in a work session" width="80">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/settings-dark.png">
  <img src="docs/screenshots/settings.png" alt="RestBell settings with work and rest durations, a bell sound preview, and an Open at Login checkbox" width="370">
</picture>

## Build and open

Use macOS 14 or later and the Apple command line tools with Swift 6. From the repository, run:

```sh
app="$(./scripts/build-app)" && open "$app"
```

For a permanent copy you can open at login, copy the built bundle into your Applications folder.

```sh
app="$(./scripts/build-app)" &&
  mkdir -p "$HOME/Applications" &&
  ditto "$app" "$HOME/Applications/RestBell.app" &&
  open "$HOME/Applications/RestBell.app"
```

## Use

- Click **RestBell** in the menu bar to see your work/rest minutes above **Start**. Choose **Start** to begin a work session.
- The menu bar shows **W** for work and **R** for rest, followed by the time remaining. Before each switch, it counts down from 3 and plays the selected bell sound once per second.
- **Reset** stops the cycle. The next **Start** begins a full work session.
- In **Settings…**, enter 1–999 whole minutes for work and rest or use the arrows to adjust either by one minute. Valid entries save when you press Return or leave the field. The defaults are 25 and 5 minutes. Changes apply the next time that session starts.
- Choose a **Bell sound** and click **Play** to hear it. RestBell enables **Open RestBell at login** by default when installed in Applications. You can turn it off in Settings.
- The countdown freezes while the Mac sleeps.

## Development

Run `swift test --disable-xctest` to check the work/rest cycle and reset behavior. GitHub Actions runs these tests and verifies the app bundle on macOS.

The build script signs the bundle for local use. A downloadable release can be signed with Developer ID and notarized for distribution. [Apple's distribution guide](https://developer.apple.com/macos/distribution/)
