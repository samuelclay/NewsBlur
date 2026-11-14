# Running mutation checks in NewsBlur

`$SKILL` is this skill's directory, `.agents/skills/deslopify-tests`.

## Where to run

Tests run inside a web container, never a local Python. Each checkout has its own: `newsblur_web` for the main repo, `newsblur_web_<worktree>` for a worktree, and each mounts its checkout at `/srv/newsblur`. A mutation is an edit to a file in the checkout, so it reaches the container that mounts that checkout and no other.

- **Review mode** runs in the checkout that holds the diff, against its container.
- **Prune mode** runs in its own worktree (`make worktree` from `.worktree/<branch>`), so the mutations never touch the main checkout. The web server in that stack reloads on every edit; that is harmless.

**One run at a time, machine-wide.** Every checkout shares one Postgres test database (`test_newsblur`) and one Mongo test database (`nb_test`). Two test runs at once, even from different worktrees, collide and the second stalls. So shards run one after another, and nothing else may run tests while a prune is going. Stop other worktree stacks, or at least confirm nobody is testing in them.

## Command

`manage.py test` writes no JUnit report, so `related_cmd` goes through `scripts/django_junit.py`, which runs the same suite through `utils/testrunner.py` inside the container and copies a report out:

```bash
python3 $SKILL/scripts/django_junit.py --container newsblur_web_<worktree> \
  --junit {junit} apps.<app>.<module> [apps.<app>.<module>.<Class> ...]
```

Run `mutate.py` from the checkout root, so the `edits` paths and the command resolve there. The report's classname is `apps.<app>.<module>.<Class>` and the name is the test method, so a candidate is `{"file": "apps/reader/test_views.py", "name": "Test_Class::test_method"}`.

`isolate_cmd` is the same command with `--exclude apps.<app>.<module>.<Class>.<test_method>` for the candidate. `mutate.py isolate-spec <shard dir>` writes those lines for results that ran without one. The wrapper keeps the test databases between runs, as CI does with `--keepdb`; tests that leave rows behind can still fail a neighbour, which is what `isolate_cmd` is for.

A `SimpleTestCase` module runs in about four seconds, most of it container start-up; modules that use the database take longer. The full `apps` suite takes 3 to 4 minutes; never use it as a `related_cmd`.

## Related tests

The candidate's module, plus the modules that import the mutated code:

```bash
git grep -l -E "from apps\.<app>\.<module> import|import apps\.<app>\.<module>" -- 'apps/**/test*.py' 'apps/**/tests.py' 'utils/**/test*.py'
```

`apps/rss_feeds/models.py`, `apps/reader/models.py`, and `utils/feed_fetcher.py` reach every app. For a mutation there, add the test modules of the apps that call the mutated function, found by grepping for its name.

## Lanes

- **Django Tests** (`tests.yml`): `python3 manage.py test apps --noinput -v 2 --failfast --keepdb` in the web container, aborted at 7 minutes. This is the lane the skill prunes. Test files are `apps/**/tests.py` and `apps/**/test_*.py`. Python tests outside `apps/` (`utils/test_*.py`, `newsblur_web/test_*.py`, `newsblur_mcp/tests/`, `clients/store/test_*.py`) are not collected by `manage.py test apps` and run in no pull-request lane: apply the bar to them and list the kept ones as "not run in CI". `localization/test_manage.py` and `localization/test_web.js` run in `localization.yml`.
- **Node tests**: `tests.yml` runs only `node --test node/tests/account_settings_save.test.js`. The other files in `node/tests/` run in no lane. `node --test --test-reporter=junit` reports no file per case, so `mutate.py` cannot match a candidate in it: prove these by hand (apply the bug, run `node --test <file>`, restore) and record the result in the ledger yourself.
- **iOS Tests** and **Android Tests** (`xcodebuild`, `:app:testDebugUnitTest`, `:app:connectedDebugAndroidTest`) need Xcode, a JDK, or an emulator and are out of scope. Never run `connectedDebugAndroidTest` on the shared emulator.

After deletions, from the worktree's container:

```bash
docker exec -t newsblur_web_<worktree> python manage.py test apps --noinput -v 1 --keepdb
docker exec -t newsblur_web_<worktree> sh -c "black --check --line-length 110 <changed .py files>; isort --check-only --profile black <changed .py files>; flake8 --max-line-length 110 --select=E9,F63,F7,F82,F821 <changed .py files>"
```

## Never deleted here

`mutate.py resolve --protect` keeps, for Sam to decide, anything whose file, class, or name touches a boundary: authentication and sessions, premium, archive, and pro gating, payments (Stripe, PayPal, App Store and Play receipts), `validate_public_url` and other SSRF checks, sharing and privacy permissions, and `apps/test_migration_safety.py`. It also keeps cases that cite a forum topic, a Sentry issue, a regression, or "Bug:". A pattern misses some: before deleting, read each remaining case's class name and docstring for the same things.

A test written to reproduce a reported bug (CLAUDE.md, Bug Fixing Workflow) is a shipped-bug lock even when it cites nothing. `git log -S '<test name>' --oneline -- <file>` shows the commit that added it; if that commit is a fix, keep the test.
