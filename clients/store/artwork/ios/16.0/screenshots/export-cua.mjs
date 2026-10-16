// export-cua.mjs runs only inside the approved CUA REPL with its existing tab and viewport handles.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = path.dirname(fileURLToPath(import.meta.url));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const supportedSizes = ['1320x2868', '1206x2622', '2064x2752'];
const views = ['stories', 'feeds', 'reader', 'saved'];

export async function exportScreenshots({ tab, viewport, language, sizes = supportedSizes,
  rawRoot = '/tmp/newsblur-store-screenshot-renders', baseUrl = 'http://127.0.0.1:8768/screenshots/' }) {
  if (!/^[A-Za-z-]+$/.test(language) || sizes.some(size => !supportedSizes.includes(size))) {
    throw new Error('Invalid locale or screenshot dimensions.');
  }
  const copyBytes = await fs.readFile(path.join(root, 'copy', `${language}.json`));
  const copy = JSON.parse(copyBytes);
  if (copy.language !== language) throw new Error('Locale copy mismatch.');
  const rendererHash = hash(await fs.readFile(path.join(root, 'index.html')));
  const completed = [];
  try {
    for (const size of sizes) {
      const [width, height] = size.split('x').map(Number);
      const device = size === '2064x2752' ? 'ipad' : 'iphone';
      const evidence = [];
      for (let panel = 1; panel <= 4; panel++) {
        const capture = `captures/${language === 'en' ? '' : `localized/${language}/`}${device}-${views[panel - 1]}.png`;
        const captureHash = hash(await fs.readFile(path.join(root, capture)));
        const url = new URL(baseUrl);
        url.search = new URLSearchParams({ concept: '01', device, lang: language, panel: String(panel), export: '1', size });
        await tab.goto(url.href);
        // Set dimensions on the newly navigated rendering tab, then let index.html's resize handler remeasure.
        await viewport.set({ width, height });
        // CUA can cap each locator wait at three seconds even with a longer timeout.
        // Keep the viewport intact while inspecting slow renders before another bounded wait.
        for (let attempt = 0; attempt < 4; attempt++) {
          try {
            await tab.playwright.locator('html[data-ready="true"][data-missing-images="0"][data-font-fit="true"]').waitFor({ state: 'attached', timeoutMs: 12000 });
            break;
          } catch (error) {
            const readiness = await tab.playwright.evaluate(() => ({ ...document.documentElement.dataset }));
            if (readiness.ready === 'true' && readiness.missingImages === '0' && readiness.fontFit === 'true') break;
            const resizing = readiness.error?.startsWith('Export blocked: use an exact ');
            if ((readiness.error && !resizing) || attempt === 3) throw error;
          }
        }
        const state = await tab.playwright.evaluate(() => ({
          headline: document.querySelector('.headline').textContent,
          viewport: [innerWidth, innerHeight], scale: devicePixelRatio,
          images: Array.from(document.images).map(image => ({ src: image.getAttribute('src'), width: image.naturalWidth, height: image.naturalHeight })),
        }));
        if (state.headline !== copy.headlines[panel - 1] || state.viewport[0] !== width || state.viewport[1] !== height || state.scale !== 1) {
          throw new Error('Rendered copy or viewport differs from the requested export.');
        }
        const bytes = await tab.screenshot({ fullPage: false });
        if (hash(await fs.readFile(path.join(root, capture))) !== captureHash) throw new Error('Native capture changed during export; repeat this panel.');
        if (bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255) throw new Error('CUA screenshot encoding changed; update the conversion workflow.');
        const directory = path.join(rawRoot, language, size);
        await fs.mkdir(directory, { recursive: true });
        await fs.writeFile(path.join(directory, `panel-${panel}.jpg`), bytes);
        evidence.push({ language, size, panel, captured_at: new Date().toISOString(), capture, capture_sha256: captureHash,
          renderer_sha256: rendererHash, copy_sha256: hash(copyBytes), screenshot_sha256: hash(bytes), ...state });
      }
      const destination = path.join(root, 'exports', language);
      await fs.mkdir(destination, { recursive: true });
      await fs.writeFile(path.join(destination, `render-checks-${size}.json`), JSON.stringify(evidence, null, 2) + '\n');
      completed.push({ language, size, panels: evidence.length });
    }
    return completed;
  } finally {
    await viewport.reset();
    await tab.markHandoff();
  }
}
