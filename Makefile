SHELL := /bin/bash
# Use timeout on Linux and gtimeout on macOS
TIMEOUT_CMD := $(shell command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || echo timeout)
newsblur := $(shell $(TIMEOUT_CMD) 2s docker ps -qf "name=newsblur_web" 2>/dev/null || docker ps -qf "name=newsblur_web")

# Color function matching NewsBlur's logging system (utils/log.py)
# Usage: @$(call log, "~FBBlue text ~FRRed text~ST")
define log
	ESC=$$(printf '\033'); echo "$(1)" | sed \
		-e "s/~FR/$${ESC}[31m/g" \
		-e "s/~FG/$${ESC}[32m/g" \
		-e "s/~FY/$${ESC}[33m/g" \
		-e "s/~FB/$${ESC}[34m/g" \
		-e "s/~FM/$${ESC}[35m/g" \
		-e "s/~FC/$${ESC}[36m/g" \
		-e "s/~FW/$${ESC}[37m/g" \
		-e "s/~FK/$${ESC}[30m/g" \
		-e "s/~FT/$${ESC}[39m/g" \
		-e "s/~BR/$${ESC}[41m/g" \
		-e "s/~BG/$${ESC}[42m/g" \
		-e "s/~BY/$${ESC}[43m/g" \
		-e "s/~BB/$${ESC}[44m/g" \
		-e "s/~BM/$${ESC}[45m/g" \
		-e "s/~BC/$${ESC}[46m/g" \
		-e "s/~BW/$${ESC}[47m/g" \
		-e "s/~BK/$${ESC}[40m/g" \
		-e "s/~BT/$${ESC}[49m/g" \
		-e "s/~SB/$${ESC}[1m/g" \
		-e "s/~SN/$${ESC}[22m/g" \
		-e "s/~SK/$${ESC}[5m/g" \
		-e "s/~SU/$${ESC}[4m/g" \
		-e "s/~ST/$${ESC}[0m/g"
endef

.PHONY: node api

# Default target - smart setup that checks if first-time install or update
.DEFAULT_GOAL := default
default:
	@WORKSPACE_NAME=$$(basename "$$(pwd)"); \
	if [ -d ".git" ]; then \
		CONTAINER_NAME="newsblur_web"; \
		URL="https://localhost"; \
	else \
		CONTAINER_NAME="newsblur_web_$$WORKSPACE_NAME"; \
		HASH=$$(echo -n "$$WORKSPACE_NAME" | md5 | head -c 4); \
		PORT_OFFSET=$$((0x$$HASH % 900 + 100)); \
		HTTPS_PORT=$$((8443 + $$PORT_OFFSET)); \
		URL="https://localhost:$$HTTPS_PORT"; \
	fi; \
	if [ -d ".git" ] && ([ ! -d "docker/volumes/postgres" ] || [ ! -d "docker/volumes/db_mongo" ]); then \
		$(call log,~FYFirst-time setup detected. Running full installation...~ST); \
		$(MAKE) rebuild; \
	elif [ -z "$$(docker ps -q -f name=$$CONTAINER_NAME)" ]; then \
		$(call log,~FYContainers not running. Starting NewsBlur...~ST); \
		$(MAKE) nb-fast; \
	else \
		$(call log,~FGNewsBlur is already running. Applying any new migrations...~ST); \
		docker exec -t $$CONTAINER_NAME ./manage.py migrate; \
	fi; \
	echo ""; \
	$(call log,~SB~FG✓ NewsBlur is ready! Visit ~FC~SB$$URL~ST); \
	$(call log,~FCNote: You may need to type '~SB~FWthisisunsafe~SN~FC' to bypass the self-signed certificate warning.~ST)

rebuild: pull bounce migrate bootstrap collectstatic
nb-fast: pull bounce-fast migrate bootstrap collectstatic
nbfast: nb-fast
nb: nbfast

metrics:
	docker compose -f docker-compose.yml -f docker-compose.metrics.yml up -d

collectstatic: 
	rm -fr static
	docker pull newsblur/newsblur_deploy
	docker run --rm -v $(shell pwd):/srv/newsblur newsblur/newsblur_deploy

#creates newsblur, builds new images, and creates/refreshes SSL keys
bounce:
	docker compose down
	@[[ -d config/certificates ]] && $(call log,~SB~FG✓ keys exist~ST) || make keys
	docker compose up -d --build --remove-orphans

bounce-fast:
	docker compose down
	docker compose up -d --remove-orphans

