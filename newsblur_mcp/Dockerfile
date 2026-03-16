FROM python:3.12-slim

WORKDIR /srv/newsblur_mcp

COPY pyproject.toml .
RUN pip install --no-cache-dir .

COPY newsblur_mcp/ newsblur_mcp/

EXPOSE 8099

CMD ["python", "-m", "newsblur_mcp.server"]
