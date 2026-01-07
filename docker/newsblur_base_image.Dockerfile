# syntax=docker/dockerfile:1.4
FROM      python:3.9-slim
WORKDIR   /srv/newsblur
ENV       PYTHONPATH=/srv/newsblur

# System dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        # Runtime deps
        libpq5 \
        libjpeg62-turbo \
        libxslt1.1 \
        # Build deps (for pip packages with C extensions)
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
        wget curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (required for tiktoken)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Create virtual environment
RUN uv venv /venv
ENV PATH="/venv/bin:$PATH"
ENV VIRTUAL_ENV="/venv"

# Copy requirements and install with cache mount (big win for rebuilds)
COPY config/requirements.txt /srv/newsblur/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r requirements.txt
