# NewsBlur Development Guidelines

## Python Environment
- **Always use `uv run` to execute Python scripts** - This automatically activates the virtualenv
- Example: `uv run python utils/script.py`
- Do NOT use `source ~/.virtualenvs/newsblur/bin/activate` - use `uv run` instead

## Build & Test Commands
- `make nb` - Build and start all services
- `make bounce` - Restart all containers with new images
- `make shell` - Django shell inside container
- `make debug` - Debug mode for pdb
- `make log` - View logs
- `make lint` - Run linting (isort, black, flake8)
- `make test` - Run all tests
- Run single test: `docker exec -t newsblur_web python3 manage.py test apps.path.to.test.TestClass.test_method -v 3`

Note: All docker commands must use `-t` instead of `-it` to avoid interactive mode issues when running through Claude.

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