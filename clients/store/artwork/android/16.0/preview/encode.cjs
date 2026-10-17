#!/usr/bin/env node
// encode.cjs cuts actual Android recordings at normal speed with localized captions.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync, spawnSync } = require('node:child_process');

const args = process.argv.slice(2);
if (!args.length || args.includes('--help')) {
  console.log('Usage: node encode.cjs --locale en [--starts 0,0,0,0,0,0,0,0] [--output FILE.mp4] [--execute]');
  console.log('Requires eight real recordings: captures/footage/<locale>/<phone|tablet10>-<feeds|stories|reader|saved>.mp4. Default writes a 28-second edit plan only.');
  process.exit(0);
}
const options = {};
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--execute') options.execute = true;
  else if (/^--(locale|output|starts)$/.test(args[i]) && args[i + 1]) options[args[i].slice(2)] = args[++i];
  else throw Error('Unknown or incomplete option: ' + args[i]);
}
const root = path.resolve(__dirname, '..');
const supported = JSON.parse(fs.readFileSync(path.resolve(root, '../../../../../localization/languages.json')));
const locale = options.locale;
if (!Object.hasOwn(supported, locale || '')) throw Error('A supported --locale is required.');
const copyPath = path.join(__dirname, 'copy', locale + '.json');
const copy = JSON.parse(fs.readFileSync(copyPath));
const views = ['feeds', 'stories', 'reader', 'saved'];
const keys = [...views, 'disclosure'];
if (Object.keys(copy).sort().join() !== keys.sort().join() || keys.some(key => typeof copy[key] !== 'string' || !copy[key].trim())) throw Error('Expected five complete localized captions.');
const starts = (options.starts || '0,0,0,0,0,0,0,0').split(',').map(Number);
if (starts.length !== 8 || starts.some(start => !Number.isFinite(start) || start < 0)) throw Error('--starts requires eight nonnegative offsets.');
const output = path.resolve(options.output || path.join(__dirname, 'exports', locale, 'newsblur-android-16.0.mp4'));
if (path.extname(output) !== '.mp4' || fs.existsSync(output)) throw Error('Choose a new .mp4 output path.');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', file], { encoding: 'utf8' }));
const sceneDuration = 3.5;
const scenes = ['phone', 'tablet10'].flatMap(device => views.map(view => ({device, view})));
const inputs = scenes.map((scene, index) => {
  const file = path.join(root, 'captures', 'footage', locale, `${scene.device}-${scene.view}.mp4`);
  if (!fs.existsSync(file)) throw Error('Missing real Android recording: ' + file);
  const info = probe(file);
  const video = info.streams.find(stream => stream.codec_type === 'video');
  const duration = Number(video?.duration || info.format.duration);
  if (!video || !Number.isFinite(duration) || duration < starts[index] + sceneDuration) throw Error('Recording too short for selected interval: ' + file);
  if (Math.min(video.width, video.height) < 640 || Math.max(video.width, video.height) > 7680) throw Error('Unexpected recording dimensions: ' + file);
  if (video.tags?.rotate || video.side_data_list?.some(item => Number(item.rotation))) throw Error('Normalize recording rotation before editing: ' + file);
  if (video.nb_frames && Number(video.nb_frames) < 30) throw Error('Input is not a substantive video recording: ' + file);
  return {...scene, file, sha256: hash(file), bytes: fs.statSync(file).size, source_start: starts[index], duration: sceneDuration,
    timeline_start: index * sceneDuration, probe: info};
});
const duration = inputs.length * sceneDuration;
const copyHash = hash(copyPath);
const encoderHash = hash(__filename);
const work = path.join(path.dirname(output), path.basename(output, '.mp4') + '-edit');
fs.mkdirSync(work, {recursive: true});
// encode.cjs uses fonts verified by the iOS preview workflow, with libass complex-script shaping.
const fonts = {ar: 'Geeza Pro', he: 'Arial Hebrew', hi: 'Kohinoor Devanagari', th: 'Thonburi', ja: 'Hiragino Sans', ko: 'Apple SD Gothic Neo', 'zh-Hans': 'Heiti SC', 'zh-Hant': 'Heiti TC'};
const font = fonts[locale] || 'Helvetica Neue';
const encoding = ['ar', 'he'].includes(locale) ? -1 : 1;
const safe = text => {
  if (/[{}\\]/.test(text)) throw Error('Subtitle control syntax is not allowed in caption copy.');
  return text.replace(/\r?\n/g, '\\N');
};
const assTime = seconds => `0:00:${seconds.toFixed(2).padStart(5, '0')}`;
const srtTime = seconds => '00:00:' + String(Math.floor(seconds)).padStart(2, '0') + ',' + String(Math.round((seconds % 1) * 1000)).padStart(3, '0');
const events = inputs.map(input => `Dialogue: 0,${assTime(input.timeline_start)},${assTime(input.timeline_start + input.duration)},Title,,0,0,0,,${safe(copy[input.view])}`);
events.push(`Dialogue: 1,${assTime(21)},${assTime(duration)},Disclosure,,0,0,0,,${safe(copy.disclosure)}`);
const ass = `[Script Info]\nScriptType: v4.00+\nPlayResX: 1920\nPlayResY: 1080\nWrapStyle: 0\nScaledBorderAndShadow: yes\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Title,${font},46,&H00252C27,&H00252C27,&H00EBEDEF,&H00EBEDEF,0,0,0,0,100,100,0,0,1,0,0,8,120,120,35,${encoding}\nStyle: Disclosure,${font},30,&H005D7168,&H005D7168,&H00EBEDEF,&H00EBEDEF,0,0,0,0,100,100,0,0,1,0,0,2,130,130,28,${encoding}\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n${events.join('\n')}\n`;
fs.writeFileSync(path.join(work, 'captions.ass'), ass);
const srt = inputs.map((input, index) => `${index + 1}\n${srtTime(input.timeline_start)} --> ${srtTime(input.timeline_start + input.duration)}\n${copy[input.view]}${input.timeline_start >= 21 ? '\n' + copy.disclosure : ''}\n`).join('\n');
fs.writeFileSync(path.join(work, 'captions.srt'), srt);
const ffmpegArgs = ['-hide_banner', '-nostdin', '-n', '-filter_complex_threads', '1'];
for (const input of inputs) ffmpegArgs.push('-threads', '1', '-i', input.file);
// Fixed camera framing and real-time cuts preserve recorded motion; no still animation, speed changes, interpolation or simulated interactions.
const filters = inputs.map((input, index) => `[${index}:v]fps=30:start_time=0,trim=start=${input.source_start}:duration=${input.duration},setpts=PTS-STARTPTS,scale=1800:864:force_original_aspect_ratio=decrease:force_divisible_by=2,pad=1920:1080:(ow-iw)/2:108:color=0xdbe1d3,drawbox=x=0:y=0:w=1920:h=104:color=0xedefeb:t=fill,drawbox=x=0:y=976:w=1920:h=104:color=0xedefeb:t=fill,setsar=1,settb=AVTB[v${index}]`);
filters.push(inputs.map((_, index) => `[v${index}]`).join('') + `concat=n=${inputs.length}:v=1:a=0,ass=filename=captions.ass:shaping=complex[v]`);
ffmpegArgs.push('-filter_complex', filters.join(';'), '-map', '[v]', '-an', '-t', String(duration), '-c:v', 'libx264', '-preset', 'fast', '-threads', '2', '-profile:v', 'high', '-level:v', '4.1', '-pix_fmt', 'yuv420p', '-b:v', '8M', '-maxrate', '10M', '-bufsize', '20M', '-r', '30', '-movflags', '+faststart', '-map_metadata', '-1', output);
const planPath = path.join(work, 'render-plan.json');
const plan = {status: 'prepared_not_encoded', locale, output, source_copy: copyPath, copy_sha256: copyHash, encoder_sha256: encoderHash,
  inputs, width: 1920, height: 1080, duration, frame_rate: 30, audio: 'none', actual_app_footage_seconds: duration,
  encoder: 'ffmpeg', encoder_args: ffmpegArgs, working_directory: work, visual_review: 'required', youtube_upload: 'unverified', play_listing: 'unverified'};
