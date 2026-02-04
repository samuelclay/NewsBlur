#!/usr/bin/env node
/**
 * Close the persistent Chrome browser
 */
import puppeteer from 'puppeteer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ENDPOINT_FILE = path.join(__dirname, '.browser-endpoint');

async function main() {
  if (!fs.existsSync(ENDPOINT_FILE)) {
    console.log('No persistent browser found.');
    process.exit(0);
  }

  const wsEndpoint = fs.readFileSync(ENDPOINT_FILE, 'utf8');
  console.log('Connecting to browser...');

  try {
    const browser = await puppeteer.connect({ browserWSEndpoint: wsEndpoint });
    await browser.close();
    fs.unlinkSync(ENDPOINT_FILE);
    console.log('✓ Browser closed successfully.');
  } catch (error) {
    console.error('Error closing browser:', error.message);
    // Clean up stale endpoint file
    if (fs.existsSync(ENDPOINT_FILE)) {
      fs.unlinkSync(ENDPOINT_FILE);
    }
  }
}

main();
