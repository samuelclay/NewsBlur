FROM       python:3.7-slim
MAINTAINER julien@rottenberg.info


WORKDIR   /srv/newsblur
ENV       PYTHONPATH=/opt/newsblur
ENV       DOCKERBUILD=True
CMD       ["gunicorn", "--bind", "0.0.0.0:8000", "newsblur.wsgi", "--env", "DJANGO_SETTINGS_MODULE=newsblur.settings"]
EXPOSE    8000

COPY      config/requirements.txt /srv/newsblur/
RUN       set -ex \
          && rundDeps=' \
                  libpq5 \
                  libjpeg62 \
                  libxslt1.1 \
                            ' \
          && buildDeps=' \
                    patch \
                    python-dev \
                    gfortran \
                    lib32ncurses5-dev  \
                    libblas-dev \
                    libffi-dev \
                    libjpeg-dev \
                    default-libmysqlclient-dev \
                    libpq-dev \
                    libreadline6-dev \
                    liblapack-dev \
                    libxml2-dev \
                    libxslt1-dev \
                    ncurses-dev \
                    zlib1g-dev \
                            ' \
            && apt-get update \
            && apt-get install -y $rundDeps $buildDeps --no-install-recommends \
            && pip install -r requirements.txt \
            && apt-get purge -y --auto-remove ${buildDeps} \
            && rm -rf /var/lib/apt/lists/*


COPY      . /srv/newsblur/
RUN       cp docker/local_settings.py .
