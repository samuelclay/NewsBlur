SHELL := /bin/bash
# Use timeout on Linux and gtimeout on macOS
TIMEOUT_CMD := $(shell command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || echo timeout)
newsblur := $(shell $(TIMEOUT_CMD) 2s docker ps -qf "name=newsblur_web" 2>/dev/null || docker ps -qf "name=newsblur_web")

.PHONY: node

nb: pull bounce migrate bootstrap collectstatic
nb-fast: pull bounce-fast migrate bootstrap collectstatic
nbfast: nb-fast

metrics:
	docker compose -f docker-compose.yml -f docker-compose.metrics.yml up -d

collectstatic: 
	rm -fr static
	docker pull newsblur/newsblur_deploy
	docker run --rm -v $(shell pwd):/srv/newsblur newsblur/newsblur_deploy

#creates newsblur, builds new images, and creates/refreshes SSL keys
bounce:
	docker compose down
	[[ -d config/certificates ]] && echo "keys exist" || make keys
	docker compose up -d --build --remove-orphans

bounce-fast:
	docker compose down
	docker compose up -d --remove-orphans

bootstrap:
	docker exec newsblur_web ./manage.py loaddata config/fixtures/bootstrap.json

nbup:
	docker compose up -d --build --remove-orphans
coffee:
	coffee -c -w **/*.coffee
migrations:
	docker exec -it newsblur_web ./manage.py makemigrations
makemigration: migrations
makemigrations: migrations
datamigration: 
	docker exec -it newsblur_web ./manage.py makemigrations --empty $(app)
migration: migrations
migrate:
	docker exec -it newsblur_web ./manage.py migrate
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
	docker compose logs -f --tail 20 newsblur_web newsblur_node task_celery
logcelery:
	docker compose logs -f --tail 20 task_celery
logtask: logcelery
logmongo:
	docker compose logs -f db_mongo
alllogs: 
	docker compose logs -f --tail 20
logall: alllogs
mongo:
	docker exec -it db_mongo mongo --port 29019
redis:
	docker exec -it db_redis redis-cli -p 6579
postgres:
	docker exec -it db_postgres psql -U newsblur
stripe:
	stripe listen --forward-to localhost/zebra/webhooks/v2/
down:
	docker compose -f docker-compose.yml -f docker-compose.metrics.yml down
nbdown: down
jekyll:
	cd blog && JEKYLL_ENV=production bundle exec jekyll serve --config _config.yml
jekyll_drafts:
	cd blog && JEKYLL_ENV=production bundle exec jekyll serve --drafts --config _config.yml
lint:
	docker exec -t newsblur_web isort --profile black .
	docker exec -t newsblur_web black --line-length 110 .
	docker exec -t newsblur_web flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics --exclude=venv,apps/analyzer/archive,utils/archive,vendor
	
deps:
	docker exec -t newsblur_web pip install -U uv
	docker exec -t newsblur_web uv pip install -r requirements.txt

jekyll_build:
	cd blog && JEKYLL_ENV=production bundle exec jekyll build
	
# runs tests
# Usage: make test [SCOPE=apps.reader] [ARGS="--noinput -v 2"]
SCOPE ?= apps
ARGS ?= --noinput -v 1 --failfast
test:
	docker compose exec -T newsblur_web python3 manage.py test $(SCOPE) --noinput $(ARGS)

keys:
	mkdir -p config/certificates
	openssl dhparam -out config/certificates/dhparam-2048.pem 2048
	openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout config/certificates/RootCA.key -out config/certificates/RootCA.pem -subj "/C=US/CN=Example-Root-CA"
	openssl x509 -outform pem -in config/certificates/RootCA.pem -out config/certificates/RootCA.crt
	openssl req -new -nodes -newkey rsa:2048 -keyout config/certificates/localhost.key -out config/certificates/localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost"
	openssl x509 -req -sha256 -days 1024 -in config/certificates/localhost.csr -CA config/certificates/RootCA.pem -CAkey config/certificates/RootCA.key -CAcreateserial -out config/certificates/localhost.crt
	cat config/certificates/localhost.crt config/certificates/localhost.key > config/certificates/localhost.pem
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo /usr/bin/security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./config/certificates/RootCA.crt; \
	elif [ "$$(uname)" = "Linux" ]; then \
		echo "Installing certificate for Linux..."; \
		sudo cp ./config/certificates/RootCA.crt /usr/local/share/ca-certificates/newsblur-rootca.crt || true; \
		sudo update-ca-certificates || true; \
		echo "Certificate installation attempted. If this fails, you may need to manually trust the certificate."; \
	else \
		echo "Unknown OS. Please manually trust the certificate at ./config/certificates/RootCA.crt"; \
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
build_web:
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
build_node: 
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/node/Dockerfile --tag=newsblur/newsblur_node
build_monitor: 
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/monitor/Dockerfile --tag=newsblur/newsblur_monitor
build_deploy: 
	docker buildx build . --platform linux/amd64,linux/arm64 --file=docker/newsblur_deploy.Dockerfile --tag=newsblur/newsblur_deploy
build: build_web build_node build_monitor build_deploy
push_web:
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
push_node:
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/node/Dockerfile --tag=newsblur/newsblur_node
push_monitor:
	docker buildx build . --push --platform linux/amd64,linux/arm64 --file=docker/monitor/Dockerfile --tag=newsblur/newsblur_monitor
push_deploy:
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
deploy_staging_static: staging_static
staging_static:
	ansible-playbook ansible/deploy.yml -l staging --tags static
test_deploy_staging:
	./utils/load_test_deploy.sh --staging
test_deploy_app:
	./utils/load_test_deploy.sh --app
celery_stop:
	ansible-playbook ansible/deploy.yml -l task --tags stop
sentry:
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
	docker exec -it db_mongo mongodump --port 29019 -d newsblur -o /data/mongodump
	cp -fr docker/volumes/db_mongo/mongodump docker/volumes/mongodump
# docker exec -it db_mongo cp -fr /data/db/mongodump /data/mongodump
# docker exec -it db_mongo rm -fr /data/db/
mongorestore:
	cp -fr docker/volumes/mongodump docker/volumes/db_mongo/
	docker exec -it db_mongo mongorestore --port 29019 -d newsblur /data/db/mongodump/newsblur
pgrestore:
	docker exec -it db_postgres bash -c "psql -U newsblur -c 'CREATE DATABASE newsblur_prod;'; pg_restore -U newsblur --role=newsblur --dbname=newsblur_prod /var/lib/postgresql/data/backup_postgresql_2023-10-10-04-00.sql.sql"
redisrestore:
	docker exec -it db_redis bash -c "redis-cli -p 6579 --pipe < /data/backup_db_redis_user_2023-10-21-04-00.rdb.gz"
	docker exec -it db_redis bash -c "redis-cli -p 6579 --pipe < /data/backup_db_redis_story2_2023-10-21-04-00.rdb.gz"
index_feeds:
	docker exec -it newsblur_web ./manage.py index_feeds
index_stories:
	docker exec -it newsblur_web ./manage.py index_stories -R

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


grafana-dashboards:
	uv run python utils/grafana_backup.py
