FROM      python:3.9-slim
WORKDIR   /srv/newsblur
ENV       PYTHONPATH=/srv/newsblur
COPY      flask_monitor/requirements.txt /srv/newsblur/
RUN       set -ex \
          && rundDeps=' \
                  libpq5 \
                  libjpeg62 \
                  libxslt1.1 \
                            ' \
          && buildDeps=' \
                    patch \
                    gfortran \
                    libblas-dev \
                    libffi-dev \
                    libjpeg-dev \
                    libpq-dev \
                    libreadline6-dev \
                    liblapack-dev \
                    libxml2-dev \
                    libxslt1-dev \
                    ncurses-dev \
                    zlib1g-dev \
                            ' \
            && apt-get update \
            && apt-get install -y $rundDeps $buildDeps --no-install-recommends

# Install uv
RUN pip install uv

# Clean uv cache and any virtual environment from previous builds
RUN uv clean || true && rm -rf /venv

# Create and activate virtual environment in /venv
RUN uv venv /venv
ENV PATH="/venv/bin:$PATH"
ENV VIRTUAL_ENV="/venv"

# Install dependencies
RUN rm -rf /root/.cache/uv && \
    uv pip install -r requirements.txt

RUN       apt-get purge -y --auto-remove ${buildDeps}
RUN       rm -rf /var/lib/apt/lists/*
