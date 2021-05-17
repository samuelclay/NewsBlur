SHELL := /bin/bash
CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

.PHONY: node

#creates newsblur, but does not rebuild images or create keys
start:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d

rebuild:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d

#creates newsblur, builds new images, and creates/refreshes SSL keys
nb:
	- make pull
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- [[ -d config/certificates ]] && echo "keys exist" || make keys
	- cd node && npm install & cd ..
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d --build --remove-orphans
	- docker-compose exec newsblur_web ./manage.py migrate
	- docker-compose exec newsblur_web ./manage.py loaddata config/fixtures/bootstrap.json

shell:
	- - CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose exec newsblur_web ./manage.py shell_plus
bash:
	- - CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose exec newsblur_web bash
# allows user to exec into newsblur_web and use pdb.
debug:
	- newsblur := $(shell docker ps -qf "name=newsblur_web")
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker attach ${newsblur}
log:
	- docker-compose logs -f --tail 20 newsblur_web newsblur_node
alllogs:
	- docker-compose logs -f --tail 20
# brings down containers
down:
	- docker-compose -f docker-compose.yml down
nbdown: down

# runs tests
test:
	- python manage.py test --settings=newsblur_web.test_settings apps/analyzer
	- python manage.py test --settings=newsblur_web.test_settings apps/api
	- python manage.py test --settings=newsblur_web.test_settings apps/categories
	- python manage.py test --settings=newsblur_web.test_settings apps/feed_import
	- python manage.py test --settings=newsblur_web.test_settings apps/profile
	- python manage.py test --settings=newsblur_web.test_settings apps/push
	- python manage.py test --settings=newsblur_web.test_settings apps/reader
	- python manage.py test --settings=newsblur_web.test_settings apps/rss_feeds

	#- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} TEST=True docker-compose -f docker-compose.yml up -d newsblur_web
	#- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} DJANGO_SETTINGS_MODULE=newsblur_web.test_settings docker-compose exec newsblur_web pytest --ignore ./vendor --verbosity 3

keys:
	- mkdir config/certificates
	- openssl dhparam -out config/certificates/dhparam-2048.pem 2048
	- openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout config/certificates/RootCA.key -out config/certificates/RootCA.pem -subj "/C=US/CN=Example-Root-CA"
	- openssl x509 -outform pem -in config/certificates/RootCA.pem -out config/certificates/RootCA.crt
	- openssl req -new -nodes -newkey rsa:2048 -keyout config/certificates/localhost.key -out config/certificates/localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
	- openssl x509 -req -sha256 -days 1024 -in config/certificates/localhost.csr -CA config/certificates/RootCA.pem -CAkey config/certificates/RootCA.key -CAcreateserial -out config/certificates/localhost.crt
	- cat config/certificates/localhost.crt config/certificates/localhost.key > config/certificates/localhost.pem
	- /usr/bin/security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ./config/certificates/RootCA.crt

# Digital Ocean / Terraform
list:
	- doctl -t `cat /srv/secrets-newsblur/keys/digital_ocean.token` compute droplet list
ansible-deps:
	ansible-galaxy install -p roles -r ansible/roles/requirements.yml --roles-path ansible/roles
tfrefresh:
	terraform -chdir=terraform refresh
plan:
	terraform -chdir=terraform plan -refresh=false
apply:
	terraform -chdir=terraform apply -refresh=false
inventory:
	- ./ansible/utils/generate_inventory.py

# Docker
pull:
	- docker pull newsblur/newsblur_python3
	- docker pull newsblur/newsblur_node
	- newsblur/newsblur_monitor

build_web:
	- docker image build . --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
build_node: 
	- docker image build . --file=docker/node/Dockerfile --tag=newsblur/newsblur_node
build_monitor: 
	- docker image build . --file=docker/monitor/Dockerfile --tag=newsblur/newsblur_monitor
build: build_web build_node build_monitor
push_web: build_web
	- docker push newsblur/newsblur_python3
push_node: build_node
	- docker push newsblur/newsblur_node
push_monitor: build_monitor
	- docker push newsblur/newsblur_monitor
push_images: push_web push_node push_monitor
push: build push_images

# Tasks
deploy_web:
	- ansible-playbook ansible/deploy.yml -l app
deploy: deploy_web
app: deploy_web
web: deploy_web
deploy_static:
	- ansible-playbook ansible/deploy.yml -l app --tags static
static: deploy_static
deploy_node:
	- ansible-playbook ansible/deploy.yml -l node
node: deploy_node
deploy_task:
	- ansible-playbook ansible/deploy.yml -l task
task: deploy_task
deploy_www:
	- ansible-playbook ansible/deploy.yml -l www
www: deploy_www
deploy_work:
	- ansible-playbook ansible/deploy.yml -l work
work: deploy_work
deploy_monitor:
	- ansible-playbook ansible/deploy.yml -l db
monitor: deploy_monitor
deploy_staging:
	- ansible-playbook ansible/deploy.yml -l staging
staging: deploy_staging
celery_stop:
	- ansible-playbook ansible/deploy.yml -l task --tags stop
maintenance_on:
	- ansible-playbook ansible/deploy.yml -l web --tags maintenance_on
maintenance_off:
	- ansible-playbook ansible/deploy.yml -l web --tags maintenance_off

# Provision
firewall:
	- ansible-playbook ansible/all.yml -l db --tags firewall
oldfirewall:
	- ANSIBLE_CONFIG=/srv/newsblur/ansible.old.cfg ansible-playbook ansible/all.yml  -l db --tags firewall

# performance tests
perf-cli:
	locust -f perf/locust.py --headless -u $(users) -r $(rate) --run-time 5m --host=$(host)

perf-ui:
	locust -f perf/locust.py

perf-docker:
	- docker build . --file=./perf/Dockerfile --tag=perf-docker
	- docker run -it -p 8089:8089 perf-docker locust -f locust.py

clean:
	- find . -name \*.pyc -delete