bootstrap:
	docker exec newsblur_web ./manage.py loaddata config/fixtures/bootstrap.json

nbup:
	docker compose up -d --build --remove-orphans

# Git worktree development workflow
worktree:
	./worktree-dev.sh

worktree-log:
	@WORKSPACE_NAME=$$(basename "$$(pwd)"); \
	if [ -f ".worktree/docker-compose.$${WORKSPACE_NAME}.yml" ]; then \
		COMPOSE_PROJECT_NAME="$$WORKSPACE_NAME" docker compose -f ".worktree/docker-compose.$${WORKSPACE_NAME}.yml" logs -f --tail 20 newsblur_web newsblur_node task_celery; \
	else \
		echo "No worktree configuration found. Run 'make worktree' first."; \
	fi

worktree-stop:
	@WORKSPACE_NAME=$$(basename "$$(pwd)"); \
	echo "Stopping workspace: $$WORKSPACE_NAME"; \
	if [ -f ".worktree/docker-compose.$${WORKSPACE_NAME}.yml" ]; then \
		COMPOSE_PROJECT_NAME="$$WORKSPACE_NAME" docker compose -f ".worktree/docker-compose.$${WORKSPACE_NAME}.yml" down --remove-orphans 2>/dev/null || true; \
	fi; \
	echo "Removing containers for workspace: $$WORKSPACE_NAME"; \
	docker rm -f newsblur_web_$$WORKSPACE_NAME newsblur_node_$$WORKSPACE_NAME newsblur_celery_$$WORKSPACE_NAME newsblur_nginx_$$WORKSPACE_NAME newsblur_haproxy_$$WORKSPACE_NAME 2>/dev/null || true; \
	echo "✓ Stopped containers for workspace: $$WORKSPACE_NAME"

worktree-close:
	@if [ -f ".git" ]; then \
		echo "Detected git worktree"; \
		WORKSPACE_NAME=$$(basename "$$(pwd)"); \
		WORKTREE_PATH=$$(pwd); \
		MAIN_REPO=$$(git rev-parse --git-common-dir | sed 's|/\.git$$||'); \
		echo "Syncing permissions before cleanup..."; \
		$(MAKE) worktree-permissions || true; \
		echo "Stopping containers..."; \
		$(MAKE) worktree-stop; \
		if [ -z "$$(git status --porcelain)" ]; then \
			echo "Cleaning up config files..."; \
			rm -f ".worktree/docker-compose.$${WORKSPACE_NAME}.yml"; \
			rm -rf ".worktree/haproxy"; \
			rmdir .worktree 2>/dev/null || true; \
			echo "Removing files that may have root ownership..."; \
			docker run --rm -v "$$WORKTREE_PATH:/workdir" alpine rm -rf /workdir/node /workdir/docker 2>/dev/null || rm -rf node docker 2>/dev/null || true; \
			cd "$$MAIN_REPO"; \
			echo "Removing worktree: $$WORKTREE_PATH"; \
			git worktree remove "$$WORKTREE_PATH" --force; \
			echo "✓ Removed worktree. You are now in: $$MAIN_REPO"; \
		else \
			echo "⚠ Worktree has uncommitted changes. Commit or stash changes before closing."; \
			git status --short; \
		fi; \
	else \
		echo "Not in a worktree, keeping directory"; \
	fi

