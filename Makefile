newsblur := $(shell docker ps -qf "name=newsblur_web")
CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

#creates newsblur, but does not rebuild images or create keys
start:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d

#creates newsblur, builds new images, and creates/refreshes SSL keys
nb:
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose down
	- [[ -d config/certificates ]] && echo "keys exist" || rm -r config/certificates
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose up -d --build --remove-orphans
	- cd node && npm install & cd ..
	- docker-compose exec newsblur_web ./manage.py migrate
	- docker-compose exec newsblur_web ./manage.py loaddata config/fixtures/bootstrap.json

# allows user to exec into newsblur_web and use pdb.
debug:
	# run `make nb-no-build` if this doesn't work
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker attach ${newsblur}

# brings down containers
nb-down:
	- docker-compose -f docker-compose.dev.yml down

# runs tests
test:
	- docker-compose down
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} TEST=True docker-compose -f docker-compose.yml up -d newsblur_web
	- CURRENT_UID=${CURRENT_UID} CURRENT_GID=${CURRENT_GID} docker-compose exec newsblur_web ./manage.py test --settings=newsblur_web.test_settings --exclude-dir=vendor

keys:
	- rm config/certificates
	- mkdir config/certificates
	- openssl dhparam -out config/certificates/dhparam-2048.pem 2048
	- openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout config/certificates/RootCA.key -out config/certificates/RootCA.pem -subj "/C=US/CN=Example-Root-CA"
	- openssl x509 -outform pem -in config/certificates/RootCA.pem -out config/certificates/RootCA.crt
	- openssl req -new -nodes -newkey rsa:2048 -keyout config/certificates/localhost.key -out config/certificates/localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
	- openssl x509 -req -sha256 -days 1024 -in config/certificates/localhost.csr -CA config/certificates/RootCA.pem -CAkey config/certificates/RootCA.key -CAcreateserial -extfile config/domains.ext -out config/certificates/localhost.crt
	- cat config/certificates/localhost.crt config/certificates/localhost.key > config/certificates/localhost.pem
