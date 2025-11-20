# NewsBlur Development Guidelines

## Git Worktree Development
- **Use git worktrees for parallel development**: Run `make worktree` in a worktree to start workspace-specific services
- Main repo uses standard ports (80/443), worktrees get unique ports based on directory name hash
- Run `./worktree-dev.sh` to see your workspace's assigned ports (output shows all URLs)
- Close worktree: `make worktree-close` stops containers and removes worktree if clean (no uncommitted changes)
- All worktrees share the same database services (postgres, mongo, redis, elasticsearch)

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
- Task/Celery server must be manually restarted only when working on background tasks
- Use `make` to apply migrations after git pull
- Running `make rebuild` unnecessarily rebuilds everything and wastes time

Note: All docker commands must use `-t` instead of `-it` to avoid interactive mode issues when running through Claude.

## Python Environment
- **Always run Python code and Django management commands inside the Docker container** - Use `docker exec newsblur_web bash -c "python <script>"`
- **Run Django shell commands non-interactively**: `docker exec -t newsblur_web_newsblur python manage.py shell -c "<python code>"`
- Do NOT use `uv run` or local Python environment - always use the Docker container

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

## Sentry
- **Projects**: `web`, `task`, `node`, `monitor` (auth token in `~/.sentryclirc`)
- List issues: `sentry-cli --url https://sentry.newsblur.com issues list -o newsblur -p web --status unresolved`
- Get stack trace from issue ID or URL: `curl -H "Authorization: Bearer $(grep token ~/.sentryclirc | cut -d= -f2)" "https://sentry.newsblur.com/api/0/issues/<ID>/events/latest/"`
- Extract issue ID from web URL: `https://sentry.newsblur.com/organizations/newsblur/issues/<ID>/` → use `<ID>` in API

## Browser Testing with Chrome DevTools MCP
- Local dev: `https://localhost` (when using containers directly)
- Open All Site Stories: `NEWSBLUR.reader.open_river_stories()`
- Get feed with unread stories: `NEWSBLUR.assets.feeds.find(f => f.get('nt') > 0)`
- Open feed: `NEWSBLUR.reader.open_feed(feed.get('id'))`
- Select first story: `document.querySelector('.NB-feed-story').click()`
- Open story intelligence trainer: `document.querySelector('.NB-feed-story-train').click()`
- Open feed options popover: Click `.NB-feedbar-options` element (no API)
- Get feed IDs: `NEWSBLUR.assets.feeds` is a Backbone.js collection with underscore.js operations
- Open folder: Click `.folder .folder_title` element (no API)
- **Screenshots**: Always specify `filePath: "/tmp/newsblur-screenshot.png"` to avoid permission prompts

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
