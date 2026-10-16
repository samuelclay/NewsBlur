#!/usr/bin/env node
// render.cjs uses reviewed per-locale cuts and the matching native capture directory.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const args = process.argv.slice(2);
const locale = args[args.indexOf('--locale') + 1];
const device = args[args.indexOf('--device') + 1];
if (!args.includes('--locale') || !args.includes('--device') || !['iphone', 'ipad'].includes(device)) {
  throw Error('Usage: node render.cjs --locale en --device iphone|ipad [--execute]');
}
const languages = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../../../../../localization/languages.json')));
if (!Object.hasOwn(languages, locale)) throw Error('Unsupported locale: ' + locale);
const editPath = path.join(__dirname, 'edits', locale + '.json');
if (!fs.existsSync(editPath)) throw Error('No reviewed edit exists for ' + locale + '. Inspect its native footage and record source offsets first.');
const edit = JSON.parse(fs.readFileSync(editPath));
const cut = edit.devices[device];
if (edit.locale !== locale || !cut || cut.source_ui_locale !== locale || cut.source_intervals_reviewed !== true) {
  throw Error('Matching native-language footage and reviewed source intervals are required.');
}
const source = path.resolve(__dirname, '../screenshots/footage', locale === 'en' ? device : `localized/${locale}/${device}`, 'scroll.mp4');
if (!fs.existsSync(source)) throw Error('Native footage is missing: ' + source);
const output = path.join(__dirname, 'exports', locale, `${device}-cooking-preview.mp4`);
const command = [path.join(__dirname, 'encode.cjs'), '--device', device, '--locale', locale];
for (const key of ['feeds', 'stories', 'reader', 'saved']) command.push('--' + key, source);
command.push('--starts', cut.starts.join(','), '--durations', cut.durations.join(','), '--output', output);
if (args.includes('--execute')) command.push('--execute');
const result = spawnSync(process.execPath, command, {stdio: 'inherit'});
if (result.error || result.status !== 0) throw result.error || Error('Preview preparation failed: ' + result.status);
