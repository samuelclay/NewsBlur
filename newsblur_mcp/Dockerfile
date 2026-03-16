FROM python:3.12-slim

WORKDIR /srv/newsblur_mcp

COPY pyproject.toml .
COPY newsblur_mcp/ newsblur_mcp/
RUN pip install --no-cache-dir .

EXPOSE 8099

CMD ["python", "-m", "newsblur_mcp.server"]