const save = () => fs.writeFileSync(planPath, JSON.stringify(plan, null, 2) + '\n');
save();
console.log('Prepared ' + planPath);
if (!options.execute) {console.log('No encoding performed. Supply --execute after reviewing source intervals.'); process.exit(0);}
const result = spawnSync('ffmpeg', ffmpegArgs, {cwd: work, stdio: 'inherit'});
if (result.error || result.status !== 0) throw result.error || Error('FFmpeg failed: ' + result.status);
for (const input of inputs) if (hash(input.file) !== input.sha256) throw Error('Recording changed during encoding: ' + input.file);
if (hash(copyPath) !== copyHash || hash(__filename) !== encoderHash) throw Error('Encoder or captions changed during encoding.');
const info = probe(output);
const video = info.streams.find(stream => stream.codec_type === 'video');
const fraction = value => {const [n, d] = value.split('/').map(Number); return n / d;};
const valid = video?.codec_name === 'h264' && video.profile === 'High' && video.level === 41 && video.width === 1920 && video.height === 1080 &&
  video.pix_fmt === 'yuv420p' && Math.abs(fraction(video.avg_frame_rate) - 30) < 0.001 && Math.abs(Number(video.duration) - duration) < 0.1 &&
  Math.abs(Number(video.nb_frames) - duration * 30) <= 1 && Math.abs(Number(info.format.duration) - duration) < 0.1 &&
  !info.streams.some(stream => stream.codec_type === 'audio');
plan.status = valid ? 'encoded_technical_checks_passed' : 'encoded_technical_checks_failed';
plan.output_probe = info;
plan.output_sha256 = hash(output);
plan.output_bytes = fs.statSync(output).size;
save();
if (!valid) throw Error('Technical checks failed; inspect ' + planPath);
// Contact frames supplement full playback review, never substitute for it.
for (let index = 0; index < inputs.length; index++) {
  const at = index * sceneDuration + sceneDuration / 2;
  execFileSync('ffmpeg', ['-v', 'error', '-n', '-ss', String(at), '-i', output, '-frames:v', '1', path.join(work, `review-scene-${index + 1}.png`)]);
}
console.log('Encoded 28-second Android preview and eight review frames. Full playback, text review, YouTube settings and Play readback remain required.');
