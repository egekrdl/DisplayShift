# DisplayShift

DisplayShift is a native macOS menu bar utility for saving and switching between display arrangements. Use it to move a MacBook's logical display from the right of an external monitor to below it, or to switch between other multi-monitor setups.

## Features

- Capture, apply, rename, update, reorder, and delete locally saved presets.
- Drag displays into a new arrangement directly from the menu bar. Apply the draft or save it as a preset.
- Preview relative display positions and sizes. A filled rectangle identifies the built-in display and a short bar marks the primary display.
- See which presets match the current arrangement and optionally show an active preset name in the menu bar.
- Assign global keyboard shortcuts to individual presets and toggle between two chosen presets.
- Optionally launch at login using macOS Login Items.
- Refresh connected-display information when macOS reports a screen change.
- Works offline with no third-party dependencies, telemetry, or Accessibility and Input Monitoring prompts.

## Requirements

- macOS 13 Ventura or newer.
- Apple Silicon or Intel Mac for the universal release.
- Xcode 16 or newer to work with the Xcode project. The local release was built with Xcode 27.2.

## Build and test

Open `DisplayShift.xcodeproj` and select the **DisplayShift** scheme. Use **Product → Build**, or build a universal Release from the repository root:

```sh
xcodebuild -project DisplayShift.xcodeproj -scheme DisplayShift \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
swift test
```

The bundle is at `build/Build/Products/Release/DisplayShift.app`. Swift Package Manager runs the unit tests against the same model and persistence sources used by the Xcode app. The tests do not open a display configuration transaction.

## Install

Unzip the release if needed, move `DisplayShift.app` to **Applications**, then open it. Look for the two-display icon in the menu bar. If macOS blocks a downloaded copy, use a build you made yourself or a trusted Developer ID–signed and notarized release. The local build uses ad hoc signing and has not been notarized.

## Use

1. Arrange your monitors in **System Settings → Displays → Arrange**.
2. Open DisplayShift and select **Save Current Layout**. Enter a name such as **Side Setup**.
3. Arrange the monitors for the second setup and save it as **Bottom Setup**.
4. Select a preset in the menu bar to apply it. The active check mark follows the arrangement reported by macOS.
5. Under **Settings → Shortcuts**, choose each preset, review the proposed shortcut, and click **Assign Shortcut**. The proposals for **Side Setup** and **Bottom Setup** are Control–Option–1 and Control–Option–2.
6. Select two presets under **Toggle Pair**. The default toggle shortcut is Control–Option–Space. If neither preset is active, the toggle applies the first one.
7. Use **Settings → Presets** to change the list. Use **Settings → General** for Launch at Login and menu bar title preferences.

### Edit a layout from the menu bar

Choose **Edit Layout…** and drag a display near another display's edge. The editor snaps neighboring edges together and helps align centers and edges. The bar at the top of a rectangle identifies the primary display.

Click **Apply** to use the arrangement, or enter a name and click **Save as Preset** to keep the draft without applying it. **Reset** reloads the current arrangement. The editor requires one connected layout with no overlapping displays. With three or more displays, move any screens that would become isolated before moving the display joining them. Reset the draft after connecting a display or changing its size.

## Known limitations

- A preset requires the same set of active displays. Mirrored displays must be switched to extended mode before capture or restore. Hot-plug events only refresh the display list.
- Display identity uses the manufacturer, model, and serial when usable, then a macOS display UUID where available. Some docks, ports, virtual displays, and identical monitors report changed or ambiguous identities. If a display no longer matches, recapture its preset in the intended setup.
- The app sends only display origins through Core Graphics. Resolution, refresh rate, scaling, rotation, HDR, and color profiles are outside the preset. Quartz can normalize positions to avoid gaps and overlap. A changed display size or orientation can make a saved position impossible. Capture a new preset for the new configuration.
- Quartz designates the primary display through the origin at `(0, 0)`. DisplayShift verifies the requested origins and primary after applying them, and attempts to restore the prior arrangement if Quartz returns a different result and the original display set is still available. An applied arrangement is scoped to the current login session. Presets persist across restarts.
- Shortcut labels refer to ANSI key positions. Some non-US keyboard layouts print different characters. Conflict detection covers DisplayShift assignments and conflicts macOS reports to the registration API. Some other apps register their shortcuts nonexclusively or handle them outside that API.
- macOS may require approval for Launch at Login under **System Settings → General → Login Items**.

### Hardware verification

For a real multi-monitor test, record the starting arrangement and display settings. Capture a side and bottom layout, apply each from the menu and its shortcut, then test the toggle while another app has focus. Check display positions, primary, and display mode settings in System Settings. Disconnect a required display and confirm the preset reports the missing display without rearranging the others. Reconnect it and confirm the preset is not applied automatically. Test Launch at Login from the installed app by signing out and back in.

## Architecture

| Path | Responsibility |
| --- | --- |
| `DisplayShift/App` | SwiftUI menu bar lifecycle and AppKit settings window |
| `DisplayShift/Models` | Display identity, preset data, coordinate planning, and shortcut settings |
| `DisplayShift/Services` | Core Graphics transactions, Carbon hotkey registration, and UserDefaults persistence |
| `DisplayShift/ViewModels` | Injected display service, preset operations, event handling, and login integration |
| `DisplayShift/Views` | Popover, layout previews, and settings |
| `DisplayShift/Resources` | Application icon assets |
| `Tests` | Hardware-independent XCTest coverage |
