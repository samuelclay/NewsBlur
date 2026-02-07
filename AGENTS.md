# NewsBlur Development Guidelines

## Planning & Clarification
**IMPORTANT: Before starting any implementation or creating a plan, ask clarifying questions in chat.** The AskUserQuestion tool is not available in Codex/Claude Code, so use normal questions to understand:
- The specific goals and desired outcomes
- Edge cases and error handling preferences
- UI/UX preferences (if applicable)
- Performance or scalability requirements
- Integration points with existing code
- Testing expectations
- Any constraints or preferences I might have

**Codex: Use the `request_user_input` tool frequently throughout development - not just during planning.**
**Claude: Continue using the AskUserQuestion tool frequently throughout development - not just during planning.**

Actively interview the user at any point (especially during planning). Prefer multiple rounds of short questions.

Asking questions is encouraged and appreciated because it:
- Helps both of us think through problems more clearly
- Surfaces edge cases and requirements that might be missed
- Leads to better solutions through collaborative dialogue
- Catches misunderstandings early before code is written

Ask about:
- Clarifying requirements and desired behavior
- UI/UX preferences and design decisions
- Trade-offs between different approaches
- Edge cases and error handling
- Whether a proposed solution matches expectations
- Anything you're uncertain about

Don't assume - ask. Multiple rounds of questions are better than one large batch. Even mid-implementation, if something feels unclear or you're choosing between options, ask. The interactive back-and-forth is valuable.

## Debugging

For debugging sessions: always take a screenshot first, reproduce the issue, then form a hypothesis before changing code. Do not start editing until the root cause is identified.

## Platform-Specific Guidelines
- **iOS**: See `clients/ios/CLAUDE.md` for iOS simulator testing and development
  - **All new iOS files must be written in Swift** (not Objective-C)

## Git Worktree Development
- **Use git worktrees for parallel development**: Run `make worktree` in a worktree to start workspace-specific services
- Main repo uses standard ports (80/443), worktrees get unique ports based on directory name hash
- Run `./worktree-dev.sh` to see your workspace's assigned ports (output shows all URLs)
- Close worktree: `make worktree-close` stops containers and removes worktree if clean (no uncommitted changes)
- All worktrees share the same database services (postgres, mongo, redis, elasticsearch)

### Container Names
- **Main repo containers**: `newsblur_web`, `newsblur_celery`, `newsblur_node`, `newsblur_nginx`, `newsblur_haproxy`
- **Worktree containers**: `newsblur_web_<worktree-name>`, `newsblur_celery_<worktree-name>`, `newsblur_node_<worktree-name>`, `newsblur_nginx_<worktree-name>`, `newsblur_haproxy_<worktree-name>`
- **Find worktree containers**: `docker ps --format '{{.Names}}' | grep <worktree-name>`
- The worktree name is the directory name (e.g., `search-by-phrase` → `newsblur_web_search-by-phrase`)

## Build & Test Commands
- `make` - Smart default: starts/updates NewsBlur, applies migrations (safe to run after git pull)
- `make rebuild` - Full rebuild with all images (for Docker config changes)
- `make nb` - Fast startup without rebuild (legacy, use `make` instead)
- `make bounce` - Restart all containers with new images
- `make shell` - Django shell inside container
- `make debug` - Debug mode for pdb
- `make log` - View logs
- `make lint` - Run linting (isort, black, flake8)
- `make test` - Run all tests (defaults: SCOPE=apps, ARGS="--noinput -v 1 --failfast")
- `make test SCOPE=apps.rss_feeds ARGS="-v 2"`

**IMPORTANT: Do NOT run `make rebuild` or `make nb` during development!**
- Web and Node servers restart automatically when code changes
- Task/Celery server must be manually restarted when modifying **any** code that runs inside a Celery task — this includes the task file itself and any module it calls (e.g., scoring, summary, models). Without a restart, the worker keeps running the old code. Restart with: `docker restart newsblur_celery` (or `newsblur_celery_<worktree-name>` in worktrees)
- Use `make` to apply migrations after git pull
- Running `make rebuild` unnecessarily rebuilds everything and wastes time

Note: All docker commands must use `-t` instead of `-it` to avoid interactive mode issues when running through Claude.

