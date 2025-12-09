# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Open in Xcode:
```bash
open NewsBlur.xcodeproj
```

Build from command line:
```bash
xcodebuild -project NewsBlur.xcodeproj -scheme "NewsBlur" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Build for Alpha (development):
```bash
xcodebuild -project NewsBlur.xcodeproj -scheme "NewsBlur Alpha" -sdk iphonesimulator build
```

Run tests:
```bash
xcodebuild -project NewsBlur.xcodeproj -scheme "NewsBlur" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Architecture Overview

### Language Mix
The app uses **Objective-C** as the primary language with **Swift** for newer components. Swift-ObjC bridging is done through `Other Sources/BridgingHeader.h`.

### Key Classes

- **NewsBlurAppDelegate** (`Classes/NewsBlurAppDelegate.h/m`): Central singleton managing app state, navigation, feeds data, offline storage, and network operations. Access via `NewsBlurAppDelegate.shared`.

- **StoriesCollection** (`Classes/StoriesCollection.h/m`): Manages the current collection of stories being displayed (feed, folder, river view). Handles story state (read/unread/saved) and navigation.

- **ThemeManager** (`Classes/ThemeManager.h/m`): Handles app theming (Light/Sepia/Medium/Dark). Uses macros like `UIColorFromRGB()` and `UIColorFromLightDarkRGB()`.

### View Controller Hierarchy

The app uses a **three-column UISplitViewController** layout:
1. **FeedsViewController** (Swift): Feed list sidebar
2. **FeedDetailViewController** (Swift): Story list
3. **DetailViewController** (Swift): Story content

Many view controllers have both ObjC and Swift versions:
- `FeedsObjCViewController.m` / `FeedsViewController.swift`
- `FeedDetailObjCViewController.m` / `FeedDetailViewController.swift`
- `StoryPagesObjCViewController.m` / `StoryPagesViewController.swift`
- `StoryDetailObjCViewController.m` / `StoryDetailViewController.swift`

### SwiftUI Components
Newer UI components use SwiftUI:
- `FeedDetailCardView.swift`, `FeedDetailGridView.swift` - Story cards
- `TrainerView.swift`, `TrainerCapsule.swift` - Intelligence trainer
- `Story.swift`, `Feed.swift` - Data models

### App Extensions

- **Share Extension**: For sharing URLs to NewsBlur (`Share Extension/`)
- **Widget Extension**: Home screen widget (`Widget Extension/`)
- **Story Notification Service Extension**: Push notification handling (`Story Notification Service Extension/`)

### Networking

Uses **AFNetworking** for HTTP requests. API calls go through `NewsBlurAppDelegate`:
```objc
[appDelegate GET:@"/reader/feeds" parameters:nil success:^(...) {...} failure:^(...) {...}];
[appDelegate POST:@"/reader/mark_story_as_read" parameters:params success:^(...) {...} failure:^(...) {...}];
```

### Offline Storage

Uses **FMDB** (SQLite wrapper) for local database:
- `database` property on NewsBlurAppDelegate
- Offline sync via `Classes/offline/` (OfflineFetchStories, OfflineFetchText, OfflineFetchImages)

Uses **PINCache** for image caching (`cachedFavicons`, `cachedStoryImages`).

### Story Display

Story content is rendered in WKWebView with:
- `static/storyDetailView.js` - Story interaction JavaScript
- `static/storyDetailView.css` - Base styles
- `static/storyDetailView{Light,Sepia,Medium,Dark}.css` - Theme variants

## Targets & Schemes

| Scheme | Bundle ID | Purpose |
|--------|-----------|---------|
| NewsBlur | com.newsblur.NewsBlur | Production release |
| NewsBlur Alpha | com.newsblur.NB-Alpha | Development/testing |
| Widget Extension | com.newsblur.NewsBlur.widget | Home screen widget |
| Share Extension | com.newsblur.NewsBlur.Share-Extension | Share sheet |

## Code Style

- **Objective-C**: Standard Apple conventions
- **Swift**: Swift 5.0, iOS 14.0+ deployment target (17.0 for widgets)
- XIB files are used for some view controllers alongside storyboards
- Main storyboard: `Resources/MainInterface.storyboard`

## Third-Party Libraries (in Other Sources/)

- **AFNetworking**: HTTP networking
- **FMDB**: SQLite database wrapper
- **PINCache**: Disk/memory caching
- **MBProgressHUD**: Loading indicators
- **MCSwipeTableViewCell**: Swipeable table cells
- **InAppSettingsKit**: Settings UI
- **OnePasswordExtension**: 1Password integration

## iOS Simulator Testing

**IMPORTANT**: Do NOT use Chrome DevTools MCP server for iOS testing. Always use `run_ios.py` for screenshots and simulator interactions.

### run_ios.py - Simulator Control Script

Use `run_ios.py` for common simulator interactions. It handles idb PATH setup automatically.

```bash
# Basic actions
python3 run_ios.py tap:<x>,<y>              # Tap at coordinates
python3 run_ios.py sleep:<seconds>          # Wait
python3 run_ios.py swipe:<x1>,<y1>,<x2>,<y2> # Swipe
python3 run_ios.py screenshot:/tmp/shot.png  # Take screenshot
python3 run_ios.py launch                    # Launch NewsBlur
python3 run_ios.py terminate                 # Kill NewsBlur
python3 run_ios.py install                   # Install from DerivedData

# Chain multiple actions
python3 run_ios.py launch sleep:2 tap:175,600 sleep:1 screenshot:/tmp/result.png
```

### Manual Simulator Commands

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
