import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { parseVersion, selectRelease, publishTag } from './release_tag.mjs';

const buildFile = 'clients/android/NewsBlur/app/build.gradle.kts';
function repository(t) {
  const cwd = mkdtempSync(join(tmpdir(), 'newsblur-release-tag-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'main');
  git('config', 'user.name', 'Release test');
  git('config', 'user.email', 'release-test@example.invalid');
  mkdirSync(join(cwd, 'clients/android/NewsBlur/app'), { recursive: true });
  function commit(version, code, note = '') {
    writeFileSync(join(cwd, buildFile), `android {\n defaultConfig {\n versionName = "${version}"\n versionCode = ${code}\n }\n}\n${note}`);
    git('add', buildFile);
    git('commit', '-m', `Version ${version} ${code} ${note}`);
    return git('rev-parse', 'HEAD');
  }
  return { cwd, git, commit };
}

test('selects the version bump rather than a later build-file edit in one push', t => {
  const r = repository(t);
  const before = r.commit('16.0.1', 293);
  const bump = r.commit('16.0.2', 294);
  const after = r.commit('16.0.2', 294, '// Dependency update\n');
  assert.deepEqual(selectRelease({ cwd: r.cwd, before, after }), { sha: bump, tag: 'Android_16.0.2' });
});

test('a later source-only push does not backfill a historical version tag', t => {
  const r = repository(t);
  const before = r.commit('16.0.2', 294);
  const after = r.commit('16.0.2', 294, '// F-Droid compatibility\n');
  assert.equal(selectRelease({ cwd: r.cwd, before, after }), null);
});

test('a merged bump tags its original commit, not the merge commit', t => {
  const r = repository(t);
  const before = r.commit('16.0.1', 293);
  r.git('checkout', '-b', 'release');
  const bump = r.commit('16.0.2', 294);
  r.git('checkout', 'main');
  r.git('merge', '--no-ff', 'release', '-m', 'Merge release');
  assert.deepEqual(selectRelease({ cwd: r.cwd, before, after: r.git('rev-parse', 'HEAD') }), { sha: bump, tag: 'Android_16.0.2' });
});

test('a batch with several bumps selects only the currently released version', t => {
  const r = repository(t);
  const before = r.commit('16.0', 292);
  r.commit('16.0.1', 293);
  const after = r.commit('16.0.2', 294);
  assert.deepEqual(selectRelease({ cwd: r.cwd, before, after }), { sha: after, tag: 'Android_16.0.2' });
});

test('rejects code reuse, code-only changes, and decreasing versions', t => {
  for (const [version, code] of [['16.0.2', 293], ['16.0.1', 294], ['15.1', 294]]) {
    const r = repository(t);
    const before = r.commit('16.0.1', 293);
    const after = r.commit(version, code);
    assert.throws(() => selectRelease({ cwd: r.cwd, before, after }), /increase|versionName/);
  }
});

test('rejects prerelease, malformed and ambiguous version declarations', () => {
  for (const text of [
    'versionName = "16.0-beta"\nversionCode = 294',
    'versionName = "16.0"\nversionCode = 0',
    'versionName = "16.0"\nversionCode = 294 + 1',
    'versionName = "16.0"\nversionName = "16.1"\nversionCode = 294',
  ]) assert.throws(() => parseVersion(text));
});

test('refuses an initial branch push or unrelated history instead of tagging old releases', t => {
  const r = repository(t);
  const after = r.commit('16.0.2', 294);
  assert.throws(() => selectRelease({ cwd: r.cwd, before: '0'.repeat(40), after }), /initial|before/);
  r.git('checkout', '--orphan', 'unrelated');
  const before = r.commit('15.1', 291);
  assert.throws(() => selectRelease({ cwd: r.cwd, before, after }), /ancestor/);
});

test('manual backfill finds the current main bump and rejects an unmerged commit', t => {
  const r = repository(t);
  r.commit('16.0.1', 293);
  const bump = r.commit('16.0.2', 294);
  const after = r.commit('16.0.2', 294, '// Later edit\n');
  assert.deepEqual(selectRelease({ cwd: r.cwd, after, manual: true, mainRef: 'main' }), { sha: bump, tag: 'Android_16.0.2' });
  r.git('checkout', '-b', 'not-main');
  const unmerged = r.commit('16.0.3', 295);
  assert.throws(() => selectRelease({ cwd: r.cwd, after: unmerged, manual: true, mainRef: 'main' }), /main/);
});

test('publishes a missing tag, accepts the same target, and refuses to move it', t => {
  const r = repository(t);
  r.commit('16.0', 292);
  const first = r.commit('16.0.1', 293);
  const second = r.commit('16.0.2', 294);
  const remote = mkdtempSync(join(tmpdir(), 'newsblur-release-remote-'));
  t.after(() => rmSync(remote, { recursive: true, force: true }));
  execFileSync('git', ['init', '--bare', remote], { stdio: 'ignore' });
  r.git('remote', 'add', 'origin', remote);
  publishTag({ cwd: r.cwd, tag: 'Android_16.0.1', sha: first });
  publishTag({ cwd: r.cwd, tag: 'Android_16.0.1', sha: first });
  assert.throws(() => publishTag({ cwd: r.cwd, tag: 'Android_16.0.1', sha: second }), /immutable/);
  assert.equal(r.git('ls-remote', 'origin', 'refs/tags/Android_16.0.1').split(/\s/)[0], first);
});

test('an existing annotated tag is accepted by its peeled commit and never rewritten', t => {
  const r = repository(t);
  r.commit('16.0.1', 293);
  const sha = r.commit('16.0.2', 294);
  const remote = mkdtempSync(join(tmpdir(), 'newsblur-release-annotated-'));
  t.after(() => rmSync(remote, { recursive: true, force: true }));
  execFileSync('git', ['init', '--bare', remote], { stdio: 'ignore' });
  r.git('remote', 'add', 'origin', remote);
  r.git('tag', '-a', 'Android_16.0.2', '-m', 'Published release');
  r.git('push', 'origin', 'refs/tags/Android_16.0.2');
  const tagObject = r.git('rev-parse', 'Android_16.0.2');
  publishTag({ cwd: r.cwd, tag: 'Android_16.0.2', sha });
  assert.equal(r.git('ls-remote', 'origin', 'refs/tags/Android_16.0.2').split(/\s/)[0], tagObject);
});

test('a transient version bump reverted within a push does not publish a release', t => {
  const r = repository(t);
  const before = r.commit('16.0.1', 293);
  r.commit('16.0.2', 294);
  const after = r.commit('16.0.1', 293);
  assert.equal(selectRelease({ cwd: r.cwd, before, after }), null);
});

test('publishing rejects mismatched names and later same-version source commits', t => {
  const r = repository(t);
  r.commit('16.0.1', 293);
  const bump = r.commit('16.0.2', 294);
  const later = r.commit('16.0.2', 294, '// Later source edit\n');
  const remote = mkdtempSync(join(tmpdir(), 'newsblur-release-validation-'));
  t.after(() => rmSync(remote, { recursive: true, force: true }));
  execFileSync('git', ['init', '--bare', remote], { stdio: 'ignore' });
  r.git('remote', 'add', 'origin', remote);
  assert.throws(() => publishTag({ cwd: r.cwd, tag: 'Android_16.0.3', sha: bump }), /versionName/);
  assert.throws(() => publishTag({ cwd: r.cwd, tag: 'Android_16.0.2', sha: later }), /bump/);
  assert.equal(r.git('ls-remote', '--tags', 'origin'), '');
});