## Python Environment
- **Always run Python code and Django management commands inside the Docker container**
- Do NOT use `uv run` or local Python environment - always use the Docker container
- **Main repo**: `docker exec -t newsblur_web python manage.py <command>`
- **Worktree**: `docker exec -t newsblur_web_<worktree-name> python manage.py <command>`
- Example (main): `docker exec -t newsblur_web python manage.py shell -c "<python code>"`
- Example (worktree): `docker exec -t newsblur_web_search-by-phrase python manage.py test apps`

## Deployment Commands
- `aps` - Alias for `ansible-playbook ansible/setup.yml`

## SSH Access to Servers
To SSH into NewsBlur servers non-interactively:
```bash
./utils/ssh_hz.sh -n <server-name> "<command>"
```

Example:
```bash
./utils/ssh_hz.sh -n happ-web-01 "hostname"
./utils/ssh_hz.sh -n hdb-redis-story-1 "redis-cli info stats"
```

Server names are defined in `ansible/inventories/hetzner.ini`. Common server prefixes:
- `happ-` - Application servers (web, refresh, count, push)
- `hdb-` - Database servers (redis, mongo, postgres, elasticsearch)
- `htask-` - Task/Celery workers
- `hnode-` - Node.js services (page, favicons, text, socket, images)
- `hwww` - Main web server
- `hstaging` - Staging server

## Code Style
- **Python**: 
  - Black formatter with line-length 110
  - Use isort with Black profile for imports
  - Classes use CamelCase, functions/variables use snake_case
  - Use explicit exception handling
  - Follow Django conventions for models/views

- **JavaScript**: 
  - Use snake_case for methods and variables (not camelCase)
  - Framework: Backbone.js with jQuery/Underscore.js

- **Tests**:
  - Classes prefixed with `Test_`
  - Methods prefixed with `test_`

- **Prioritize readability over performance**
- **Leave no TODOs or placeholders**
- **Always reference file names in comments**

## API Testing
- Test API endpoints: `make api URL=/reader/feeds`
- With POST data: `make api URL=/reader/river_stories ARGS="-X POST -d 'feeds[]=1&feeds[]=2&feeds[]=3'"`

## Ask AI Development
- **Restart Celery after changes**: Ask AI questions are processed asynchronously via Celery tasks. After modifying `apps/ask_ai/` (providers, tasks, models), restart celery: `docker restart newsblur_celery` (or `newsblur_celery_<worktree-name>` in worktrees)
- Provider implementations are in `apps/ask_ai/providers.py`
- **Frontend model selectors**: Search for `data-model="gemini` to find all dropdown locations
- **CSS for model pills**: Search for `NB-provider-` to find pill styles

## Sentry
- **Projects**: `web`, `task`, `node`, `monitor` (auth token in `~/.sentryclirc`)
- **Always use sentry-cli** when given a Sentry issue URL
- Extract issue ID from URL: `https://sentry.newsblur.com/organizations/newsblur/issues/1037/` → issue ID is `1037`

### Sentry CLI Commands
```bash
# List unresolved issues
sentry-cli --url https://sentry.newsblur.com issues list -o newsblur -p web --status unresolved

# Get specific issue with full details (use --log-level debug to see JSON with file/function info)
sentry-cli --url https://sentry.newsblur.com issues list -o newsblur -p web --query "issue.id:1037" --log-level debug 2>&1 | grep "body:"

# The JSON body contains: culprit (endpoint), metadata.filename, metadata.function
# Example output: "culprit":"/profile/save_ios_receipt/","metadata":{"filename":"apps/profile/models.py","function":"setup_premium_history",...}

# List issues for other projects (task, node, monitor)
sentry-cli --url https://sentry.newsblur.com issues list -o newsblur -p task --status unresolved

# Resolve an issue after fixing (use issue ID from URL)
sentry-cli --url https://sentry.newsblur.com issues resolve -o newsblur -p web -i 1037
```

### Sentry Workflow
1. Extract issue ID from URL (e.g., `.../issues/1037/` → `1037`)
2. Get issue details with `--log-level debug` to find the file and function
3. Fix the issue in code
4. Commit the fix
5. Resolve the issue with `sentry-cli issues resolve -i <issue_id>`

## Browser Testing
- Use the Chrome DevTools MCP server for browser automation and testing
- Local dev: `https://localhost` (self-signed certs are accepted by default)
- **Screenshots**: Save to `/tmp/newsblur-screenshot.png`, then use Read tool to view

