# NewsBlur Archive Browser Extension

Automatically archives your browsing history and syncs it to NewsBlur for AI-powered search across everything you've read.

## Features

- **Automatic Archiving**: Captures pages you visit for more than 5 seconds
- **Privacy-First**: Extensive blocklist of sensitive domains (banking, medical, email)
- **Smart Sync**: Debounced batching minimizes network requests
- **Content Extraction**: Uses Readability-inspired extraction for clean content
- **NewsBlur Integration**: Save, Share, and Subscribe actions in popup
- **AI Categories**: Archives are automatically categorized for easy browsing

## Requirements

- NewsBlur account with Premium Archive subscription
- Chrome, Edge, Firefox, or Safari browser

## Installation

### Chrome / Edge

1. Open `chrome://extensions` (or `edge://extensions`)
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select the `clients/browser-extension` directory

### Firefox

1. Open `about:debugging#/runtime/this-firefox`
2. Click "Load Temporary Add-on"
3. Select `manifest.firefox.json` from the `clients/browser-extension` directory

### Safari

See `clients/safari-extension/` for Safari-specific build instructions.

## Development

### Project Structure

```
clients/browser-extension/
├── manifest.json              # Chrome/Edge manifest (v3)
├── manifest.firefox.json      # Firefox manifest (v2)
├── package.json               # npm scripts
├── src/
│   ├── background/
│   │   └── service-worker.js  # Background script
│   ├── content/
│   │   └── detector.js        # Content extraction
│   ├── popup/
│   │   ├── popup.html
│   │   ├── popup.js
│   │   └── popup.css
│   ├── options/
│   │   ├── options.html
│   │   ├── options.js
│   │   └── options.css
│   ├── lib/
│   │   ├── api.js             # NewsBlur API client
│   │   └── storage.js         # Chrome storage wrapper
│   └── shared/
│       ├── constants.js       # Constants and blocklist
│       └── utils.js           # Utility functions
├── icons/
│   ├── icon-16.png
│   ├── icon-32.png
│   ├── icon-48.png
│   └── icon-128.png
├── _locales/
│   └── en/
│       └── messages.json
└── build/
    └── build.sh               # Build script
```

### Building

```bash
# Build all browsers
./build/build.sh

# Or use npm scripts
npm run build:chrome
npm run build:firefox
npm run package
```

### Testing

1. Load the extension in developer mode (see Installation)
2. Navigate to various websites
3. Open the popup to see archived pages
4. Check the options page for settings and blocklist

## Configuration

### Default Blocklist

The extension blocks archiving on:
- Banking and financial sites
- Medical and health portals
- Email providers
- Password managers
- Internal/localhost URLs
- Login and checkout pages

Users can add custom blocked domains in the options page.

### Settings

- **Enable archiving**: Toggle automatic archiving on/off
- **Enable sync**: Toggle syncing to NewsBlur
- **Minimum time on page**: How long before a page is archived (3-30 seconds)

## API Endpoints

The extension communicates with NewsBlur using these endpoints:

- `POST /api/archive/ingest` - Submit a single archive
- `POST /api/archive/batch_ingest` - Submit multiple archives
- `GET /api/archive/list` - List archives with filters
- `GET /api/archive/stats` - Get archive statistics
- `GET/POST /api/archive/blocklist` - Manage blocklist

## Privacy

- No data is collected on blocked domains
- All data is stored in your NewsBlur account
- Content is compressed and encrypted in transit
- You can export or delete your data at any time

## License

MIT License - See LICENSE file
