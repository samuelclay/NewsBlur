# Sentry Secrets

This directory contains Sentry secrets that need to be preserved across deployments.

## Setup

1. Copy `secrets.yml.example` to `secrets.yml`:
   ```bash
   cp secrets.yml.example secrets.yml
   ```

2. Fill in your actual values in `secrets.yml`

## Files

- **secrets.yml.example** - Template showing required variables
- **secrets.yml** - Actual secrets (gitignored, never committed)

## Secret Values

### sentry_secret_key
The Sentry system secret key from `sentry/config.yml`. This is used for cryptographic signing.

To generate a new key:
```bash
docker run --rm getsentry/sentry config generate-secret-key
```

### Relay Credentials
These are from `relay/credentials.json`:
- `sentry_relay_secret_key` - Relay secret key
- `sentry_relay_public_key` - Relay public key
- `sentry_relay_id` - Relay ID (UUID)

## Extracting Current Values

If you need to extract current values from a running Sentry instance:

```bash
# Get secret key
ssh hdb-sentry "cat /srv/sentry/sentry/config.yml | grep 'system.secret-key'"

# Get relay credentials
ssh hdb-sentry "cat /srv/sentry/relay/credentials.json"
```
