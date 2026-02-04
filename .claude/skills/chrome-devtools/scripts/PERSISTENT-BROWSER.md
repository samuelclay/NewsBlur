# Persistent Browser Mode

These scripts enable you to launch Chrome once and keep it open for multiple commands, making it easier to interact with authenticated sessions and multi-step workflows.

## Quick Start

### 1. Launch Persistent Browser

```bash
# Launch browser (visible window)
node launch-persistent.js --headless=false

# Launch with initial URL
node launch-persistent.js --headless=false --url=https://example.com/login

# Launch headless
node launch-persistent.js
```

The browser will stay open and print a message confirming it's ready.

### 2. Run Commands

All existing scripts will automatically connect to the persistent browser:

```bash
# Navigate to a page
node navigate.js --url https://example.com/dashboard

# Take a screenshot
node screenshot.js --output ./screenshot.png

# Run JavaScript
node evaluate.js --script "document.title"

# Get page snapshot
node snapshot.js

# Fill forms
node fill.js --selector "#username" --value "user@example.com"
node click.js --selector "button[type=submit]"
```

### 3. Close Browser

```bash
# Close the persistent browser
node close-persistent.js

# Or press Ctrl+C in the launch-persistent.js terminal
```

## How It Works

1. **launch-persistent.js** starts Chrome with remote debugging enabled and saves the WebSocket endpoint to `.browser-endpoint`
2. All other scripts check for this file first and connect to the existing browser if found
3. If no persistent browser exists, scripts fall back to launching their own temporary browser (original behavior)

## Use Cases

### Authenticated Sessions
```bash
# Launch browser
node launch-persistent.js --headless=false --url=https://app.example.com/login

# Manually log in through the visible browser window
# Then run commands on authenticated pages

node navigate.js --url=https://app.example.com/dashboard
node screenshot.js --output ./dashboard.png
node evaluate.js --script "document.querySelector('.user-name').textContent"
```

### Multi-Step Workflows
```bash
# Launch browser
node launch-persistent.js --headless=false

# Fill out multi-page form
node navigate.js --url=https://example.com/signup
node fill.js --selector "#email" --value "user@example.com"
node click.js --selector ".next-button"
# Wait for page to load, then continue...
node fill.js --selector "#password" --value "secret123"
node click.js --selector ".submit-button"
```

### Accessibility Audits on Live Pages
```bash
# Launch and navigate manually to complex authenticated state
node launch-persistent.js --headless=false

# After manual navigation/interaction, run audits
node evaluate.js --script "/* accessibility check script */"
node screenshot.js --output ./audit.png
```

## Advantages

- **Manual interaction**: Log in, navigate, or manipulate the page manually
- **Persistent state**: Cookies, localStorage, and session state preserved
- **Faster iterations**: No browser startup delay for each command
- **Real-world testing**: Test on actual authenticated or complex application states

## Backwards Compatibility

All existing scripts work exactly as before if no persistent browser is running. The enhancement is completely opt-in.