# Bidirectional Claude permissions sync (worktree ↔ parent)
# Only syncs permissions.allow array, merges both directions
worktree-permissions:
	@if [ ! -f ".git" ]; then \
		echo "Not in a worktree, skipping permission sync"; \
		exit 0; \
	fi; \
	PARENT="../../.claude/settings.local.json"; \
	LOCAL=".claude/settings.local.json"; \
	mkdir -p .claude; \
	if [ ! -f "$$PARENT" ] && [ ! -f "$$LOCAL" ]; then \
		exit 0; \
	fi; \
	if [ -f "$$PARENT" ] && [ ! -f "$$LOCAL" ]; then \
		cp "$$PARENT" "$$LOCAL"; \
		echo "✓ Copied permissions from parent repo"; \
		exit 0; \
	fi; \
	if [ ! -f "$$PARENT" ] && [ -f "$$LOCAL" ]; then \
		exit 0; \
	fi; \
	PARENT_PERMS=$$(jq -r '.permissions.allow[]' "$$PARENT" 2>/dev/null | sort); \
	LOCAL_PERMS=$$(jq -r '.permissions.allow[]' "$$LOCAL" 2>/dev/null | sort); \
	NEW_IN_LOCAL=$$(echo "$$LOCAL_PERMS" | grep -vxF "$$PARENT_PERMS" 2>/dev/null || true); \
	NEW_IN_PARENT=$$(echo "$$PARENT_PERMS" | grep -vxF "$$LOCAL_PERMS" 2>/dev/null || true); \
	if [ -n "$$NEW_IN_PARENT" ]; then \
		COUNT=$$(echo "$$NEW_IN_PARENT" | grep -c . || echo 0); \
		echo "Syncing $$COUNT permission(s) from parent → worktree:"; \
		echo "$$NEW_IN_PARENT" | while read perm; do [ -n "$$perm" ] && echo "  + $$perm"; done; \
		MERGED=$$(jq -s '.[0].permissions.allow = (.[0].permissions.allow + .[1].permissions.allow | unique) | .[0]' "$$LOCAL" "$$PARENT"); \
		echo "$$MERGED" > "$$LOCAL"; \
	fi; \
	if [ -n "$$NEW_IN_LOCAL" ]; then \
		COUNT=$$(echo "$$NEW_IN_LOCAL" | grep -c . || echo 0); \
		echo "Syncing $$COUNT permission(s) from worktree → parent:"; \
		echo "$$NEW_IN_LOCAL" | while read perm; do [ -n "$$perm" ] && echo "  + $$perm"; done; \
		MERGED=$$(jq -s '.[0].permissions.allow = (.[0].permissions.allow + .[1].permissions.allow | unique) | .[0]' "$$PARENT" "$$LOCAL"); \
		echo "$$MERGED" > "$$PARENT"; \
	fi; \
	if [ -z "$$NEW_IN_LOCAL" ] && [ -z "$$NEW_IN_PARENT" ]; then \
		echo "✓ Permissions already in sync"; \
	else \
		echo "✓ Permissions synced"; \
	fi

# Clean up orphaned worktree containers and directories
# Run from main repo to remove artifacts from worktrees that no longer exist
worktree-cleanup:
	@echo "Cleaning up orphaned worktree artifacts..."
	@# Stop and remove any containers from worktrees that no longer exist
	@for name in $$(docker ps -a --format '{{.Names}}' | grep -E 'newsblur_(web|node|celery|nginx|haproxy)_' | sed 's/newsblur_[^_]*_//' | sort -u); do \
		if [ ! -d ".worktree/$$name" ] || [ ! -f ".worktree/$$name/.git" ]; then \
			echo "Removing orphaned containers for: $$name"; \
			docker rm -f newsblur_web_$$name newsblur_node_$$name newsblur_celery_$$name newsblur_nginx_$$name newsblur_haproxy_$$name 2>/dev/null || true; \
		fi; \
	done
	@# Clean up orphaned directories in .worktree that aren't valid git worktrees
	@for dir in .worktree/*/; do \
		if [ -d "$$dir" ] && [ ! -f "$${dir}.git" ]; then \
			echo "Removing orphaned directory: $$dir"; \
			docker run --rm -v "$$(pwd)/$$dir:/workdir" alpine rm -rf /workdir 2>/dev/null || rm -rf "$$dir" 2>/dev/null || true; \
		fi; \
	done
	@echo "✓ Cleanup complete"

coffee:
	coffee -c -w **/*.coffee
migrations:
	docker exec -t newsblur_web ./manage.py makemigrations
makemigration: migrations
makemigrations: migrations
datamigration:
	docker exec -t newsblur_web ./manage.py makemigrations --empty $(app)
migration: migrations
migrate:
	docker exec -t newsblur_web ./manage.py migrate
shell:
	docker exec -it newsblur_web ./manage.py shell_plus
bash:
	docker exec -it newsblur_web bash
# allows user to exec into newsblur_web and use pdb.
debug:
	docker attach ${newsblur}
log:
	docker compose logs -f --tail 20 newsblur_web newsblur_node
logweb:
	docker compose logs -f --tail 20 newsblur_web newsblur_node newsblur_celery
logcelery:
	docker compose logs -f --tail 20 newsblur_celery
logtask: logcelery
logmongo:
	docker compose logs -f newsblur_db_mongo
alllogs: 
	docker compose logs -f --tail 20
logall: alllogs
mongo:
	docker exec -it newsblur_db_mongo mongo --port 29019
