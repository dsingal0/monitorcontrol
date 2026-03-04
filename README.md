# MonitorControl

Control external display brightness, contrast, and volume from your Mac menu bar using DDC/CI. Supports native Apple keyboard media keys and custom shortcuts.

## Features

- Brightness, volume, and contrast control via menu bar sliders or keyboard
- Native OSD overlay for brightness and volume changes
- DDC/CI for external displays, native protocol for Apple/built-in displays, gamma and shade control for virtual displays
- Smooth brightness transitions
- Combined hardware + software dimming (dim beyond display minimum, down to full black)
- Brightness sync across displays
- Display layouts: save and switch between display on/off configurations
- Enable/disable individual displays from the menu bar
- Custom keyboard shortcuts

## Build from source

### Prerequisites

- Xcode (with command line tools)
- [SwiftLint](https://github.com/realm/SwiftLint): `brew install swiftlint`
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat): `brew install swiftformat`
- [BartyCrouch](https://github.com/Flinesoft/BartyCrouch): `brew install bartycrouch`

### Build and install

```sh
# Clone
git clone https://github.com/MonitorControl/MonitorControl.git
cd MonitorControl

# Build (arm64 only, for Apple Silicon)
xcodebuild -scheme MonitorControl -configuration Release -arch arm64 ONLY_ACTIVE_ARCH=YES build

# For universal binary (Intel + Apple Silicon)
xcodebuild -scheme MonitorControl -configuration Release build

# Copy to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/MonitorControl-*/Build/Products/Release/MonitorControl.app /Applications/

# Ad-hoc sign (required for local builds)
codesign --deep --force --sign - /Applications/MonitorControl.app

# Launch
open /Applications/MonitorControl.app
```

### Post-install

If you want to use native Apple keyboard brightness/media keys, grant Accessibility access when prompted under **System Settings > Privacy & Security > Accessibility**.

## Dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Settings](https://github.com/sindresorhus/Settings)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

Dependencies are resolved automatically via Swift Package Manager when building.

## Credits

Based on [MonitorControl](https://github.com/MonitorControl/MonitorControl) by [@waydabber](https://github.com/waydabber), [@the0neyouseek](https://github.com/the0neyouseek), [@JoniVR](https://github.com/JoniVR), and [contributors](https://github.com/MonitorControl/MonitorControl/graphs/contributors).
