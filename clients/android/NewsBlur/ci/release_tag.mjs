import { execFileSync } from 'node:child_process';
import { appendFileSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const buildFile = 'clients/android/NewsBlur/app/build.gradle.kts';
const stableVersion = /^(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?$/;
const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const versionAt = (cwd, sha) => parseVersion(git(cwd, 'show', `${sha}:${buildFile}`));
const sameVersion = (a, b) => a.name === b.name && a.code === b.code;
const commitSha = (cwd, ref) => git(cwd, 'rev-parse', '--verify', `${ref}^{commit}`);

export function parseVersion(text) {
  const names = [...text.matchAll(/^\s*versionName\s*=\s*"([^"\n]+)"\s*$/gm)];
  const codes = [...text.matchAll(/^\s*versionCode\s*=\s*([1-9]\d*)\s*$/gm)];
  if (names.length !== 1 || codes.length !== 1 || !stableVersion.test(names[0][1])) {
    throw new Error('Expected one stable numeric versionName and one positive integer versionCode');
  }
  const code = Number(codes[0][1]);
  if (!Number.isSafeInteger(code) || code > 2100000000) throw new Error('Invalid Android versionCode');
  return { name: names[0][1], code };
}

function assertIncrease(previous, current) {
  const left = previous.name.split('.').map(Number);
  const right = current.name.split('.').map(Number);
  const difference = [0, 1, 2].map(i => (right[i] ?? 0) - (left[i] ?? 0)).find(n => n !== 0) ?? 0;
  if (difference <= 0 || current.code <= previous.code) {
    throw new Error('Both versionName and versionCode must increase for a stable release');
  }
}

function assertVersionBump(cwd, sha, tag) {
  const current = versionAt(cwd, sha);
  if (tag !== `Android_${current.name}`) throw new Error('Tag does not match build versionName');
  const parents = git(cwd, 'show', '-s', '--format=%P', sha).split(' ').filter(Boolean);
  if (!parents.length) throw new Error('Release tag must target a version bump commit');
  for (const parent of parents) {
    const previous = versionAt(cwd, parent);
    if (sameVersion(previous, current)) throw new Error('Release tag must target the exact version bump commit');
    assertIncrease(previous, current);
  }
}

export function selectRelease({ cwd = process.cwd(), before, after, manual = false, mainRef = 'refs/remotes/origin/main' }) {
  after = commitSha(cwd, after);
  const current = versionAt(cwd, after);
  if (manual) {
    if (after !== commitSha(cwd, mainRef)) throw new Error('Manual backfill must inspect current main');
  } else {
    if (!before || /^0+$/.test(before)) throw new Error('Refusing initial branch push without a before commit');
    before = commitSha(cwd, before);
    try { git(cwd, 'merge-base', '--is-ancestor', before, after); }
    catch { throw new Error('Push before commit is not an ancestor; inspect force-push manually'); }
    const previous = versionAt(cwd, before);
    if (sameVersion(previous, current)) return null;
    assertIncrease(previous, current);
  }
  // release_tag.mjs follows file history so a merged release keeps its original bump SHA.
  const range = manual ? after : `${before}..${after}`;
  const commits = git(cwd, 'rev-list', '--topo-order', range, '--', buildFile).split('\n').filter(Boolean);
  for (const sha of commits) {
    if (!sameVersion(versionAt(cwd, sha), current)) continue;
    const parents = git(cwd, 'show', '-s', '--format=%P', sha).split(' ').filter(Boolean);
    if (!parents.length) continue;
    const previousVersions = parents.map(parent => versionAt(cwd, parent));
    if (previousVersions.some(previous => sameVersion(previous, current))) continue;
    for (const previous of previousVersions) assertIncrease(previous, current);
    return { sha, tag: `Android_${current.name}` };
  }
  throw new Error('Could not identify the exact stable version bump commit');
}

export function publishTag({ cwd = process.cwd(), tag, sha }) {
  if (!tag?.startsWith('Android_') || !stableVersion.test(tag.slice(8))) throw new Error('Invalid Android release tag');
  sha = commitSha(cwd, sha);
  const remote = git(cwd, 'ls-remote', 'origin', `refs/tags/${tag}`, `refs/tags/${tag}^{}`);
  const refs = remote.split('\n').filter(Boolean).map(line => line.split(/\s+/));
  const existing = refs.find(([, ref]) => ref.endsWith('^{}'))?.[0] ?? refs[0]?.[0];
  if (existing && existing !== sha) throw new Error(`${tag} is immutable and already points to ${existing}, not ${sha}`);
  assertVersionBump(cwd, sha, tag);
  if (existing) {
    console.log(`${tag} already points to ${sha}`);
    return;
  }
  // Push a commit directly to a new ref; no force option and no local tag replacement.
  git(cwd, 'push', 'origin', `${sha}:refs/tags/${tag}`);
}

function main() {
  if (process.argv[2] === 'publish') {
    publishTag({ tag: process.env.RELEASE_TAG, sha: process.env.RELEASE_SHA });
    return;
  }
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const eventName = process.env.GITHUB_EVENT_NAME;
  const ref = process.env.GITHUB_REF;
  const sha = commitSha(process.cwd(), process.env.GITHUB_SHA);
  let release = null;
  let publish = false;
  if (eventName === 'push' && ref === 'refs/heads/main') {
    release = selectRelease({ before: event.before, after: sha });
    publish = Boolean(release);
  } else if (eventName === 'workflow_dispatch') {
    if (ref !== 'refs/heads/main') throw new Error('Manual release workflow must run from main');
    if (event.inputs?.backfill_tag === 'true' || event.inputs?.backfill_tag === true) {
      release = selectRelease({ after: sha, manual: true });
      publish = true;
    }
  } else if (eventName === 'push' && ref?.startsWith('refs/tags/Android_')) {
    const tag = ref.slice('refs/tags/'.length);
    assertVersionBump(process.cwd(), sha, tag);
    git(process.cwd(), 'merge-base', '--is-ancestor', sha, 'refs/remotes/origin/main');
    release = { sha, tag };
  } else if (eventName !== 'pull_request') {
    throw new Error('Unsupported release event');
  }
  appendFileSync(process.env.GITHUB_OUTPUT, `sha=${release?.sha ?? sha}\ntag=${release?.tag ?? ''}\npublish=${publish}\n`);
  console.log(release ?? { sha, message: 'Compatibility check only; no new version bump' });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
