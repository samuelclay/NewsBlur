# NewsBlur Archive Safari Extension

A Safari Web Extension that automatically archives your browsing history and syncs it to NewsBlur for AI-powered search.

## Requirements

- macOS 13.0 or later
- Safari 16.4 or later
- Xcode 15.0 or later (for building)
- NewsBlur account with Premium Archive subscription

## Building

### Prerequisites

1. Install Xcode from the Mac App Store
2. Build the browser extension first (required for web extension files):

```bash
cd ../browser-extension
./build/build.sh
```

### Build Steps

1. Run the build script to copy web extension files:

```bash
./build.sh
```

2. Open the Xcode project:

```bash
open "NewsBlur Archive.xcodeproj"
```

3. Configure signing:
   - Select the "NewsBlur Archive" target
   - Go to Signing & Capabilities
   - Select your development team
   - Do the same for "NewsBlur Archive Extension" target

4. Build and run (⌘R)

### App Groups

The app uses an App Group (`group.com.newsblur.archive`) for shared storage between the main app and the Safari extension. Make sure this is properly configured in your Apple Developer account.

## Installation

### Development

1. Build and run the app from Xcode
2. Open Safari → Settings → Extensions
3. Enable "NewsBlur Archive"
4. Grant "Allow on All Websites" permission

### Distribution

For App Store distribution:
1. Archive the app in Xcode (Product → Archive)
2. Follow Apple's notarization and submission process
3. Submit to the Mac App Store

## Project Structure

```
clients/safari-extension/
├── NewsBlur Archive/
│   └── NewsBlur Archive/
│       ├── AppDelegate.swift          # Main app delegate
│       ├── ViewController.swift       # Extension status UI
│       ├── Main.storyboard           # UI layout
│       ├── Assets.xcassets/          # App icons
│       ├── Info.plist                # App configuration
│       └── NewsBlur_Archive.entitlements
├── NewsBlur Archive Extension/
│   ├── SafariWebExtensionHandler.swift  # Native messaging handler
│   ├── Resources/                       # Web extension files
│   │   ├── manifest.json
│   │   ├── background.js
│   │   ├── content.js
│   │   ├── popup.html/js/css
│   │   ├── options.html/js/css
│   │   └── images/
│   ├── Info.plist
│   └── NewsBlur_Archive_Extension.entitlements
├── NewsBlur Archive.xcodeproj/
├── build.sh                           # Build script
└── README.md
```

## Native Messaging

The extension supports native messaging between the Safari extension and the macOS app:

- `getAppGroupIdentifier`: Returns the app group identifier for shared storage
- `getNativeStatus`: Returns the native app status and version
- `log`: Logs messages from the extension to the native console

## Differences from Chrome/Firefox

Safari Web Extensions have some differences from standard WebExtensions:

1. **Manifest Version**: Uses v3 manifest similar to Chrome
2. **Native Messaging**: Handled through `SafariWebExtensionHandler`
3. **App Wrapper**: Requires a macOS app to host the extension
4. **Permissions**: Some permissions work differently in Safari
5. **Storage**: Uses App Groups for shared storage with the native app

## Troubleshooting

### Extension not appearing in Safari

1. Make sure the app has been run at least once
2. Check Safari → Settings → Extensions
3. Try toggling the extension off and on

### "Allow on All Websites" not working

1. Make sure you've granted the permission in Safari settings
2. Try restarting Safari
3. Check Console.app for extension errors

### Build errors

1. Make sure you've run the browser extension build first
2. Check that your development team is properly configured
3. Verify App Group entitlements match your provisioning profile

## License

MIT License - See LICENSE file
