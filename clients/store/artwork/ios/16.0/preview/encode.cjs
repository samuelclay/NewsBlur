#!/usr/bin/env node
// encode.cjs prepares a reproducible edit from real recordings; encoding is opt-in.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync, spawnSync} = require('node:child_process');
const storyboard = JSON.parse(fs.readFileSync(path.join(__dirname, 'storyboard.json')));
const args = process.argv.slice(2);
if (!args.length || args.includes('--help')) {
  console.log('Usage: node encode.cjs --device iphone|ipad --locale en --feeds VIDEO --stories VIDEO --reader VIDEO --saved VIDEO --starts 0,0,0,0 [--durations 5,5,5,5] --output FILE.mp4 [--execute]');
  console.log('Default: probe inputs and write edit plan/captions only. No encoding. Real portrait video intervals totaling 15–30 seconds are required; a zero-duration scene is omitted.');
  process.exit(0);
}
const options = {};
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--execute') options.execute = true;
  else if (args[i] === '--saved-final-frame-hold') options.saved_final_frame_hold = true;
  else {
    if (!/^--(device|locale|feeds|stories|reader|saved|starts|durations|output)$/.test(args[i]) || !args[i + 1]) throw Error('Unknown or incomplete argument: ' + args[i]);
    options[args[i].slice(2)] = args[++i];
  }
}
const device = storyboard.devices[options.device];
if (!device) throw Error('Choose --device iphone or ipad.');
const supported = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../../../../../localization/languages.json')));
if (!Object.hasOwn(supported, options.locale || '')) throw Error('A supported --locale is required.');
const copyPath = path.join(__dirname, 'copy', options.locale + '.json');
if (!fs.existsSync(copyPath)) throw Error('Reviewed caption copy is missing: ' + copyPath);
const copy = JSON.parse(fs.readFileSync(copyPath));
const keys = ['feeds', 'stories', 'reader', 'saved', 'disclosure'];
if (Object.keys(copy).sort().join() !== [...keys].sort().join() || keys.some(k => typeof copy[k] !== 'string' || !copy[k].trim())) throw Error('Caption copy must contain exactly five nonempty text fields.');
const starts = (options.starts || '0,0,0,0').split(',').map(Number);
if (starts.length !== 4 || starts.some(n => !Number.isFinite(n) || n < 0)) throw Error('--starts needs four nonnegative offsets.');
const durations = (options.durations || '5,5,5,5').split(',').map(Number);
const totalDuration = durations.reduce((a, b) => a + b, 0);
if (durations.length !== 4 || durations.some(n => !Number.isFinite(n) || (n !== 0 && n < 2)) || totalDuration < 15 || totalDuration > 30 || durations[3] < 4) throw Error('--durations needs four intervals (zero skips a scene), totaling 15–30 seconds, with at least 4 seconds for the final disclosure.');
let timeline = 0;
const editScenes = storyboard.scenes.map((scene, i) => {const edit = {...scene, source_index: i, start: timeline, duration: durations[i]}; timeline += durations[i]; return edit;}).filter(scene => scene.duration > 0);
if (!options.output || path.extname(options.output).toLowerCase() !== '.mp4') throw Error('Choose an --output ending in .mp4.');
const output = path.resolve(options.output);
if (fs.existsSync(output)) throw Error('Output already exists; choose a new file: ' + output);
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', file], {encoding: 'utf8'}));
const inputs = editScenes.map((scene, i) => {
  if (!options[scene.key]) throw Error('Missing --' + scene.key);
  const file = path.resolve(options[scene.key]);
  if (!fs.existsSync(file)) throw Error('Recording does not exist: ' + file);
  if (!/\.(mov|mp4|m4v)$/i.test(file)) throw Error('Supply an actual video recording, not a still image: ' + file);
  const info = probe(file);
  const video = info.streams.find(s => s.codec_type === 'video');
  const duration = Number(video?.duration || info.format.duration);
  const finalFrameHold = scene.key === 'saved' && options.saved_final_frame_hold;
  const finalFrameIndex = Number(video?.nb_frames) - 1;
  if (finalFrameHold && (!Number.isInteger(finalFrameIndex) || finalFrameIndex < 0)) throw Error('Final-frame hold requires an exact decoded frame count.');
  if (!video || (!finalFrameHold && !(duration >= starts[scene.source_index] + scene.duration))) throw Error('Recording is too short for selected interval: ' + file);
  if (video.width !== device.expected_raw_width || video.height !== device.expected_raw_height) throw Error('Unexpected raw recording dimensions: ' + file + ` (${video.width}x${video.height})`);
  return {scene: scene.key, file, start: starts[scene.source_index], duration: scene.duration, ...(finalFrameHold ? {final_frame_hold: true, final_frame_index: finalFrameIndex} : {}), bytes: fs.statSync(file).size, probe: info};
});
const folder = path.dirname(output);
const stem = path.basename(output, '.mp4');
const work = path.join(folder, stem + '-edit');
fs.mkdirSync(work, {recursive: true});
const fontNames = {ar: 'Geeza Pro', he: 'Arial Hebrew', hi: 'Kohinoor Devanagari', th: 'Thonburi', ja: 'Hiragino Sans', ko: 'Apple SD Gothic Neo', 'zh-Hans': 'PingFang SC', 'zh-Hant': 'PingFang TC'};
const font = fontNames[options.locale] || 'Helvetica Neue';
// encode.cjs uses libass RTL paragraph ordering and one box across shaped glyph runs.
const rtl = ['ar', 'he'].includes(options.locale);
const titleBox = rtl ? '4,0,12' : '3,12,0';
const disclosureBox = rtl ? '4,0,9' : '3,9,0';
const encoding = rtl ? -1 : 1;
const fontSize = options.device === 'ipad' ? 43 : 34;
const margin = Math.round(device.width * 0.06);
const safeText = text => {
  if (/[{}\\]/.test(text)) throw Error('ASS control syntax is not allowed in caption copy.');
  return text.replace(/\r?\n/g, '\\N');
};
const stamp = seconds => `0:00:${seconds.toFixed(2).padStart(5, '0')}`;
const events = editScenes.map(scene => `Dialogue: 0,${stamp(scene.start)},${stamp(scene.start + scene.duration)},Title,,0,0,0,,${safeText(copy[scene.key])}`);
events.push(`Dialogue: 1,${stamp(editScenes.at(-1).start)},${stamp(totalDuration)},Disclosure,,0,0,0,,${safeText(copy.disclosure)}`);
const subtitles = `[Script Info]\nScriptType: v4.00+\nPlayResX: ${device.width}\nPlayResY: ${device.height}\nWrapStyle: 0\nScaledBorderAndShadow: yes\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Title,${font},${fontSize},&H00F3F2ED,&H00F3F2ED,&H40252C27,&H40252C27,0,0,0,0,100,100,0,0,${titleBox},2,${margin},${margin},${Math.round(device.height * 0.155)},${encoding}\nStyle: Disclosure,${font},${Math.round(fontSize * 0.76)},&H00F3F2ED,&H00F3F2ED,&H40252C27,&H40252C27,0,0,0,0,100,100,0,0,${disclosureBox},2,${margin},${margin},${Math.round(device.height * 0.075)},${encoding}\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n${events.join('\n')}\n`;
fs.writeFileSync(path.join(work, 'captions.ass'), subtitles);
const ffmpegArgs = ['-hide_banner', '-nostdin', '-n', '-filter_complex_threads', '1'];
for (const input of inputs) ffmpegArgs.push('-threads', '1', '-i', input.file);
ffmpegArgs.push('-f', 'lavfi', '-t', String(totalDuration), '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000');
// encode.cjs must preserve held VFR frames: normalize the full timeline before cutting.
const filters = inputs.map((input, i) => {
  // encode.cjs holds only an explicitly reviewed final Saved frame; it invents no interaction.
  const timeline = input.final_frame_hold
    ? `select=eq(n\\,${input.final_frame_index}),setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=${input.duration},fps=30:start_time=0,trim=duration=${input.duration}`
    : `fps=30:start_time=0,trim=start=${input.start}:duration=${input.duration},setpts=PTS-STARTPTS`;
  return `[${i}:v]${timeline},scale=${device.width}:${device.height}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad=${device.width}:${device.height}:(ow-iw)/2:(oh-ih)/2:color=0xedefeb,setsar=1,settb=AVTB[v${i}]`;
});
filters.push(inputs.map((_, i) => `[v${i}]`).join('') + `concat=n=${inputs.length}:v=1:a=0,ass=filename=captions.ass:shaping=complex[v]`);
ffmpegArgs.push('-filter_complex', filters.join(';'), '-map', '[v]', '-map', `${inputs.length}:a:0`, '-t', String(totalDuration), '-c:v', 'libx264', '-preset', 'fast', '-threads', '2', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-b:v', '11M', '-maxrate', '12M', '-bufsize', '24M', '-r', '30', '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2', '-disposition:a:0', 'default', '-movflags', '+faststart', '-map_metadata', '-1', output);
const plan = {status: 'prepared_not_encoded', locale: options.locale, device: options.device, output, source_copy: copyPath, inputs, scenes: editScenes, expected: device, duration: totalDuration, encoder: 'ffmpeg', encoder_args: ffmpegArgs, working_directory: work, poster_candidate_seconds: storyboard.poster_candidate_seconds, visual_review: 'pending', submission: 'not_submitted'};
const planPath = path.join(work, 'render-plan.json');
fs.writeFileSync(planPath, JSON.stringify(plan, null, 2) + '\n');
console.log('Prepared ' + planPath);
if (!options.execute) { console.log('No encoding performed. Review intervals and captions, then pass --execute.'); process.exit(0); }
const result = spawnSync('ffmpeg', ffmpegArgs, {cwd: work, stdio: 'inherit'});
if (result.error || result.status !== 0) throw result.error || Error('FFmpeg failed with status ' + result.status);
const report = probe(output);
const video = report.streams.find(s => s.codec_type === 'video');
const audio = report.streams.find(s => s.codec_type === 'audio');
const duration = Number(report.format.duration);
const fraction = value => { const [n, d] = value.split('/').map(Number); return n / d; };
const valid = video?.codec_name === 'h264' && video.profile === 'High' && video.level <= 40 && video.width === device.width && video.height === device.height && video.pix_fmt === 'yuv420p' && Math.abs(fraction(video.avg_frame_rate) - 30) < 0.001 && Math.abs(Number(video.duration) - totalDuration) <= 0.1 && Math.abs(Number(video.nb_frames) - Math.round(totalDuration * 30)) <= 1 && Math.abs(duration - totalDuration) <= 0.1 && audio?.codec_name === 'aac' && audio.channels === 2 && Number(audio.sample_rate) === 48000 && fs.statSync(output).size < 500000000;
plan.status = valid ? 'encoded_technical_checks_passed' : 'encoded_technical_checks_failed';
plan.output_probe = report;
fs.writeFileSync(planPath, JSON.stringify(plan, null, 2) + '\n');
if (!valid) throw Error('Technical checks failed; inspect ' + planPath);
console.log('Technical checks passed. Full visual review and upload verification are still pending.');