### Dev Auto-Login (DEBUG mode only)
- `https://localhost/reader/dev/autologin/` - Login as default dev user (configured in `DEV_AUTOLOGIN_USERNAME`)
- `https://localhost/reader/dev/autologin/<username>/` - Login as specific user
- Add `?next=/path` to redirect after login
- Returns 403 Forbidden in production (DEBUG=False)

### Test Query Parameters
- `?test=growth` - Test growth prompts (bypasses premium check and cooldowns)
- `?test=growth1` - Test feed_added growth prompt
- `?test=growth2` - Test stories_read growth prompt

### Theme Switching
- `NEWSBLUR.reader.switch_theme('dark')` - Switch to dark mode
- `NEWSBLUR.reader.switch_theme('light')` - Switch to light mode
- `NEWSBLUR.reader.switch_theme('auto')` - Switch to auto/system theme

### Opening Modals
- `NEWSBLUR.reader.open_premium_upgrade_modal()` - Premium upgrade dialog
- `NEWSBLUR.reader.open_feedchooser_modal()` - Feed chooser (mute sites)
- `NEWSBLUR.reader.open_account_modal()` - Account settings
- `NEWSBLUR.reader.open_preferences_modal()` - Preferences
- `NEWSBLUR.reader.open_keyboard_shortcuts_modal()` - Keyboard shortcuts
- `NEWSBLUR.reader.open_goodies_modal()` - Goodies & apps
- `NEWSBLUR.reader.open_notifications_modal(feed_id)` - Notifications for feed
- `NEWSBLUR.reader.open_newsletters_modal()` - Email newsletters
- `NEWSBLUR.reader.open_organizer_modal()` - Organize feeds
- `NEWSBLUR.reader.open_trainer_modal()` - Intelligence trainer
- `NEWSBLUR.reader.open_add_feed_modal()` - Add new feed
- `NEWSBLUR.reader.open_friends_modal()` - Find friends
- `NEWSBLUR.reader.open_intro_modal()` - Intro/tutorial
- `NEWSBLUR.reader.open_feed_statistics_modal(feed_id)` - Feed statistics
- `NEWSBLUR.reader.open_feed_exception_modal(feed_id)` - Feed exceptions
- `NEWSBLUR.reader.open_mark_read_modal()` - Mark as read options
- `NEWSBLUR.reader.open_social_profile_modal(user_id)` - Social profile
- `$.modal.close()` - Close any open modal

### Feed & Story Operations
- `NEWSBLUR.reader.open_river_stories()` - Open All Site Stories
- `NEWSBLUR.reader.open_feed(feed_id)` - Open a specific feed
- `NEWSBLUR.assets.feeds.find(f => f.get('nt') > 0)` - Get feed with unread stories
- `NEWSBLUR.assets.feeds` - Backbone.js collection of all feeds

### Element Interactions
- `.NB-feed-story` - Select first story
- `.NB-feed-story-train` - Open story intelligence trainer
- `.NB-feedbar-options` - Open feed options popover
- `.folder .folder_title` - Open folder

### User State (via Django shell)
To test different subscription states, modify user profile in Django shell:
```python
docker exec -t newsblur_web_<worktree> python manage.py shell -c "
from apps.profile.models import Profile
p = Profile.objects.get(user__username='<username>')
p.is_premium = True       # Enable premium
p.is_premium_trial = True # Set as trial (False = paid)
p.is_archive = False      # Archive tier
p.is_pro = False          # Pro tier
p.premium_renewal = True  # Has active renewal
p.save()
"
```

## Server Maintenance
- **DNS/Service Discovery**: Docker containers resolve services via dnsmasq → Consul (e.g., `redis-story.service.consul`)
- **Container Names by Server Type**:
  - Web (`happ-web-*`): `newsblur_web`, `haproxy`
  - Task (`htask-celery-*`): `task-celery`, `autoheal`
  - Task (`htask-work-*`): `task-work`, `autoheal`
  - Node (`hnode-page/text/socket/favicons-*`): `node`
  - Node (`hnode-images-*`): `imageproxy`
  - Redis (`hdb-redis-{story,user,session,pubsub}-*`): `redis-story`, `redis-user`, `redis-session`, `redis-pubsub`
  - Mongo (`hdb-mongo-*`): `mongo`
  - Postgres (`hdb-postgres-*`): `postgres`
  - Nginx (`hwww`): `nginx`, `haproxy`

## Writing Emails
- Never use em dashes
- Sign off with just "Sam" (no "Best," "Thanks," or other closings before it)
- Keep it concise and direct
