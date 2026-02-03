#!/usr/bin/env node
/**
 * Take a screenshot
 * Usage: node screenshot.js --output screenshot.png [--url https://example.com] [--full-page true] [--selector .element] [--max-size 5] [--no-compress]
 * Supports both CSS and XPath selectors:
 *   - CSS: node screenshot.js --selector ".main-content" --output page.png
 *   - XPath: node screenshot.js --selector "//div[@class='main-content']" --output page.png
 */
import { getBrowser, getPage, closeBrowser, parseArgs, outputJSON, outputError } from './lib/browser.js';
import { parseSelector, getElement, enhanceError } from './lib/selector.js';
import fs from 'fs/promises';
import path from 'path';
import { execFileSync } from 'child_process';

/**
 * Compress image using ImageMagick if it exceeds max size
 * @param {string} filePath - Path to the image file
 * @param {number} maxSizeMB - Maximum file size in MB (default: 5)
 * @returns {Promise<{compressed: boolean, originalSize: number, finalSize: number}>}
 */
async function compressImageIfNeeded(filePath, maxSizeMB = 5) {
  const stats = await fs.stat(filePath);
  const originalSize = stats.size;
  const maxSizeBytes = maxSizeMB * 1024 * 1024;

  if (originalSize <= maxSizeBytes) {
    return { compressed: false, originalSize, finalSize: originalSize };
  }

  try {
    // Check if ImageMagick is available and determine the command name
    let magickCmd = 'magick';
    try {
      execFileSync('magick', ['-version'], { stdio: 'pipe' });
    } catch {
      try {
        execFileSync('convert', ['-version'], { stdio: 'pipe' });
        magickCmd = 'convert';
      } catch {
        console.error('Warning: ImageMagick not found. Install it to enable automatic compression.');
        return { compressed: false, originalSize, finalSize: originalSize };
      }
    }

    const ext = path.extname(filePath).toLowerCase();
    const tempPath = filePath.replace(ext, `.temp${ext}`);

    // Determine compression strategy based on file type
    // Using execFileSync with array args prevents command injection
    let compressionArgs;
    if (ext === '.png') {
      // For PNG: resize and compress with quality
      compressionArgs = [filePath, '-strip', '-resize', '90%', '-quality', '85', tempPath];
    } else if (ext === '.jpg' || ext === '.jpeg') {
      // For JPEG: compress with quality and progressive
      compressionArgs = [filePath, '-strip', '-quality', '80', '-interlace', 'Plane', tempPath];
    } else {
      // For other formats: convert to JPEG with compression
      compressionArgs = [filePath, '-strip', '-quality', '80', tempPath.replace(ext, '.jpg')];
    }

    // Try compression - execFileSync doesn't invoke shell, preventing injection
    execFileSync(magickCmd, compressionArgs, { stdio: 'pipe' });

    const compressedStats = await fs.stat(tempPath);
    const compressedSize = compressedStats.size;

    // If still too large, try more aggressive compression
    if (compressedSize > maxSizeBytes) {
      const finalPath = filePath.replace(ext, `.final${ext}`);
      let aggressiveArgs;

      if (ext === '.png') {
        aggressiveArgs = [tempPath, '-strip', '-resize', '75%', '-quality', '70', finalPath];
      } else {
        aggressiveArgs = [tempPath, '-strip', '-quality', '60', '-sampling-factor', '4:2:0', finalPath];
      }

      execFileSync(magickCmd, aggressiveArgs, { stdio: 'pipe' });
      await fs.unlink(tempPath);
      await fs.rename(finalPath, filePath);
    } else {
      await fs.rename(tempPath, filePath);
    }

    const finalStats = await fs.stat(filePath);
    return { compressed: true, originalSize, finalSize: finalStats.size };
  } catch (error) {
    console.error('Compression error:', error.message);
    // If compression fails, keep original file
    try {
      const tempPath = filePath.replace(path.extname(filePath), '.temp' + path.extname(filePath));
      await fs.unlink(tempPath).catch(() => {});
    } catch {}
    return { compressed: false, originalSize, finalSize: originalSize };
  }
}

async function screenshot() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.output) {
    outputError(new Error('--output is required'));
    return;
  }

  try {
    const browser = await getBrowser({
      headless: args.headless !== 'false'
    });

    const page = await getPage(browser);

    // Navigate if URL provided
    if (args.url) {
      await page.goto(args.url, {
        waitUntil: args['wait-until'] || 'networkidle2'
      });
    }

    const screenshotOptions = {
      path: args.output,
      type: args.format || 'png',
      fullPage: args['full-page'] === 'true'
    };

    if (args.quality) {
      screenshotOptions.quality = parseInt(args.quality);
    }

    let buffer;
    if (args.selector) {
      // Parse and validate selector
      const parsed = parseSelector(args.selector);

      // Get element based on selector type
      const element = await getElement(page, parsed);
      if (!element) {
        throw new Error(`Element not found: ${args.selector}`);
      }
      buffer = await element.screenshot(screenshotOptions);
    } else {
      buffer = await page.screenshot(screenshotOptions);
    }

    const result = {
      success: true,
      output: path.resolve(args.output),
      size: buffer.length,
      url: page.url()
    };

    // Compress image if needed (unless --no-compress flag is set)
    if (args['no-compress'] !== 'true') {
      const maxSize = args['max-size'] ? parseFloat(args['max-size']) : 5;
      const compressionResult = await compressImageIfNeeded(args.output, maxSize);

      if (compressionResult.compressed) {
        result.compressed = true;
        result.originalSize = compressionResult.originalSize;
        result.size = compressionResult.finalSize;
        result.compressionRatio = ((1 - compressionResult.finalSize / compressionResult.originalSize) * 100).toFixed(2) + '%';
      }
    }

    outputJSON(result);

    if (args.close !== 'false') {
      await closeBrowser();
    }
  } catch (error) {
    // Enhance error message if selector-related
    if (args.selector) {
      const enhanced = enhanceError(error, args.selector);
      outputError(enhanced);
    } else {
      outputError(error);
    }
    process.exit(1);
  }
}

screenshot();
