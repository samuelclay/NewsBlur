# Consul

![Molecule](https://github.com/ansible-community/ansible-consul/workflows/Molecule/badge.svg?branch=master&event=pull_request)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/ansible-community/ansible-consul.svg)](http://isitmaintained.com/project/ansible-community/ansible-consul "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/ansible-community/ansible-consul.svg)](http://isitmaintained.com/project/ansible-community/ansible-consul "Percentage of issues still open")

This Ansible role installs [Consul](https://consul.io/), including establishing a filesystem structure and server or client agent configuration with support for some common operational features.

It can also bootstrap a development or evaluation cluster of 3 server agents running in a Vagrant and VirtualBox based environment. See [README_VAGRANT.md](https://github.com/ansible-community/ansible-consul/blob/master/examples/README_VAGRANT.md) and the associated [Vagrantfile](https://github.com/ansible-community/ansible-consul/blob/master/examples/Vagrantfile) for more details.

## Role Philosophy

> “Another flaw in the human character is that everybody wants to build and nobody wants to do maintenance.”<br>
> ― Kurt Vonnegut, Hocus Pocus

Please note that the original design goal of this role was more concerned with the initial installation and bootstrapping of a Consul server cluster environment and so it does not currently concern itself (all that much) with performing ongoing maintenance of a cluster.

Many users have expressed that the Vagrant based environment makes getting a working local Consul server cluster environment up and running an easy process — so this role will target that experience as a primary motivator for existing.

If you get some mileage from it in other ways, then all the better!

## Role migration and installation
This role was originally developed by Brian Shumate and was known on Ansible Galaxy as **brianshumate.consul**. Brian asked the community to be relieved of the maintenance burden, and therefore Bas Meijer transferred the role to **ansible-community** so that a team of volunteers can maintain it. At the moment there is no membership of ansible-community on https://galaxy.ansible.com and therefore to install this role into your project you should create a file `requirements.yml` in the subdirectory `roles/` of your project with this content:

```
---
- src: https://github.com/ansible-community/ansible-consul.git
  name: ansible-consul
  scm: git
  version: master
```

This repo has tagged releases that you can use to pin the version.

Tower will install the role automatically, if you use the CLI to control ansible, then install it like:

```
ansible-galaxy install -p roles -r roles/requirements.yml
```

## Requirements

This role requires a FreeBSD, Debian, or Red Hat Enterprise Linux distribution or Windows Server 2012 R2.

The role might work with other OS distributions and versions, but is known to function well with the following software versions:

* Consul: 1.8.7
* Ansible: 2.8.2
* Alpine Linux: 3.8
* CentOS: 7
* Debian: 9
* FreeBSD: 11
* RHEL: 7
* OracleLinux: 7
* Ubuntu: 16.04
* Windows: Server 2012 R2

Note that for the "local" installation mode (the default), this role will locally download only one instance of the Consul archive, unzip it and install the resulting binary on all desired Consul hosts.

To do so requires that `unzip` is available on the Ansible control host and the role will fail if it doesn't detect `unzip` in the PATH.

## Caveats

This role does not fully support the limit option (`ansible -l`) to limit the hosts, as this will break populating required host variables. If you do use the limit option with this role, you can encounter template errors like:

```
Undefined is not JSON serializable.
```

## Role Variables

The role uses variables defined in these 3 places:

- Hosts inventory file (see `examples/vagrant_hosts` for an example)
- `vars/*.yml` (primarily OS/distributions specific variables)
- `defaults/main.yml` (everything else)

> **NOTE**: The label for servers in the hosts inventory file must be `[consul_instances]` as shown in the example. The role will not properly function if the label name is anything other value.

Many role variables can also take their values from environment variables as well; those are noted in the description where appropriate.

### `consul_version`

- Version to install
- Default value: 1.8.7

### `consul_architecture_map`

- Dictionary for translating _ansible_architecture_ values to Go architecture values
  naming convention
- Default value: dict

### `consul_architecture`

- System architecture as determined by `{{ consul_architecture_map[ansible_architecture] }}`
- Default value (determined at runtime): amd64, arm, or arm64

### `consul_os`

- Operating system name in lowercase representation
- Default value: `{{ ansible_os_family | lower }}`

### `consul_zip_url`

- Consul archive file download URL
- Default value: `https://releases.hashicorp.com/consul/{{ consul_version }}/consul_{{ consul_version }}_{{ consul_os }}_{{ consul_architecture }}.zip`

### `consul_checksum_file_url`

- Package SHA256 summaries file URL
- Default value: `https://releases.hashicorp.com/consul/{{ consul_version }}/{{ consul_version }}_SHA256SUMS`

### `consul_bin_path`

- Binary installation path
- Default Linux value: `/usr/local/bin`
- Default Windows value: `C:\ProgramData\consul\bin`

### `consul_config_path`

- Base configuration file path
- Default Linux value: `/etc/consul`
- Default Windows value: `C:\ProgramData\consul\config`

### `consul_configd_path`

- Additional configuration directory
- Default Linux value: `{{ consul_config_path }}/consul.d`
- Default Windows value: `C:\ProgramData\consul\config.d`

### `consul_data_path`

- Data directory path as defined in [data_dir or -data-dir](https://www.consul.io/docs/agent/options.html#_data_dir)
- Default Linux value: `/var/consul`
- Default Windows value: `C:\ProgramData\consul\data`

### `consul_configure_syslogd`

- Enable configuration of rsyslogd or syslog-ng on Linux. If disabled, Consul will still log to syslog if `consul_syslog_enable` is true, but the syslog daemon won't be configured to write Consul logs to their own logfile.
  - Override with `CONSUL_CONFIGURE_SYSLOGD` environment variable
- Default Linux value: *false*

### `consul_log_path`
- If `consul_syslog_enable` is false
  - Log path for use in [log_file or -log-file](https://www.consul.io/docs/agent/options.html#_log_file)
- If `consul_syslog_enable` is true
  - Log path for use in rsyslogd configuration on Linux. Ignored if `consul_configure_syslogd` is false.
- Default Linux value: `/var/log/consul`
  - Override with `CONSUL_LOG_PATH` environment variable
- Default Windows value: `C:\ProgramData\consul\log`

### `consul_log_file`

- If `consul_syslog_enable` is false
  - Log file for use in [log_file or -log-file](https://www.consul.io/docs/agent/options.html#_log_file)
- If `consul_syslog_enable` is true
  - Log file for use in rsyslogd configuration on Linux. Ignored if `consul_configure_syslogd` is false.
- Override with `CONSUL_LOG_FILE` environment variable
- Default Linux value: `consul.log`

### `consul_log_rotate_bytes`

- Log rotate bytes as defined in [log_rotate_bytes or -log-rotate-bytes](https://www.consul.io/docs/agent/options.html#_log_rotate_bytes)
  - Override with `CONSUL_LOG_ROTATE_BYTES` environment variable
- Ignored if `consul_syslog_enable` is true
- Default value: 0

### `consul_log_rotate_duration`

- Log rotate bytes as defined in [log_rotate_duration or -log-rotate-duration](https://www.consul.io/docs/agent/options.html#_log_rotate_duration)
  - Override with `CONSUL_LOG_ROTATE_DURATION` environment variable
- Ignored if `consul_syslog_enable` is true
- Default value: 24h

### `consul_log_rotate_max_files`

- Log rotate bytes as defined in [log_rotate_max_files or -log-rotate-max-files](https://www.consul.io/docs/agent/options.html#_log_rotate_max_files)
  - Override with `CONSUL_LOG_ROTATE_MAX_FILES` environment variable
- Ignored if `consul_syslog_enable` is true
- Default value: 0

### `consul_syslog_facility`

- Syslog facility as defined in [syslog_facility](https://www.consul.io/docs/agent/options.html#syslog_facility)
  - Override with `CONSUL_SYSLOG_FACILITY` environment variable
- Default Linux value: local0

### `syslog_user`

- Owner of `rsyslogd` process on Linux. `consul_log_path`'s ownership is set to this user on Linux. Ignored if `consul_configure_syslogd` is false.
  - Override with `SYSLOG_USER` environment variable
- Default Linux value: syslog

### `syslog_group`

- Group of user running `rsyslogd` process on Linux. `consul_log_path`'s group ownership is set to this group on Linux. Ignored if `consul_configure_syslogd` is false.
  - Override with `SYSLOG_GROUP` environment variable
- Default value: adm

### `consul_run_path`

- Run path for process identifier (PID) file
- Default Linux value: `/run/consul`
- Default Windows value: `C:\ProgramData\consul`

### `consul_user`

- OS user
- Default Linux value: consul
- Default Windows value: LocalSystem

### `consul_manage_user`

- Whether to create the user defined by `consul_user` or not
- Default value: true

### `consul_group`

- OS group
- Default value: bin

### `consul_manage_group`

- Whether to create the group defined by `consul_group` or not
- Default value: true

### `consul_group_name`

- Inventory group name
  - Override with `CONSUL_GROUP_NAME` environment variable
- Default value: consul_instances

### `consul_retry_interval`

- Interval for reconnection attempts to LAN servers
- Default value: 30s

### `consul_retry_interval_wan`

- Interval for reconnection attempts to WAN servers
- Default value: 30s

### `consul_retry_join_skip_hosts`

- If true, the config value for retry_join won't be populated by the default hosts servers. The value can be initialized using consul_join
- Default value: false

### `consul_retry_max`

- Max reconnection attempts to LAN servers before failing (0 = infinite)
- Default value: 0

### `consul_retry_max_wan`

- Max reconnection attempts to WAN servers before failing (0 = infinite)
- Default value: *0*

### `consul_join`

- List of LAN servers, not managed by this role, to join (IPv4 IPv6 or DNS addresses)
- Default value: []

### `consul_join_wan`

- List of WAN servers, not managed by this role, to join (IPv4 IPv6 or DNS addresses)
- Default value: []

### `consul_servers`

It's typically not necessary to manually alter this list.

- List of server nodes
- Default value: List of all nodes in `consul_group_name` with
  `consul_node_role` set to server or bootstrap

### `consul_bootstrap_expect`

- Boolean that adds bootstrap_expect value on Consul servers's config file
- Default value: false

### `consul_bootstrap_expect_value`

- Integer to define the minimum number of consul servers joined to the cluster in order to elect the leader.
- Default value: Calculated at runtime based on the number of nodes

### `consul_gather_server_facts`

This feature makes it possible to gather the `consul_advertise_address(_wan)` from servers that are currently not targeted by the playbook.

To make this possible the `delegate_facts` option is used; note that his option has been problematic.

- Gather facts from servers that are not currently targeted
- Default value: false

### `consul_datacenter`

- Datacenter label
  - Override with `CONSUL_DATACENTER` environment variable- Default value: *dc1*
- Default value: dc1

### `consul_domain`

- Consul domain name as defined in [domain or -domain](https://www.consul.io/docs/agent/options.html#_domain)
  - Override with `CONSUL_DOMAIN` environment variable
- Default value: consul

### `consul_alt_domain`

- Consul domain name as defined in [alt_domain or -alt-domain](https://www.consul.io/docs/agent/options.html#_alt_domain)
  - Override with `CONSUL_ALT_DOMAIN` environment variable
- Default value: Empty string

### `consul_node_meta`

- Consul node meta data (key-value)
- Supported in Consul version 0.7.3 or later
- Default value: *{}*
- Example:
```yaml
consul_node_meta:
    node_type: "my-custom-type"
    node_meta1: "metadata1"
    node_meta2: "metadata2"
```

### `consul_log_level`

- Log level as defined in [log_level or -log-level](https://www.consul.io/docs/agent/options.html#_log_level)
  - Override with `CONSUL_LOG_LEVEL` environment variable
- Default value: INFO

### `consul_syslog_enable`

- Log to syslog as defined in [enable_syslog or -syslog](https://www.consul.io/docs/agent/options.html#_syslog)
  - Override with `CONSUL_SYSLOG_ENABLE` environment variable
- Default Linux value: false
- Default Windows value: false

### `consul_iface`

- Consul network interface
  - Override with `CONSUL_IFACE` environment variable
- Default value: `{{ ansible_default_ipv4.interface }}`

### `consul_bind_address`

- Bind address
  - Override with `CONSUL_BIND_ADDRESS` environment variable
- Default value: default ipv4 address, or address of interface configured by
  `consul_iface`

### `consul_advertise_address`

- LAN advertise address
- Default value: `consul_bind_address`

### `consul_advertise_address_wan`

- Wan advertise address
- Default value: `consul_bind_address`

### `consul_translate_wan_address`

- Prefer a node's configured WAN address when serving DNS
- Default value: false

### `consul_advertise_addresses`

- Advanced advertise addresses settings
- Individual addresses can be overwritten using the `consul_advertise_addresses_*` variables
- Default value:
  ```yaml
  consul_advertise_addresses:
    serf_lan: "{{ consul_advertise_addresses_serf_lan | default(consul_advertise_address+':'+consul_ports.serf_lan) }}"
    serf_wan: "{{ consul_advertise_addresses_serf_wan | default(consul_advertise_address_wan+':'+consul_ports.serf_wan) }}"
    rpc: "{{ consul_advertise_addresses_rpc | default(consul_bind_address+':'+consul_ports.server) }}"
  ```

### `consul_client_address`

- Client address
- Default value: 127.0.0.1

### `consul_addresses`

- Advanced address settings
- Individual addresses kan be overwritten using the `consul_addresses_*` variables
- Default value:
  ```yaml
  consul_addresses:
    dns: "{{ consul_addresses_dns | default(consul_client_address, true) }}"
    http: "{{ consul_addresses_http | default(consul_client_address, true) }}"
    https: "{{ consul_addresses_https | default(consul_client_address, true) }}"
    rpc: "{{ consul_addresses_rpc | default(consul_client_address, true) }}"
    grpc: "{{ consul_addresses_grpc | default(consul_client_address, true) }}"
  ```

### `consul_ports`

- The official documentation on the [Ports Used](https://www.consul.io/docs/agent/options.html#ports)
- The ports mapping is a nested dict object that allows setting the bind ports for the following keys:
  - dns - The DNS server, -1 to disable. Default 8600.
  - http - The HTTP API, -1 to disable. Default 8500.
  - https - The HTTPS API, -1 to disable. Default -1 (disabled).
  - rpc - The CLI RPC endpoint. Default 8400. This is deprecated in Consul 0.8 and later.
  - grpc - The gRPC endpoint, -1 to disable. Default -1 (disabled).
  - serf_lan - The Serf LAN port. Default 8301.
  - serf_wan - The Serf WAN port. Default 8302.
  - server - Server RPC address. Default 8300.

For example, to enable the consul HTTPS API it is possible to set the variable as follows:

- Default values:
```yaml
  consul_ports:
    dns: "{{ consul_ports_dns | default('8600', true) }}"
    http: "{{ consul_ports_http | default('8500', true) }}"
    https: "{{ consul_ports_https | default('-1', true) }}"
    rpc: "{{ consul_ports_rpc | default('8400', true) }}"
    serf_lan: "{{ consul_ports_serf_lan | default('8301', true) }}"
    serf_wan: "{{ consul_ports_serf_wan | default('8302', true) }}"
    server: "{{ consul_ports_server | default('8300', true) }}"
    grpc: "{{ consul_ports_grpc | default('-1', true) }}"
```

Notice that the dict object has to use precisely the names stated in the documentation! And all ports must be specified. Overwriting one or multiple ports can be done using the `consul_ports_*` variables.

### `consul_node_name`

- Define a custom node name (should not include dots)
  See [node_name](https://www.consul.io/docs/agent/options.html#node_name)
  - The default value on Consul is the hostname of the server.
- Default value: ''

### `consul_recursors`

- List of upstream DNS servers
  See [recursors](https://www.consul.io/docs/agent/options.html#recursors)
  - Override with `CONSUL_RECURSORS` environment variable
- Default value: Empty list

### `consul_iptables_enable`

- Whether to enable iptables rules for DNS forwarding to Consul
  - Override with `CONSUL_IPTABLES_ENABLE` environment variable
- Default value: false

### `consul_acl_policy`

- Add basic ACL config file
  - Override with `CONSUL_ACL_POLICY` environment variable
- Default value: false

### `consul_acl_enable`

- Enable ACLs
  - Override with `CONSUL_ACL_ENABLE` environment variable
- Default value: false

### `consul_acl_ttl`

- TTL for ACL's
  - Override with `CONSUL_ACL_TTL` environment variable
- Default value: 30s

### `consul_acl_token_persistence`

- Define if tokens set using the API will be persisted to disk or not
  - Override with `CONSUL_ACL_TOKEN_PERSISTENCE` environment variable
- Default value: true

### `consul_acl_datacenter`

- ACL authoritative datacenter name
  - Override with `CONSUL_ACL_DATACENTER` environment variable
- Default value: dc1

### `consul_acl_down_policy`

- Default ACL down policy
  - Override with `CONSUL_ACL_DOWN_POLICY` environment variable
- Default value: allow

### `consul_acl_token`

- Default ACL token, only set if provided
  - Override with `CONSUL_ACL_TOKEN` environment variable
- Default value: ''

### `consul_acl_agent_token`

- Used for clients and servers to perform internal operations to the service catalog. See: [acl_agent_token](https://www.consul.io/docs/agent/options.html#acl_agent_token)
  - Override with `CONSUL_ACL_AGENT_TOKEN` environment variable
- Default value: ''

### `consul_acl_agent_master_token`

- A [special access token](https://www.consul.io/docs/agent/options.html#acl_agent_master_token) that has agent ACL policy write privileges on each agent where it is configured
  - Override with `CONSUL_ACL_AGENT_MASTER_TOKEN` environment variable
- Default value: ''

### `consul_acl_default_policy`

- Default ACL policy
  - Override with `CONSUL_ACL_DEFAULT_POLICY` environment variable
- Default value: allow

### `consul_acl_master_token`

- ACL master token
  - Override with `CONSUL_ACL_MASTER_TOKEN` environment variable
- Default value: UUID

### `consul_acl_master_token_display`

- Display generated ACL Master Token
  - Override with `CONSUL_ACL_MASTER_TOKEN_DISPLAY` environment variable
- Default value: false

### `consul_acl_replication_enable`

- Enable ACL replication without token (makes it possible to set the token
  trough the API)
  - Override with `CONSUL_ACL_REPLICATION_TOKEN_ENABLE` environment variable
- Default value: ''

### `consul_acl_replication_token`

- ACL replication token
  - Override with `CONSUL_ACL_REPLICATION_TOKEN_DISPLAY` environment variable
- Default value: *SN4K3OILSN4K3OILSN4K3OILSN4K3OIL*

### `consul_tls_enable`

- Enable TLS
  - Override with `CONSUL_ACL_TLS_ENABLE` environment variable
- Default value: false

### `consul_src_def`

- Default source directory for TLS files
  - Override with `CONSUL_ACL_TLS_ENABLE` environment variable
- Default value: `{{ role_path }}/files`

### `consul_tls_src_files`

- User-specified source directory for TLS files
  - Override with `CONSUL_TLS_SRC_FILES` environment variable
- Default value: `{{ role_path }}/files`

### `consul_tls_dir`

- Target directory for TLS files
  - Override with `CONSUL_TLS_DIR` environment variable
- Default value: `/etc/consul/ssl`

### `consul_tls_ca_crt`

- CA certificate filename
  - Override with `CONSUL_TLS_CA_CRT` environment variable
- Default value: `ca.crt`

### `consul_tls_server_crt`

- Server certificate
  - Override with `CONSUL_TLS_SERVER_CRT` environment variable
- Default value: `server.crt`

### `consul_tls_server_key`

- Server key
  - Override with `CONSUL_TLS_SERVER_KEY` environment variable
- Default value: `server.key`

### `consul_tls_files_remote_src`

- Copy from remote source if TLS files are already on host
- Default value: false

### `consul_encrypt_enable`

- Enable Gossip Encryption
- Default value: true

### `consul_encrypt_verify_incoming`

- Verify incoming Gossip connections
- Default value: true

### `consul_encrypt_verify_outgoing`

- Verify outgoing Gossip connections
- Default value: true

### `consul_disable_keyring_file`

- If set, the keyring will not be persisted to a file. Any installed keys will be lost on shutdown, and only the given -encrypt key will be available on startup.
- Default value: false

### `consul_raw_key`

- Set the encryption key; should be the same across a cluster. If not present the key will be generated & retrieved from the bootstrapped server.
- Default value: ''

### `consul_tls_verify_incoming`

- Verify incoming connections
  - Override with `CONSUL_TLS_VERIFY_INCOMING` environment variable
- Default value: false

### `consul_tls_verify_outgoing`

- Verify outgoing connections
  - Override with `CONSUL_TLS_VERIFY_OUTGOING` environment variable
- Default value: true

### `consul_tls_verify_incoming_rpc`
- Verify incoming connections on RPC endpoints (client certificates)
  - Override with `CONSUL_TLS_VERIFY_INCOMING_RPC` environment variable
- Default value: false

### `consul_tls_verify_incoming_https`
- Verify incoming connections on HTTPS endpoints (client certificates)
  - Override with `CONSUL_TLS_VERIFY_INCOMING_HTTPS` environment variable
- Default value: false

### `consul_tls_verify_server_hostname`

- Verify server hostname
  - Override with `CONSUL_TLS_VERIFY_SERVER_HOSTNAME` environment variable
- Default value: false

### `consul_tls_min_version`

- [Minimum acceptable TLS version](https://www.consul.io/docs/agent/options.html#tls_min_version)
  - Can be overridden with `CONSUL_TLS_MIN_VERSION` environment variable
- Default value: tls12

### `consul_tls_cipher_suites`

- [Comma-separated list of supported ciphersuites](https://www.consul.io/docs/agent/options.html#tls_cipher_suites)
- Default value: ""

### `consul_tls_prefer_server_cipher_suites`

- [Prefer server's cipher suite over client cipher suite](https://www.consul.io/docs/agent/options.html#tls_prefer_server_cipher_suites)
  - Can be overridden with `CONSUL_TLS_PREFER_SERVER_CIPHER_SUITES` environment variable
- Default value: false

### `auto_encrypt`
- [Auto encrypt](https://www.consul.io/docs/agent/options#auto_encrypt)
- Default value:
```yaml
auto_encrypt:
  enabled: false
```
- Example:

```yaml
auto_encrypt:
  enabled: true
  dns_san: ["consul.com"]
  ip_san: ["127.0.0.1"]
```

### `consul_install_remotely`

- Whether to download the files for installation directly on the remote hosts
- This is the only option on Windows as WinRM is somewhat limited in this scope
- Default value: false

### `consul_install_upgrade`

- Whether to [upgrade consul](https://www.consul.io/docs/upgrading.html) when a new version is specified
- The role does not handle the orchestration of a rolling update of servers followed by client nodes
- This option is not available for Windows, yet. (PR welcome)
- Default value: false

### `consul_ui`

- Enable the consul ui?
- Default value: true

### `consul_ui_legacy`

- Enable legacy consul ui mode
- Default value: false

### `consul_disable_update_check`

- Disable the consul update check?
- Default value: false

### `consul_enable_script_checks`

- Enable script based checks?
- Default value: false
- This is discouraged in favor of `consul_enable_local_script_checks`.

### `consul_enable_local_script_checks`

- Enable locally defined script checks?
- Default value: false

### `consul_raft_protocol`

- Raft protocol to use.
- Default value:
  - Consul versions <= 0.7.0: 1
  - Consul versions > 0.7.0: 3

### `consul_node_role`

- The Consul role of the node, one of: *bootstrap*, *server*, or *client*
- Default value: client

One server should be designated as the bootstrap server, and the other
servers will connect to this server. You can also specify *client* as the
role, and Consul will be configured as a client agent instead of a server.

There are two methods to setup a cluster, the first one is to explicitly choose the bootstrap server, the other one is to let the servers elect a leader among
themselves.

Here is an example of how the hosts inventory could be defined for a simple
cluster of 3 servers, the first one being the designated bootstrap / leader:

```yaml
[consul_instances]
consul1.consul consul_node_role=bootstrap
consul2.consul consul_node_role=server
consul3.consul consul_node_role=server
consul4.local consul_node_role=client
```

Or you can use the simpler method of letting them do their election process:

```yaml
[consul_instances]
consul1.consul consul_node_role=server consul_bootstrap_expect=true
consul2.consul consul_node_role=server consul_bootstrap_expect=true
consul3.consul consul_node_role=server consul_bootstrap_expect=true
consul4.local consul_node_role=client
```

> Note that this second form is the preferred one, because it is simpler.

### `consul_autopilot_enable`

Autopilot is a set of new features added in Consul 0.8 to allow for automatic operator-friendly management of Consul servers. It includes cleanup of dead servers, monitoring the state of the Raft cluster, and stable server introduction.

https://www.consul.io/docs/guides/autopilot.html

- Enable Autopilot config (will be written to bootsrapper node)
  - Override with `CONSUL_AUTOPILOT_ENABLE` environment variable
- Default value: false

#### `consul_autopilot_cleanup_dead_Servers`

Dead servers will periodically be cleaned up and removed from the Raft peer set, to prevent them from interfering with the quorum size and leader elections. This cleanup will also happen whenever a new server is successfully added to the cluster.

- Enable Autopilot config (will be written to bootsrapper node)
  - Override with `CONSUL_AUTOPILOT_CLEANUP_DEAD_SERVERS` environment variable
- Default value: false

#### `consul_autopilot_last_contact_threshold`

Used in the serf health check to determine node health.

- Sets the threshold for time since last contact
  - Override with `CONSUL_AUTOPILOT_LAST_CONTACT_THRESHOLD` environment variable
- Default value: 200ms

#### `consul_autopilot_max_trailing_logs`

- Used in the serf health check to set a max-number of log entries nodes can trail the leader
  - Override with `CONSUL_AUTOPILOT_MAX_TRAILING_LOGS` environment variable
- Default value: 250


#### `consul_autopilot_server_stabilization_time`

- Time to allow a new node to stabilize
  - Override with `CONSUL_AUTOPILOT_SERVER_STABILIZATION_TIME` environment variable
- Default value: 10s

#### `consul_autopilot_redundancy_zone_tag`

_Consul Enterprise Only (requires that CONSUL_ENTERPRISE is set to true)_

- Override with `CONSUL_AUTOPILOT_REDUNDANCY_ZONE_TAG` environment variable
- Default value: az

#### `consul_autopilot_disable_upgrade_migration`

_Consul Enterprise Only (requires that CONSUL_ENTERPRISE is set to true)_

- Override with `CONSUL_AUTOPILOT_DISABLE_UPGRADE_MIGRATION` environment variable
- Default value: *false*

#### `consul_autopilot_upgrade_version_tag`

_Consul Enterprise Only (requires that CONSUL_ENTERPRISE is set to true)_

- Override with `CONSUL_AUTOPILOT_UPGRADE_VERSION_TAG` environment variable
- Default value: ''

#### Custom Configuration Section

As Consul loads the configuration from files and directories in lexical order, typically merging on top of previously parsed configuration files, you may set custom configurations via `consul_config_custom`, which will be expanded into a file named `config_z_custom.json` within your `consul_config_path` which will be loaded after all other configuration by default.

An example usage for enabling `telemetry`:

```yaml
  vars:
    consul_config_custom:
      telemetry:
        dogstatsd_addr: "localhost:8125"
        dogstatsd_tags:
          - "security"
          - "compliance"
        disable_hostname: true
```

## Consul Snapshot Agent

_Consul snapshot agent takes backup snaps on a set interval and stores them. Must have enterprise_

### `consul_snapshot`

- Bool, true will setup and start snapshot agent (enterprise only)
- Default value: false

### `consul_snapshot_storage`

- Location snapshots will be stored. NOTE: path must end in snaps
- Default value: `{{ consul_config_path }}/snaps`

### `consul_snapshot_interval`

- Default value: 1h

### `consul_snapshot_retain`

## OS and Distribution Variables

The `consul` binary works on most Linux platforms and is not distribution
specific. However, some distributions require installation of specific OS
packages with different package names.

### `consul_centos_pkg`

- Consul package filename
- Default value: `{{ consul_version }}_linux_amd64.zip`

### `consul_centos_url`

- Consul package download URL
- Default value: `{{ consul_zip_url }}`

### `consul_centos_sha256`

- Consul download SHA256 summary
- Default value: SHA256 summary

### `consul_centos_os_packages`

- List of OS packages to install
- Default value: list

### `consul_debian_pkg`

- Consul package filename
- Default value: `{{ consul_version }}_linux_amd64.zip`

### `consul_debian_url`

- Consul package download URL
- Default value: `{{ consul_zip_url }}`

### `consul_debian_sha256`

- Consul download SHA256 summary
- Default value: SHA256 SUM

### `consul_debian_os_packages`

- List of OS packages to install
- Default value: list

### `consul_redhat_pkg`

- Consul package filename
- Default value: `{{ consul_version }}_linux_amd64.zip`

### `consul_redhat_url`

- Consul package download URL
- Default value: `{{ consul_zip_url }}`

### `consul_redhat_sha256`

- Consul download SHA256 summary
- Default value: SHA256 summary

### `consul_redhat_os_packages`

- List of OS packages to install
- Default value: list

### consul_systemd_restart_sec

- Integer value for systemd unit `RestartSec` option
- Default value: 42

### consul_systemd_limit_nofile

- Integer value for systemd unit `LimitNOFILE` option
- Default value: 65536

### `consul_ubuntu_pkg`

- Consul package filename
- Default value: `{{ consul_version }}_linux_amd64.zip`

### `consul_ubuntu_url`

- Consul package download URL
- Default value: `{{ consul_zip_url }}`

### `consul_ubuntu_sha256`

- Consul download SHA256 summary
- Default value: SHA256 summary

### `consul_ubuntu_os_packages`

- List of OS packages to install
- Default value: list

### `consul_windows_pkg`

- Consul package filename
- Default value: `{{ consul_version }}_windows_amd64.zip`

### `consul_windows_url`

- Consul package download URL
- Default value: `{{ consul_zip_url }}`

### `consul_windows_sha256`

- Consul download SHA256 summary
- Default value: SHA256 summary

### `consul_windows_os_packages`

- List of OS packages to install
- Default value: list

### `consul_performance`

- List of Consul performance tuning items
- Default value: list

#### `raft_multiplier`

- [Raft multiplier](https://www.consul.io/docs/agent/options.html#raft_multiplier) scales key Raft timing parameters
- Default value: 1

#### `leave_drain_time`

- [Node leave drain time](https://www.consul.io/docs/agent/options.html#leave_drain_time) is the dwell time for a server to honor requests while gracefully leaving

- Default value: 5s

#### `rpc_hold_timeout`

- [RPC hold timeout](https://www.consul.io/docs/agent/options.html#rpc_hold_timeout) is the duration that a client or server will retry internal RPC requests during leader elections
- Default value: 7s

#### `leave_on_terminate`
- [leave_on_terminate](https://www.consul.io/docs/agent/options.html#leave_on_terminate) If enabled, when the agent receives a TERM signal, it will send a Leave message to the rest of the cluster and gracefully leave. The default behavior for this feature varies based on whether or not the agent is running as a client or a server. On agents in client-mode, this defaults to true and for agents in server-mode, this defaults to false.

### `consul_limit`

- Consul node limits (key-value)
- Supported in Consul version 0.9.3 or later
- Default value: *{}*
- Example:
```yaml
consul_limits:
    http_max_conns_per_client: 250
    rpc_max_conns_per_client: 150
```

## Dependencies

Ansible requires GNU tar and this role performs some local use of the unarchive module for efficiency, so ensure that your system has `gtar` and `unzip` installed and in the PATH. If you don't this role will install `unzip` on the remote machines to unarchive the ZIP files.

If you're on system with a different (i.e. BSD) `tar`, like macOS and you see odd errors during unarchive tasks, you could be missing `gtar`.

Installing Ansible on Windows requires the PowerShell Community Extensions. These already installed on Windows Server 2012 R2 and onward. If you're attempting this role on Windows Server 2008 or earlier, you'll want to install the extensions [here](https://pscx.codeplex.com/).

## Example Playbook

Basic installation is possible using the included `site.yml` playbook:

```
ansible-playbook -i hosts site.yml
```

You can also pass variables in using the `--extra-vars` option to the
`ansible-playbook` command:

```
ansible-playbook -i hosts site.yml --extra-vars "consul_datacenter=maui"
```

Be aware that for clustering, the included `site.yml` does the following:

1. Executes consul role (installs Consul and bootstraps cluster)
2. Reconfigures bootstrap node to run without bootstrap-expect setting
3. Restarts bootstrap node

### ACL Support

Basic support for ACLs is included in the role. You can set the environment variables `CONSUL_ACL_ENABLE` to true, and also set the `CONSUL_ACL_DATACENTER` environment variable to its correct value for your environment prior to executing your playbook; for example:

```
CONSUL_ACL_ENABLE=true CONSUL_ACL_DATACENTER=maui \
CONSUL_ACL_MASTER_TOKEN_DISPLAY=true ansible-playbook -i uat_hosts aloha.yml
```

If you want the automatically generated ACL Master Token value emitted to standard out during the play, set the environment variable `CONSUL_ACL_MASTER_TOKEN_DISPLAY` to true as in the above example.

If you want to use existing tokens, set the environment variables `CONSUL_ACL_MASTER_TOKEN` and `CONSUL_ACL_REPLICATION_TOKEN` as well, for example:

```
CONSUL_ACL_ENABLE=true CONSUL_ACL_DATACENTER=stjohn \
CONSUL_ACL_MASTER_TOKEN=0815C55B-3AD2-4C1B-BE9B-715CAAE3A4B2 \
CONSUL_ACL_REPLICATION_TOKEN=C609E56E-DD0B-4B99-A0AD-B079252354A0 \
CONSUL_ACL_MASTER_TOKEN_DISPLAY=true ansible-playbook -i uat_hosts sail.yml
```

There are a number of Ansible ACL variables you can override to further refine your initial ACL setup. They are not all currently picked up from environment variables, but do have some sensible defaults.

Check `defaults/main.yml` to see how some of he defaults (i.e. tokens) are automatically generated.

### Dnsmasq DNS Forwarding Support

The role now includes support for [DNS forwarding](https://www.consul.io/docs/guides/forwarding.html) with [Dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html).

Enable like this:

```
ansible-playbook -i hosts site.yml --extra-vars "consul_dnsmasq_enable=true"
```

Then, you can query any of the agents via DNS directly via port 53,
for example:

```
dig @consul1.consul consul3.node.consul

; <<>> DiG 9.8.3-P1 <<>> @consul1.consul consul3.node.consul
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 29196
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;consul3.node.consul.   IN  A

;; ANSWER SECTION:
consul3.node.consul.  0 IN  A 10.1.42.230

;; Query time: 42 msec
;; SERVER: 10.1.42.210#53(10.1.42.210)
;; WHEN: Sun Aug  7 18:06:32 2016
;;
```

### `consul_delegate_datacenter_dns`
- Whether to delegate Consul datacenter DNS domain to Consul
- Default value: false

### `consul_dnsmasq_enable`

- Whether to install and configure DNS API forwarding on port 53 using DNSMasq
  - Override with `CONSUL_DNSMASQ_ENABLE` environment variable
- Default value: false

### `consul_dnsmasq_bind_interfaces`

- Setting this option to _true_ prevents DNSmasq from binding by default 0.0.0.0, but instead instructs it to bind to the specific network interfaces that correspond to the `consul_dnsmasq_listen_addresses` option
- Default value: false

### `consul_dnsmasq_consul_address`

- Address used by DNSmasq to query consul
- Default value: `consul_address.dns`
- Defaults to 127.0.0.1 if consul's DNS is bound to all interfaces (eg `0.0.0.0`)

### `consul_dnsmasq_cache`

- dnsmasq cache-size
- If smaller then 0, the default dnsmasq setting will be used.
- Default value: *-1*

### `consul_dnsmasq_servers`

- Upstream DNS servers used by dnsmasq
- Default value: *8.8.8.8* and *8.8.4.4*

### `consul_dnsmasq_revservers`

- Reverse lookup subnets
- Default value: *[]*

### `consul_dnsmasq_no_poll`

- Do not poll /etc/resolv.conf
- Default value: false

### `consul_dnsmasq_no_resolv`

- Ignore /etc/resolv.conf file
- Default value: false

### `consul_dnsmasq_local_service`

- Only allow requests from local subnets
- Default value: false

### `consul_dnsmasq_listen_addresses`

- Custom list of addresses to listen on.
- Default value: *[]*

### `consul_connect_enabled`

- Enable Consul Connect feature
- Default value: false

### iptables DNS Forwarding Support

This role can also use iptables instead of Dnsmasq for forwarding DNS queries to Consul. You can enable it like this:

```
ansible-playbook -i hosts site.yml --extra-vars "consul_iptables_enable=true"
```

> Note that iptables forwarding and DNSmasq forwarding cannot be used
> simultaneously and the execution of the role will stop with error if such
> a configuration is specified.

### TLS Support

You can enable TLS encryption by dropping a CA certificate, server certificate, and server key into the role's `files` directory.

By default these are named:

- `ca.crt` (can be overridden by {{ consul_tls_ca_crt }})
- `server.crt` (can be overridden by {{ consul_tls_server_crt }})
- `server.key` (can be overridden by {{ consul_tls_server_key }})

Then either set the environment variable `CONSUL_TLS_ENABLE=true` or use the Ansible variable `consul_tls_enable=true` at role runtime.

### Service management Support

You can create a configuration file for [consul services](https://www.consul.io/docs/agent/services.html).
Add a list of service in the `consul_services`.

| name            | Required | Type | Default | Comment                            |
| --------------- | -------- | ---- | ------- | ---------------------------------- |
| consul_services | False    | List | `[]`    | List of service object (see below) |

Services object:

| name                | Required | Type   | Default | Comment                                                                                                    |
| ------------------- | -------- | ------ | ------- | ---------------------------------------------------------------------------------------------------------- |
| name                | True     | string |         | Name of the service                                                                                        |
| id                  | False    | string |         | Id of the service                                                                                          |
| tags                | False    | list   |         | List of string tags                                                                                        |
| address             | False    | string |         | service-specific IP address                                                                                |
| meta                | False    | dict   |         | Dict of 64 key/values with string semantics                                                                |
| port                | False    | int    |         | Port of the service                                                                                        |
| enable_tag_override | False    | bool   |         | enable/disable the anti-entropy feature for the service                                                    |
| kind                | False    | string |         | identify the service as a Connect proxy instance                                                           |
| proxy               | False    | dict   |         | [proxy configuration](https://www.consul.io/docs/connect/proxies.html#complete-configuration-example)      |
| checks              | False    | list   |         | List of [checks configuration](https://www.consul.io/docs/agent/checks.html)                               |
| connect             | False    | dict   |         | [Connect object configuration](https://www.consul.io/docs/connect/index.html)                              |
| weights             | False    | dict   |         | [Weight of a service in DNS SRV responses](https://www.consul.io/docs/agent/services.html#dns-srv-weights) |
| token               | False    | string |         | ACL token to use to register this service                                                                  |


Configuration example:
```yaml
consul_services:
  - name: "openshift"
    tags: ['production']
  - name: "redis"
    id: "redis"
    tags: ['primary']
    address: ""
    meta:
      meta: "for my service"
    proxy:
      destination_service_name: "redis"
      destination_service_id: "redis1"
      local_service_address: "127.0.0.1"
      local_service_port: 9090
      config: {}
      upstreams:  []
    checks:
      - args: ["/home/consul/check.sh"]
        interval: "10s"
```

Then you can check that the service is well added to the catalog
```
> consul catalog services
consul
openshift
redis
```

>**Note:** to delete a service that has been added from this role, remove it from the `consul_services` list and apply the role again.

### Vagrant and VirtualBox

See [examples/README_VAGRANT.md](https://github.com/ansible-community/ansible-consul/blob/master/examples/README_VAGRANT.md) for details on quick Vagrant deployments under VirtualBox for development, evaluation, testing, etc.

## License

BSD

## Author Information

[Brian Shumate](http://brianshumate.com)

## Contributors

Special thanks to the folks listed in [CONTRIBUTORS.md](https://github.com/ansible-community/ansible-consul/blob/master/CONTRIBUTORS.md) for their contributions to this project.

Contributions are welcome, provided that you can agree to the terms outlined in [CONTRIBUTING.md](https://github.com/ansible-community/ansible-consul/blob/master/CONTRIBUTING.md).
