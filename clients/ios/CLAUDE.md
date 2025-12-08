# iOS Development Guidelines

## iOS Simulator Testing
- **idb (iOS Development Bridge)**: Use `idb` for UI interactions like tapping coordinates
  - Install: `brew install idb-companion` and `pip3 install --user fb-idb`
  - Add to PATH: `export PATH="$PATH:~/Library/Python/3.13/bin"`
  - Tap: `idb ui tap --udid <UDID> <x> <y>`
- **xcrun simctl commands**:
  - List devices: `xcrun simctl list devices`
  - Install app: `xcrun simctl install booted <path/to/App.app>`
  - Launch app: `xcrun simctl launch booted <bundle.id>`
  - Terminate app: `xcrun simctl terminate booted <bundle.id>`
  - Screenshot: `xcrun simctl io booted screenshot /tmp/screenshot.png`
  - Stream logs: `xcrun simctl spawn booted log stream --predicate 'process == "NewsBlur"'`
- **Build for simulator**: `xcodebuild -project NewsBlur.xcodeproj -scheme NewsBlur -destination 'id=<UDID>' -configuration Debug build`
