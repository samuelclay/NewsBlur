#!/usr/bin/env node
// refresh-manifest.cjs inventories local assets without launching an app or browser.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');

const root = __dirname;
const repository = path.resolve(root, '../../../../../..');
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function inventory(relativePath, base = root) {
  const absolutePath = path.resolve(base, relativePath);
  if (!fs.existsSync(absolutePath)) return {path: relativePath, status: 'pending'};
  const bytes = fs.readFileSync(absolutePath);
  const result = {path: relativePath, status: 'present', bytes: bytes.length, sha256: sha256(bytes)};
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    result.format = 'png';
    result.width = bytes.readUInt32BE(16);
    result.height = bytes.readUInt32BE(20);
  }
  return result;
}
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
// Only evaluate the local declarative concept array, not the gallery runtime.
const concepts = vm.runInNewContext(script.slice(0, script.indexOf('const params')) + '\nconcepts');
const languages = Object.keys(JSON.parse(fs.readFileSync(path.join(repository, 'localization/languages.json'))));
const copy = Object.fromEntries(languages.map(language => {
  const value = JSON.parse(fs.readFileSync(path.join(root, 'copy', `${language}.json`)));
  if (value.language !== language || value.headlines.length !== 4 || value.labels.length !== 4) {
    throw new Error(`Invalid canonical copy: ${language}`);
  }
  return [language, value];
}));
concepts[0].headlines = copy.en.headlines;
concepts[0].labels = copy.en.labels;
concepts[0].captures = ['stories', 'feeds', 'reader', 'saved'];
const datasetPath = 'clients/ios/MarketingCooking/cooking.json';
const photoSourcesPath = 'clients/ios/MarketingCooking/photo-sources.json';
const data = JSON.parse(fs.readFileSync(path.join(repository, datasetPath)));
const photos = JSON.parse(fs.readFileSync(path.join(repository, photoSourcesPath)));
const modes = {
  iphone: {
    expected_capture: {width: 1320, height: 2868, format: 'png'},
    expected_canvas: {width: 1320, height: 2868},
    export_sizes: [{width: 1320, height: 2868}, {width: 1206, height: 2622}],
    bezel: {path: '../selected/assets/iphone-18-pro-max.png', width: 1470, height: 3000},
    screen_opening: {x: 75, y: 66, width: 1320, height: 2868},
  },
  ipad: {
    expected_capture: {width: 2064, height: 2752, format: 'png'},
    expected_canvas: {width: 2064, height: 2752},
    export_sizes: [{width: 2064, height: 2752}],
    bezel: {path: '../selected/assets/ipad-pro-m5.png', width: 2300, height: 3000},
    screen_opening: {x: 118, y: 124, width: 2064, height: 2752},
  },
};
const captureStates = {feeds: 'reader', stories: 'reader-folder-tech', reader: 'reader-story-swift-1', saved: 'cooking-saved'};
const captures = [];
const plannedExports = [];
const capturePath = (language, device, view) => `captures/${language === 'en' ? '' : `localized/${language}/`}${device}-${view}.png`;
for (const [device, mode] of Object.entries(modes)) {
  mode.bezel.file = inventory(mode.bezel.path);
  for (const language of languages) {
    for (const [view, launchState] of Object.entries(captureStates)) {
      const file = inventory(capturePath(language, device, view));
      const valid = file.status === 'present' && file.format === 'png' && file.width === mode.expected_capture.width && file.height === mode.expected_capture.height;
      captures.push({language, device, view, launch_state: launchState, expected: mode.expected_capture, ...file,
        status: file.status === 'pending' ? 'pending_capture' : valid ? 'captured_pending_review' : 'invalid_capture_dimensions_or_format',
        visual_review: 'pending',
      });
    }
    const concept = concepts[0];
    for (const canvas of mode.export_sizes) {
      const size = `${canvas.width}x${canvas.height}`;
      concept.captures.forEach((capture, index) => {
        const file = inventory(`exports/${language}/${size}/panel-${index + 1}.png`);
        plannedExports.push({concept: concept.id, language, device, panel: index + 1, headline: copy[language].headlines[index],
          capture: capturePath(language, device, capture),
          render_path: `index.html?concept=${concept.id}&device=${device}&lang=${language}&panel=${index + 1}&export=1&size=${size}`,
          expected: {...canvas, format: 'png'}, ...file,
          status: file.status === 'pending' ? 'not_exported' : 'present_pending_validation',
          visual_review: 'pending', submission: 'not_submitted',
        });
      });
    }
  }
}
const manifest = {
  schema_version: 2,
  generated_at: new Date().toISOString(),
  purpose: 'Selected localized Sage panels export plan; presence does not mean approval or submission.',
  source: inventory('index.html'),
  selected_concept: '01',
  concepts,
  languages,
  copy: languages.map(language => ({language, ...inventory(`copy/${language}.json`)})),
  provenance: {
    rendering: 'Current native NewsBlur app in an isolated simulator demo account; app UI is not reconstructed.',
    fictional_sources: data.feeds.length,
    original_stories: data.stories.length,
    licensed_photographs: photos.length,
    demo_dataset: inventory(datasetPath, repository),
    native_harness: inventory('clients/ios/Classes/NewsBlurUITestHarness.swift', repository),
    capture_instructions: 'clients/ios/MarketingCooking/README.md',
    photography_credits_and_licenses: inventory(photoSourcesPath, repository),
    apple_license: inventory('../selected/assets/Apple-Design-Resources-License.rtf'),
    screenshot_dataset_revision: 'Capture operator must verify the dataset revision used; file presence alone does not establish it.',
  },
  render_protocol: {
    server_root: 'clients/store/artwork/ios/16.0',
    route_prefix: '/screenshots/',
    readiness_selector: 'html[data-ready="true"][data-missing-images="0"][data-font-fit="true"]',
    viewport: 'Use each export expected dimensions as the exact viewport and capture only the rendered panel at scale 1.',
    native_locale: 'English uses root captures; every other locale requires captures/localized/<language>/<device>-<view>.png. Never fall back to English.',
    encoding: 'Canonical export filenames require real PNG bytes; verify encoding before submission.',
    device_frame: 'Use raw capture at exact screen_opening below the unmodified official bezel. No added device shadow.',
    direction_07: 'Same-capture inset at 300% inset width, approximately 1.5 times the complete-device screen scale; separate by a 4% canvas-width gap. iPad crop needs review when captures arrive.',
  },
  devices: modes,
  captures,
  exports: plannedExports,
};
fs.writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({captures_present: captures.filter(x => x.status === 'captured_pending_review').length,
  captures_pending: captures.filter(x => x.status === 'pending_capture').length,
  captures_invalid: captures.filter(x => x.status === 'invalid_capture_dimensions_or_format').length,
  exports_planned: plannedExports.length, exports_present: plannedExports.filter(x => x.status !== 'not_exported').length}));
