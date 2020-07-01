# Upgrading from Django 1.5 to 3.0

## Django 1.7

pip install -r requirements.txt
pip uninstall south
./manage.py migrate

## Django 1.8

pip install -r requirements.txt
./manage.py migrate

## Django 1.9

pip install -r requirements.txt
./manage.py migrate oauth2_provider 0001 --fake
./manage.py migrate

## Django 1.10

pip install -r requirements.txt
./manage.py migrate

## Django 1.11

pip install -r requirements.txt
./manage.py migrate

## Django 2.0 (python 3)

mkvirutalenv -p python3 newsblur3
