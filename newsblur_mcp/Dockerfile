FROM python:3.12-slim

WORKDIR /srv/newsblur_mcp

RUN pip install --no-cache-dir uv

COPY pyproject.toml README.md ./
COPY newsblur_mcp/ newsblur_mcp/
RUN uv pip install --system --no-cache .

EXPOSE 8099

CMD ["python", "-m", "newsblur_mcp"]
