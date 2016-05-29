FROM       debian:jessie
MAINTAINER julien@rottenberg.info

RUN       apt-get update && \
          apt-get install -y locales
RUN       locale-gen en_GB.UTF-8
ENV       LANG=en_GB.UTF-8 \
          LC_CTYPE=en_GB.UTF-8

WORKDIR   /opt/newsblur

# install python
RUN       apt-get install -y python-pip python-requests-whl python-dev libxslt1-dev libxml2-dev zlib1g-dev  lib32ncurses5-dev  libjpeg-dev libpq-dev libblas-dev liblapack-dev gfortran
COPY      requirements.txt /opt/newsblur/
RUN       pip install -r requirements.txt && \
          pip install image psycopg2 numpy scipy

# encoding
RUN       echo "import sys; reload(sys); sys.setdefaultencoding('utf-8')" | tee /usr/lib/python2.7/sitecustomize.py

COPY      . /opt/newsblur/
RUN       cp docker/local_settings.py .
CMD       gunicorn_django --bind 0.0.0.0:8000