mongo-repair:
	@echo "Repairing MongoDB database (fixes boot loop on Apple Silicon)..."
	docker compose stop newsblur_db_mongo
	@echo "Cleaning journal and lock files..."
	rm -rf docker/volumes/db_mongo/journal/ docker/volumes/db_mongo/WiredTiger.lock docker/volumes/db_mongo/mongod.lock docker/volumes/db_mongo/WiredTigerLAS.wt
	@echo "Running MongoDB repair..."
	docker run --rm -v $(shell pwd)/docker/volumes/db_mongo:/data/db mongo:4.0 mongod --repair --dbpath /data/db --nojournal
	@echo "Fixing permissions..."
	chmod -R 755 docker/volumes/db_mongo
	@echo "Starting MongoDB..."
	docker compose up -d newsblur_db_mongo
	@echo "MongoDB repair complete! Waiting for startup..."
	@sleep 5
	@docker ps | grep newsblur_db_mongo
redis:
	docker exec -it newsblur_db_redis redis-cli -p 6579
postgres:
	docker exec -it newsblur_db_postgres psql -U newsblur
stripe:
	stripe listen --forward-to localhost/zebra/webhooks/v2/
down:
	docker compose -f docker-compose.yml -f docker-compose.metrics.yml down
stop: down
nbdown: down
jekyll:
	cd blog && JEKYLL_ENV=production bundle exec jekyll serve --config _config.yml
jekyll_drafts:
	cd blog && JEKYLL_ENV=production bundle exec jekyll serve --drafts --config _config.yml
lint:
	docker exec -t newsblur_web isort --profile black --skip-glob '*.worktree/*' --skip-glob '*/archive/*' --skip-glob '.claude/*' .
	docker exec -t newsblur_web black --line-length 110 --exclude '\.worktree/.*|.*/archive/.*|\.claude/.*' .
	docker exec -t newsblur_web flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics --exclude=venv,apps/analyzer/archive,utils/archive,vendor,.worktree,.claude
	
deps:
	docker exec -t newsblur_web pip install -U uv
	docker exec -t newsblur_web uv pip install -r requirements.txt

jekyll_build:
	cd blog && JEKYLL_ENV=production bundle exec jekyll build
	
# runs tests with pytest
# Usage: make test [SCOPE=apps] [ARGS="-v"]
SCOPE ?= apps
ARGS ?= -v --tb=short
test:
	docker compose exec -T newsblur_web pytest $(SCOPE) $(ARGS)

# runs Django tests (legacy)
# Usage: make test-django [SCOPE=apps.reader] [ARGS="--noinput -v 2"]
test-django:
	docker compose exec -T newsblur_web python3 manage.py test $(SCOPE) --noinput $(ARGS)

# runs river stories tests with query profiling
test-river:
	docker compose exec -T newsblur_web pytest apps/reader/test_river_stories.py -v

keys:
	@if [ -f "config/certificates/localhost.pem" ]; then \
		$(call log,~SB~FG✓ SSL certificates already exist~ST); \
	else \
		mkdir -p config/certificates; \
		openssl dhparam -out config/certificates/dhparam-2048.pem 2048; \
		openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout config/certificates/RootCA.key -out config/certificates/RootCA.pem -subj "/C=US/CN=Example-Root-CA"; \
		openssl x509 -outform pem -in config/certificates/RootCA.pem -out config/certificates/RootCA.crt; \
		openssl req -new -nodes -newkey rsa:2048 -keyout config/certificates/localhost.key -out config/certificates/localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost"; \
		openssl x509 -req -sha256 -days 1024 -in config/certificates/localhost.csr -CA config/certificates/RootCA.pem -CAkey config/certificates/RootCA.key -CAcreateserial -out config/certificates/localhost.crt; \
		cat config/certificates/localhost.crt config/certificates/localhost.key > config/certificates/localhost.pem; \
		if [ "$$(uname)" = "Darwin" ]; then \
			sudo /usr/bin/security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./config/certificates/RootCA.crt; \
		elif [ "$$(uname)" = "Linux" ]; then \
			$(call log,~FYInstalling certificate for Linux...~ST); \
			sudo cp ./config/certificates/RootCA.crt /usr/local/share/ca-certificates/newsblur-rootca.crt || true; \
			sudo update-ca-certificates || true; \
			$(call log,~FYCertificate installation attempted. If this fails~FB~SB you may need to manually trust the certificate.~ST); \
		else \
			$(call log,~FRUnknown OS. Please manually trust the certificate at ~SB~FW./config/certificates/RootCA.crt~ST); \
		fi; \
	fi

