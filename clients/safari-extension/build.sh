#!/bin/bash
# NewsBlur Archive Safari Extension - Build Script
# Copies WebExtension files and prepares for Xcode build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSER_EXT_DIR="$(dirname "$SCRIPT_DIR")/browser-extension"
RESOURCES_DIR="$SCRIPT_DIR/NewsBlur Archive/NewsBlur Archive Extension/Resources"
IMAGES_DIR="$RESOURCES_DIR/images"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}NewsBlur Archive Safari Extension - Build Script${NC}"

# Check if browser extension exists
if [ ! -d "$BROWSER_EXT_DIR" ]; then
    echo -e "${RED}Error: Browser extension not found at $BROWSER_EXT_DIR${NC}"
    echo "Please build the browser extension first."
    exit 1
fi

# Create directories
mkdir -p "$RESOURCES_DIR"
mkdir -p "$IMAGES_DIR"

# Copy icons
echo -e "${YELLOW}Copying icons...${NC}"
cp "$BROWSER_EXT_DIR/icons/icon-16.png" "$IMAGES_DIR/"
cp "$BROWSER_EXT_DIR/icons/icon-32.png" "$IMAGES_DIR/"
cp "$BROWSER_EXT_DIR/icons/icon-48.png" "$IMAGES_DIR/"
cp "$BROWSER_EXT_DIR/icons/icon-128.png" "$IMAGES_DIR/"

# Copy and bundle JavaScript files
echo -e "${YELLOW}Bundling JavaScript files...${NC}"

# Create bundled background.js (combine all background modules)
cat > "$RESOURCES_DIR/background.js" << 'BACKGROUND_EOF'
// NewsBlur Archive Safari Extension - Background Script
// Bundled from browser extension source files

BACKGROUND_EOF

cat "$BROWSER_EXT_DIR/src/shared/constants.js" >> "$RESOURCES_DIR/background.js"
echo "" >> "$RESOURCES_DIR/background.js"
cat "$BROWSER_EXT_DIR/src/shared/utils.js" >> "$RESOURCES_DIR/background.js"
echo "" >> "$RESOURCES_DIR/background.js"
cat "$BROWSER_EXT_DIR/src/lib/api.js" >> "$RESOURCES_DIR/background.js"
echo "" >> "$RESOURCES_DIR/background.js"
cat "$BROWSER_EXT_DIR/src/lib/storage.js" >> "$RESOURCES_DIR/background.js"
echo "" >> "$RESOURCES_DIR/background.js"
cat "$BROWSER_EXT_DIR/src/background/service-worker.js" >> "$RESOURCES_DIR/background.js"

# Remove ES module syntax for Safari compatibility
sed -i '' 's/^export //g' "$RESOURCES_DIR/background.js"
sed -i '' 's/^import .*;//g' "$RESOURCES_DIR/background.js"

# Create bundled content.js
cat > "$RESOURCES_DIR/content.js" << 'CONTENT_EOF'
// NewsBlur Archive Safari Extension - Content Script
// Bundled from browser extension source files

CONTENT_EOF

cat "$BROWSER_EXT_DIR/src/content/detector.js" >> "$RESOURCES_DIR/content.js"
sed -i '' 's/^export //g' "$RESOURCES_DIR/content.js"
sed -i '' 's/^import .*;//g' "$RESOURCES_DIR/content.js"

# Copy HTML and CSS files
echo -e "${YELLOW}Copying HTML and CSS files...${NC}"

# Popup
cp "$BROWSER_EXT_DIR/src/popup/popup.html" "$RESOURCES_DIR/popup.html"
cp "$BROWSER_EXT_DIR/src/popup/popup.css" "$RESOURCES_DIR/popup.css"

# Create bundled popup.js
cat > "$RESOURCES_DIR/popup.js" << 'POPUP_EOF'
// NewsBlur Archive Safari Extension - Popup Script
// Bundled from browser extension source files

POPUP_EOF

cat "$BROWSER_EXT_DIR/src/shared/constants.js" >> "$RESOURCES_DIR/popup.js"
echo "" >> "$RESOURCES_DIR/popup.js"
cat "$BROWSER_EXT_DIR/src/shared/utils.js" >> "$RESOURCES_DIR/popup.js"
echo "" >> "$RESOURCES_DIR/popup.js"
cat "$BROWSER_EXT_DIR/src/popup/popup.js" >> "$RESOURCES_DIR/popup.js"
sed -i '' 's/^export //g' "$RESOURCES_DIR/popup.js"
sed -i '' 's/^import .*;//g' "$RESOURCES_DIR/popup.js"

# Update popup.html to reference bundled files
sed -i '' 's|type="module" src="popup.js"|src="popup.js"|g' "$RESOURCES_DIR/popup.html"
sed -i '' 's|href="popup.css"|href="popup.css"|g' "$RESOURCES_DIR/popup.html"
sed -i '' 's|src="../../icons/|src="images/|g' "$RESOURCES_DIR/popup.html"

# Options
cp "$BROWSER_EXT_DIR/src/options/options.html" "$RESOURCES_DIR/options.html"
cp "$BROWSER_EXT_DIR/src/options/options.css" "$RESOURCES_DIR/options.css"

# Create bundled options.js
cat > "$RESOURCES_DIR/options.js" << 'OPTIONS_EOF'
// NewsBlur Archive Safari Extension - Options Script
// Bundled from browser extension source files

OPTIONS_EOF

cat "$BROWSER_EXT_DIR/src/shared/constants.js" >> "$RESOURCES_DIR/options.js"
echo "" >> "$RESOURCES_DIR/options.js"
cat "$BROWSER_EXT_DIR/src/shared/utils.js" >> "$RESOURCES_DIR/options.js"
echo "" >> "$RESOURCES_DIR/options.js"
cat "$BROWSER_EXT_DIR/src/lib/api.js" >> "$RESOURCES_DIR/options.js"
echo "" >> "$RESOURCES_DIR/options.js"
cat "$BROWSER_EXT_DIR/src/lib/storage.js" >> "$RESOURCES_DIR/options.js"
echo "" >> "$RESOURCES_DIR/options.js"
cat "$BROWSER_EXT_DIR/src/options/options.js" >> "$RESOURCES_DIR/options.js"
sed -i '' 's/^export //g' "$RESOURCES_DIR/options.js"
sed -i '' 's/^import .*;//g' "$RESOURCES_DIR/options.js"

# Update options.html to reference bundled files
sed -i '' 's|type="module" src="options.js"|src="options.js"|g' "$RESOURCES_DIR/options.html"
sed -i '' 's|href="options.css"|href="options.css"|g' "$RESOURCES_DIR/options.html"
sed -i '' 's|src="../../icons/|src="images/|g' "$RESOURCES_DIR/options.html"

# Copy locales
echo -e "${YELLOW}Copying locales...${NC}"
cp -r "$BROWSER_EXT_DIR/_locales" "$RESOURCES_DIR/"

echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open 'NewsBlur Archive.xcodeproj' in Xcode"
echo "2. Select your development team in Signing & Capabilities"
echo "3. Build and run the app"
echo "4. Enable the extension in Safari → Settings → Extensions"
