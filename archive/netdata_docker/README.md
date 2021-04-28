# Luzifer-Ansible / netdata

This role installs a systemd service running [netdata](https://github.com/firehol/netdata) using Docker and my [Docker image](https://hub.docker.com/r/luzifer/netdata/) for it.

## Usage

```yaml
roles:
  - role: netdata
    config:
      PUSHOVER_APP_TOKEN: 'mytoken'
      DEFAULT_RECIPIENT_PUSHOVER: 'myuser'
```

(For configuration values see the [original repositories](https://github.com/luzifer-docker/netdata) README file!)