# Doesn't work yet
mkcert:
	mkdir config/mkcert
	docker run -v $(shell pwd)/config/mkcert:/root/.local/share/mkcert brunopadz/mkcert-docker:latest \
		/bin/sh -c "mkcert -install && \
		mkcert -cert-file /root/.local/share/mkcert/mkcert.pem \
		-key-file /root/.local/share/mkcert/mkcert.key localhost"
	cat config/mkcert/rootCA.pem config/mkcert/rootCA-key.pem > config/certificates/localhost.pem
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./config/mkcert/rootCA.pem

# Digital Ocean / Terraform
list:
	doctl -t `cat /srv/secrets-newsblur/keys/digital_ocean.token` compute droplet list
sizes:
	doctl -t `cat /srv/secrets-newsblur/keys/digital_ocean.token` compute size list
size: sizes
ratelimit:
	doctl -t `cat /srv/secrets-newsblur/keys/digital_ocean.token` account ratelimit
ansible-deps:
	ansible-galaxy install -p roles -r ansible/roles/requirements.yml --roles-path ansible/roles
tfrefresh:
	terraform -chdir=terraform refresh
plan:
	terraform -chdir=terraform plan -refresh=false
apply:
	terraform -chdir=terraform apply -refresh=false -parallelism=15
inventory:
	./ansible/utils/generate_inventory.py
oldinventory:
	OLD=1 ./ansible/utils/generate_inventory.py
hinventory:
	./ansible/utils/generate_hetzner_inventory.py
# Docker
pull:
	docker pull newsblur/newsblur_python3
	docker pull newsblur/newsblur_node
	docker pull newsblur/newsblur_monitor

local_build_web:
	# docker buildx build --load . --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
	docker build . --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3

# Ensure buildx builder exists for multi-platform builds
# The default 'docker' driver doesn't support multi-platform; we need 'docker-container'
buildx_setup:
	@if ! docker buildx inspect newsblur-builder >/dev/null 2>&1; then \
		echo "Creating buildx builder 'newsblur-builder'..."; \
		docker buildx create --name newsblur-builder --driver docker-container --use; \
		docker buildx inspect --bootstrap; \
	else \
		docker buildx use newsblur-builder; \
	fi

# Clean buildx cache (use if builds fail due to disk space)
buildx_clean:
	docker buildx prune -f

build_web: buildx_setup
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
build_node: buildx_setup
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/node/Dockerfile --tag=newsblur/newsblur_node
build_monitor: buildx_setup
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/monitor/Dockerfile --tag=newsblur/newsblur_monitor
build_deploy: buildx_setup
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/newsblur_deploy.Dockerfile --tag=newsblur/newsblur_deploy
build: build_web build_node build_monitor build_deploy
push_web: buildx_setup
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
push_node: buildx_setup
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/node/Dockerfile --tag=newsblur/newsblur_node
push_monitor: buildx_setup
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/monitor/Dockerfile --tag=newsblur/newsblur_monitor
push_deploy: buildx_setup
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/newsblur_deploy.Dockerfile --tag=newsblur/newsblur_deploy
push_images: push_web push_node push_monitor push_deploy
push: push_images

# Tasks
deploy_web:
	ansible-playbook ansible/deploy.yml -l app
deploy: deploy_web
app: deploy_web
web: deploy_web
deploy_static:
	ansible-playbook ansible/deploy.yml -l app --tags static
static: deploy_static
deploy_node:
	ansible-playbook ansible/deploy.yml -l node
node: deploy_node
deploy_task:
	ansible-playbook ansible/deploy.yml -l task
task: deploy_task
celery: deploy_task
deploy_www:
	ansible-playbook ansible/deploy.yml -l haproxy
www: deploy_www
deploy_work:
	ansible-playbook ansible/deploy.yml -l work
work: deploy_work
deploy_monitor:
	ansible-playbook ansible/deploy.yml -l db
monitor: deploy_monitor
deploy_staging:
	ansible-playbook ansible/deploy.yml -l staging
staging: deploy_staging
deploy_blog:
	ansible-playbook ansible/deploy.yml -l blogs
blog: deploy_blog
deploy_staging_static: staging_static
staging_static:
	ansible-playbook ansible/deploy.yml -l staging --tags static
test_deploy_staging:
	./utils/load_test_deploy.sh --staging
test_deploy_staging_static:
	./utils/load_test_deploy.sh --staging --static
test_deploy_app:
	./utils/load_test_deploy.sh --app
