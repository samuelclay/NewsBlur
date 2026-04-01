FROM python:3.12-slim

WORKDIR /srv/newsblur_mcp

RUN pip install --no-cache-dir uv

ENV UV_PROJECT_ENVIRONMENT="/usr/local"

COPY pyproject.toml uv.lock README.md ./
COPY newsblur_mcp/ newsblur_mcp/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

EXPOSE 8099

CMD ["python", "-m", "newsblur_mcp"]
