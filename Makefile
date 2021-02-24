CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

#creates newsblur, but does not rebuild images or create keys
start:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d

rebuild:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d

#creates newsblur, builds new images, and creates/refreshes SSL keys
nb:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- [[ -d config/certificates ]] && echo "keys exist" || make keys
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d --build --remove-orphans
	- cd node && npm install & cd ..
	- docker-compose exec newsblur_web ./manage.py migrate
	- docker-compose exec newsblur_web ./manage.py loaddata config/fixtures/bootstrap.json

shell:
	- - CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose exec newsblur_web ./manage.py shellplus
# allows user to exec into newsblur_web and use pdb.
debug:
	- newsblur := $(shell docker ps -qf "name=newsblur_web")
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker attach ${newsblur}

# brings down containers
nb-down:
	- docker-compose -f docker-compose.dev.yml down

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

# Lists all Digital Ocean machines
list:
	- doctl -t `cat /srv/secrets-newsblur/keys/digital_ocean.token` compute droplet list

ansible-deps:
	ansible-galaxy install -p roles -r ansible/roles/requirements.yml --roles-path ansible/roles

plan:
	terraform -chdir=terraform plan 

apply:
	terraform -chdir=terraform apply

# Docker
images:
	- docker image build . --file=docker/newsblur_base_image.Dockerfile --tag=newsblur/newsblur_python3
	- docker image build . --file=docker/node/node_base.Dockerfile --tag=newsblur/newsblur_node
	- docker push newsblur/newsblur_python3
	- docker push newsblur/newsblur_node

# Tasks
deploy:
	- ansible-playbook ansible/deploy_app.yml

firewall:
	- ansible-playbook ansible/provision.yml --tags firewall -l db

# performance tests
perf-cli:
	locust -f perf/locust.py --headless -u $(users) -r $(rate) --run-time 5m --host=$(host)

perf-ui:
	locust -f perf/locust.py

perf-docker:
	- docker build . --file=./perf/Dockerfile --tag=perf-docker
	- docker run -it -p 8089:8089 perf-docker locust -f locust.py
