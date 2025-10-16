FROM      python:3.9-slim
WORKDIR   /srv/newsblur
ENV       PYTHONPATH=/srv/newsblur
RUN       set -ex \
          && rundDeps=' \
                  libpq5 \
                  libjpeg62-turbo \
                  libxslt1.1 \
                            ' \
          && buildDeps=' \
                    patch \
                    gfortran \
                    libblas-dev \
                    libffi-dev \
                    libjpeg-dev \
                    libpq-dev \
                    libev-dev \
                    libreadline-dev \
                    liblapack-dev \
                    libxml2-dev \
                    libxslt1-dev \
                    libncurses-dev \
                    zlib1g-dev \
                    ' \
            && apt-get update || (echo "Retrying apt-get update with different DNS" && echo "nameserver 8.8.8.8" > /etc/resolv.conf && apt-get update) \
            && apt-get install -y $rundDeps $buildDeps --no-install-recommends || (echo "Retrying apt-get install with different package names" && apt-get install -y libpq5 libjpeg62-turbo libxslt1.1 patch gfortran libblas-dev libffi-dev libjpeg-dev libpq-dev libev-dev libreadline-dev liblapack-dev libxml2-dev libxslt1-dev libncurses-dev zlib1g-dev --no-install-recommends) \
            && apt-get install -y wget curl ca-certificates
COPY      config/requirements.txt /srv/newsblur/

# Install Rust (required for tiktoken)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

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