test_deploy_app_static:
	./utils/load_test_deploy.sh --app --static
test_haproxy:
	./utils/test_haproxy_toggle.sh
test_haproxy_staging:
	./utils/test_haproxy_toggle.sh --staging
celery_stop:
	ansible-playbook ansible/deploy.yml -l task --tags stop
deploy_sentry:
	ansible-playbook ansible/setup.yml -l sentry -t sentry
maintenance_on:
	ansible-playbook ansible/deploy.yml -l web --tags maintenance_on
maintenance_off:
	ansible-playbook ansible/deploy.yml -l web --tags maintenance_off
env:
	ansible-playbook ansible/setup.yml -l app,task --tags env

# Provision
firewall:
	ansible-playbook ansible/all.yml -l db --tags ufw
oldfirewall:
	ANSIBLE_CONFIG=/srv/newsblur/ansible.old.cfg ansible-playbook ansible/all.yml  -l db --tags firewall
repairmongo:
	sudo docker run -v "/srv/newsblur/docker/volumes/db_mongo:/data/db" mongo:4.0 mongod --repair --dbpath /data/db
mongodump:
	docker exec -t newsblur_db_mongo mongodump --port 29019 -d newsblur -o /data/mongodump
	cp -fr docker/volumes/db_mongo/mongodump docker/volumes/mongodump
# docker exec -t newsblur_db_mongo cp -fr /data/db/mongodump /data/mongodump
# docker exec -t newsblur_db_mongo rm -fr /data/db/
mongorestore:
	cp -fr docker/volumes/mongodump docker/volumes/db_mongo/
	docker exec -t newsblur_db_mongo mongorestore --port 29019 -d newsblur /data/db/mongodump/newsblur
pgrestore:
	docker exec -t newsblur_db_postgres bash -c "psql -U newsblur -c 'CREATE DATABASE newsblur_prod;'; pg_restore -U newsblur --role=newsblur --dbname=newsblur_prod /var/lib/postgresql/data/backup_postgresql_2023-10-10-04-00.sql.sql"
redisrestore:
	docker exec -t newsblur_db_redis bash -c "redis-cli -p 6579 --pipe < /data/backup_db_redis_user_2023-10-21-04-00.rdb.gz"
	docker exec -t newsblur_db_redis bash -c "redis-cli -p 6579 --pipe < /data/backup_db_redis_story2_2023-10-21-04-00.rdb.gz"
index_feeds:
	docker exec -t newsblur_web ./manage.py index_feeds
index_stories:
	docker exec -t newsblur_web ./manage.py index_stories -R

# performance tests
perf-cli:
	locust -f perf/locust.py --headless -u $(users) -r $(rate) --run-time 5m --host=$(host)

perf-ui:
	locust -f perf/locust.py

perf-docker:
	docker build . --file=./perf/Dockerfile --tag=perf-docker
	docker run -it -p 8089:8089 perf-docker locust -f locust.py

clean:
	find . -name \*.pyc -delete

# API testing with authenticated curl
# Usage: make api URL=/reader/feeds
# Usage: make api URL=/reader/feeds CURL_ARGS="-X POST -d 'foo=bar'"
api:
	@WORKSPACE_NAME=$$(basename "$$(pwd)"); \
	if [ -d ".git" ]; then \
		CONTAINER_NAME="newsblur_web"; \
		API_BASE_URL="https://localhost"; \
	else \
		CONTAINER_NAME="newsblur_web_$$WORKSPACE_NAME"; \
		HASH=$$(echo -n "$$WORKSPACE_NAME" | md5 | head -c 4); \
		PORT_OFFSET=$$((0x$$HASH % 900 + 100)); \
		HTTPS_PORT=$$((8443 + $$PORT_OFFSET)); \
		API_BASE_URL="https://localhost:$$HTTPS_PORT"; \
	fi; \
	if [ ! -f .dev_session ]; then \
		$(call log,~FYGenerating dev session...~ST); \
		docker exec -t $$CONTAINER_NAME ./manage.py generate_dev_session; \
	fi; \
	SESSION_ID=$$(cat .dev_session); \
	$(call log,~FCUsing container: ~SB~FW$$CONTAINER_NAME~SN~FC~SB URL: ~FW$$API_BASE_URL$(URL)~ST); \
	curl -sk -H "Cookie: newsblur_sessionid=$$SESSION_ID" $$API_BASE_URL$(URL) $(CURL_ARGS)

grafana-dashboards:
	uv run python utils/grafana_backup.py
