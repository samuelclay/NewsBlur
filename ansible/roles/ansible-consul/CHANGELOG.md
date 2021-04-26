## 2.6.1

- Update CONTRIBUTORS
- Prevent gathering facts for the same servers in loop. (thanks Pavel Zinchuk)
- Update consul\_systemd.service.j2 (thanks Han Sooloo)
- Allow "Connect" for any and all nodes (#401) (thanks adawalli)
- Increment to 1.7.3 (#395) (thanks Stuart Low)
- fix: Stop sending logs to syslog through systemd (#393) (thanks Samuel Mutel)
- Don't create TLS folder if consul\_tls\_copy\_keys is false (#369) (thanks Samuel Mutel)
- Setup the role to be used in check mode (thanks Louis Paret)
- Use consul\_node\_name as empty by default to use hostname (#373) (thanks Louis Paret)
- Corrected version Fedora dropped libselinux-python. (#385) (thanks jebas)
- add leave\_on\_terminate (thanks Le Minh Duc)
- Allow consul connect on bootstrap nodes (thanks Robert Edström)
- Fix unarchive consul package to run_once (thanks schaltiemi)

## 2.6.0

- Consul v1.7.0
- Add GitHub workflows (thanks @gofrolist )
- Modernize PID path (thanks @smutel)
- Add Consul automatic startup to systemd in Nix tasks (thanks @smutel)
- Add verify_incoming_rpc option (thanks @smutel)
- Update CONTRIBUTORS
- Update documentation

## v2.5.4

- Consul v1.6.3
- consul_manage_group now defaults to true
- Set consul_node_name to ansible_hostname, resolves #337
- Enable consul Connect (thanks @imcitius)
- Cloud auto discovery (thanks @imcitius)
- Use generated password as token UUID source (thanks @jmariondev)
- Fix ACL Replication Token sed pattern (thanks @jmariondev)
- Add when_false to ACL master lookup (thanks @jmariondev)
- Ensure enable_tag_override is json (thanks @slomo)
- Add suport for -alt-domain (thanks @soloradish)
- Add enable_token_persistence option (thanks @smutel)
- Support new ARM builds for Consul 1.6.2+ (thanks @KyleOndy)
- Add CAP_NET_BIND_SERVICE to systemd unit (thanks @smutel)
- Fix configuration template (thanks @imcitius)
- Update documentation (thanks @karras)

## v2.5.3

- Consul v1.6.2
- Update documentation

## v2.5.2

- Fix path / drop with_fileglob in install_remote (thanks @bbaassssiiee)
- Handle consul_encrypt_enable variable for Nix (thanks @bbaassssiiee)
- Parse acl_master_token from config (thanks @bbaassssiiee)
- Fix start service on Windows (thanks @imcitius)
- Preserve custom config (thanks @slomo)
- Update Windows for win_service usage (thanks @FozzY1234)
- Restart when TLS material changes (Thanks @bbaassssiiee)
- No tokens in logging (Thanks @bbaassssiiee)
- Flush handlers at the end of main (Thanks @bbaassssiiee)
- Read tokens from from previously bootstrapped server (Thanks @bbaassssiiee)
- Rename `consul_server_key` variable
- Sort keys in service configuration (thanks @slomo)

## v2.5.1

- Consul v1.6.1
- Add run_once to delegated tasks (thanks @liuxu623)
- Fix service restart on upgrades (thanks @jpiron)
- Fix log directory ownership (@thanks liuxu623)
- Handle missing unzip on control host (thanks @bbaassssiiee)
- Add Added version check for log_rotate_max_files (thanks @jasonneurohr)
- Update documentation

## v2.5.0

- Consul v1.6.0
- Add documentation for new TLS options (thanks @jasonneurohr)
- Add support for translate_wan_address (@calmacara)
- Add `-log-file` (thanks @liuxu623)

## v2.4.5

- Consul v1.5.3
- Update molecule configuration (thanks @gofrolist)
- Support TLS files in subdirectories - resolves #297
- Update some bare variable comparisons - resolves #293
- Update server address for usage with --limit (thanks @danielkucera)
- Update snapshot configuration for TLS (thanks @jasonneurohr)
- Add TLS minimum version and ciper suite preferences (thanks @jasonneurohr)
- Update documentation
- Update CONTRIBUTORS

## v2.4.4

- Consul v1.5.2 (thanks @patsevanton)
- Add Molecule support (thanks @gofrolist)
- Correct several task issues (thanks @gofrolist)

## v2.4.3

- Consul v1.5.1
- Update documentation

## v2.4.2

- Correct ACL typo correction (thanks @bewiwi)
- Fix unarchive failure case (thanks @cyril-dussert)
- Update CONTRIBUTORS

## v2.4.1

- Add LimitNOFILE option to systemd unit (thanks @liuxu623)
- Fix typo in in replication token check (thanks @evilhamsterman)

## v2.4.0

- Consul v1.5.0
- Specify a token for a service (thanks @xeivieni)
- Empty consul_acl_master_token check (thanks @evilhamsterman)
- Separate Unix and Linux tasks from Windows tasks (thanks @evilhamsterman)

## v2.3.6

- Continue with task cleanup
- Fix deleting of unregistered services (thanks @Shaiou)
- Fix issue in Amazon variables (thanks @ToROxI)
- Add bool filter to templates (thanks @eeroniemi)
- Fix CONSUL_ACL_POLICY (thanks @eeroniemi)
- Correct cleanup task fileglob bogusness
- Switch to SIGTERM in sysvinit stop

## v2.3.5

- Consul v1.5.0
- fixed multiarch deployment race condition (thanks @lanefu)
- Switched from systemctl command to systemd module [lint]
- Update for E504 use 'delegate_to: localhost' [lint]
 - asserts
 - install
 - encrypt_gossip
- Update for E104 in with_fileglob for install_remote [lint]
- Update for E601 in syslog [lint]
- Update for E602 in tasks [lint]
 - acl
 - main
- Update example site playbook roles format
- Support install on Debian Testing (thanks @gfeun)
- Fix consul_bind_address (thanks @danielkucera)
- Custom bootstrap expect value (thanks @Roviluca)
- Fix Windows support for registering services (thanks @gyorgynadaban)
- Update documentation

## v2.3.4

- Consul v1.4.3
- Update documentation

## v2.3.3

- Add services management (thanks @Sispheor)
- Add enable_local_script_checks configuration (thanks @canardleteer)
- Add ability to enable legacy GUI (thanks @imcitius)
- Optional domain datacenter delegation with `consul_delegate_datacenter_dns`

## v2.3.2

- Consul v1.4.2
- Remove token generation/retrieval on clients (thanks @jpiron)
- Add listen to all the handler tasks (@pwae)
- retry_join setup independent from the hosts servers (thanks @Fuochi-YNAP)

## v2.3.1

- Add Consul 1.4.0 ACL configuration syntax support (thanks @jpiron)
- Fix unzip installation check task check mode (thanks @jpiron)
- Fix systemd configuration task handler notification (thanks @jpiron)

## v2.3.0

- The role no longer attempts to install the unzip binary locally onto
 the Ansible control host; it is now a hard dependency and role execution
 will fail if unzip is not in the PATH on the control host.
- Snapshot agent installation and configuration (thanks @drewmullen)
- Delegate Consul datacenter DNS domain to Consul (thanks @teralype)
- Allow DNSmasq binding to particular interfaces (thanks @teralype)
- Update local tasks (thanks @sgrimm-sg)
- Update documentation

## v2.2.0

- Consul v1.4.0
- Update documentation

## v2.1.1

- Consul v1.3.1
- Configuration and documentation for gRPC (thanks @RavisMsk)
- Consistent boolean use
- Fix Consul restart handler reference (thanks @blaet)
- Write gossip key on all hosts (thanks @danielkucera)
- Protect local consul cluster key file (thanks @blaet)
- Support Amazon Linux (thanks @soloradish)
- Quite ACL replication token retrieval (thanks @jpiron)
- disable_keyring_file configuration option (thanks @vincepii)
- Update tests
- Update documentation

## v2.1.0

- Consul v1.3.0
- Fix undefined is_virtualenv condition (thanks @jpiron)
- Ensure idempotent folder permissions (thanks @jpiron)
- Add configurable systemd restart time (@thanks abarbare)
- Update documentation (thanks @jeffwelling, @megamorf)

## v2.0.9

- Consul v1.2.3
- Update documentation

## v2.0.8

- Normalize conditionals in all tasks
- Update documentation

## v2.0.7

- Add initial support for Alpine Linux (thanks @replicajune)
- Add support for verify_incoming_https (thanks @jeffwelling)
- Fix ACL token behavior on existing configuration (thanks @abarbare)
- Windows enhancements and fixes (thanks @imcitius)
- Update CONTRIBUTORS
- Update Meta
- Update documentation

## v2.0.6

- Update meta for ArchLinux to allow Galaxy import

## v2.0.4

- Consul 1.2.2
- Update remaining deprecated tests (thanks @viruzzo)
- Added handler to reload configuration on Linux (thanks @viruzzo)
- Add support for Oracle Linux (thanks @TheLastChosenOne)
- Fix generate `consul_acl_master_token` when not provided (thanks @abarbare)
- Update CONTRIBUTORS

## v2.0.3

- Fix jinja2 retry_join loops (thanks @Logan2211)
- Dependency Management Improvements (thanks @Logan2211)
- Update some deprecated tests in main tasks
- Update CONTRIBUTORS
- Update documentation

## v2.0.2

- Consul v1.2.0
- Update documentation

## v2.0.1

- Add beta UI flag (thanks @coughlanio)
- Clean up dir tasks (thanks @soloradish)

## v2.0.0

- Consul v1.1.0
- Update configuration directory permissions (thanks @Rtzq0)
- Update service script dependency (thanks @mattburgess)
- Assert if consul_group_name missing from groups (thanks @suzuki-shunsuke)
- Add Archlinux support
- Change syslog user to root (no syslog user on Debian/dir task fails)
- Updated CHANGELOG ordering 🎉
- Updated CONTRIBUTORS

## v1.60.0

- Consul v1.0.7
- Option for TLS files already on the remote host (thanks @calebtonn)
- Raise minimum Ansible version to 2.4.0.0
- Update documentation
- Update Vagrant documentation

## v1.50.1

- Revert to old style retry_join which doesn't fail in all cases

## v1.50.0

- Consul v1.0.6
- Add support for setting syslog facility and syslog file (thanks @ykhemani)
- Update configuration
- Update tests
- Update documentation (thanks also to @ChrisMcKee)

## v1.40.0

- Consul v1.0.3
- It's 2018!
- Update configuration
- Update documentation

## v1.30.2

- Correct retry_join block (@thanks hwmrocker)

## v1.30.1

- Add performance tuning configuration (thanks @t0k4rt)
 - Set raft multiplier to 1
- Conditionally install Python dependency baed on virtualenv or --user
 Addresses https://github.com/brianshumate/ansible-consul/issues/129#issuecomment-356095611
- Update includes to import_tasks and include_tasks
- Remove invalid consul_version key from configuration
- Update Vagrantfile
 - Set client address to 0.0.0.0 so Vagrant based deploy checks now pass
- Update documentation

## v1.30.0

- Consul v1.0.2
- Update documentation

## v1.29.0

- Consul v1.0.1
- Fix idempotency (thanks @issmirnov)
- Make gossip encryption optional (thanks @hwmrocker)
- Install netaddr with `--user`
- Update documentation
- Update CONTRIBUTORS

## v1.28.1

- Remove deprecated advertise_addrs to resolve #123 so that role works again

## v1.28.0

- Consul 1.0!
- Fix python3 compatibility for meta data (thanks @groggemans)


## v1.27.0

- Consul v0.9.3
- Update server joining (thanks @groggemans)
- Fix types that should be lists (thanks @vincent-legoll)

## v1.26.1

- Fix deprecation notice on include
- Change example server hostnames

## v1.26.0

- Add node_meta config (thanks @groggemans)
- Add additional retry-join parameters (thanks @groggemans)
- Add DNSMasq for Red Hat (thanks @giannidallatorre)
- Fix typo (thanks @vincent-legoll)
- Allow post setup bootstrapping of ACLs (thanks @groggemans)
- Add disable_update_check to config options (thanks @groggemans)
- Fix list example data type (thanks @vincent-legoll)
- Remove tasks for installation of python-consul (thanks @vincent-legoll)

## v1.25.4

- Add raft_protocol parameter, fix version compares (thanks @groggemans)
- Add missing address and port config (thanks @groggemans)
- Add missing ACL config options (thanks @groggemans)
- Prefer retry_join and retry_join_wan instead of start_join / start_join_wan
- DNSMasq updates (thanks @groggemans)

## v1.25.3

- Consul v0.9.2
- Add enable_script_checks parameter (thanks @groggemans)
- Update documentation

## v1.25.2

- Rename `cluster_nodes` label to `consul_instances`

## v1.25.1

- Support rolling upgrades on systemd based Linux (thanks oliverprater)
- Fix breaking change in paths and runtime warnings (thanks oliverprater)
- Set CONSUL_TLS_DIR default to `/etc/consul/ssl` for #95

## v1.25.0

- Consul version 0.9.0
- Add `consul_tls_verify_server_hostname` to TLS configuration template
- Begin to add relevant Consul docs links to variable descriptions in README
- Fix formatting in README_VAGRANT (thanks @jstoja)
- Update CONTRIBUTORS

## v1.24.3

- Consul v0.8.5
- Fix "Check Consul HTTP API" via unix socket (thanks @vincent-legoll)
- Avoid warning about already existing directory (thanks @vincent-legoll)
- Fix typos in messages (thanks @vincent-legoll)
- Fix documentation about `consul_node_role` (thanks @vincent-legoll)
- Update documentation

## v1.24.2

- Use consul_run_path variable (thanks @vincent-legoll)
- Replace remaining hardcoded paths (thanks @vincent-legoll)
- Factorize LOCK_FILE (thanks @vincent-legoll)
- CHANGELOG++
- Update CONTRIBUTORS
- Update README

## v1.24.1

- Add `ansible.cfg` for examples and install netaddr (thanks @arehmandev)
- Improve HTTP API check (thanks @dmke)
- Update CONTRIBUTORS

## v1.24.0

- Consul 0.8.4
- Remove `user_acl_policy.hcl.j2` and `user_custom.json.j2`
- Update configuration template with new ACL variables
- Remove consul_iface from vagrant_hosts
- Simplify ACL configuration
- Remove checks for `consul_acl_replication_token_display`
- Update Vagrantfile
- Update README

## v1.23.1

- Add files directory

## v1.23.0

- Combines all (client/server/bootstrap) config templates (thanks @groggemans)
- Template for dnsmasq settings (thanks @groggemans)

## v1.22.0

- Revert changes from v1.21.2 and v1.21.1

## v1.21.2

Actually add new template files :facepalm:

## v1.21.1

Update ACL tasks
Rename configd_50custom.json.j2 template tp user_custom.json.j2
Rename configd_50acl_policy.hcl template to user_acl_policy.hcl.j2
Do not enable a default set of ACL policies

## v1.20.2

- Correct meta for Windows platform
- Update supported versions
- Update documentation

## v1.20.1

- Update main tasks to move Windows specific tasks into blocks

## v1.20.0

- Initial Windows support (thanks @judy)
- Update documentation
- Update CONTRIBUTORS

## v1.19.1

- Consul version 0.8.3
- Recurse perms through config, data, and log directories (thanks @misho-kr)
- Update documentation

## v1.19.0

- Consul version 0.8.2
- Enable consul_manage_group var and conditional in user_group tasks
- Initial multi datacenter awareness bits (thanks @groggemans)

## v1.18.5

- Set `| bool` where needed to stop warnings about template delimiters
- Add consul group when managing the consul user

## v1.18.4

- Correct links in README (thanks @MurphyMarkW)
- Lower minimum Debian version from 8.5. to 8 (addresses #63)

## v1.18.3

- Generate correct JSON with TLS and ACL enabled (thanks @tbartelmess)
- Switch local tasks to `delegate_to` which should cover most concerns

## v1.18.2

- Remove check from install_remote

## v1.18.1

- Update stat task

## v1.18.0

- Add new vars
 - `consul_run_path` for the PID file
- Add bootstrap-expect toggle option (thanks @groggemans)
- Use directory variables in dirs tasks
- Do not attempt to install Consul binary if already found on consul_bin_path
 - Fixes #60
- Rename intermediate `boostrap_marker` var
- Formatting on CONTRIBUTING
- Update CONTRIBUTORS
- Updated tested versions
- Update documentation

## v1.17.4

- Clean up task names and make more detailed; use consistent verb intros
- Switch to local_action on all local install tasks
- Already using grep, so let's just awk for the SHA and then register it

## v1.17.3

- Revert local_action tasks
 - Ansible generally spazzes out with "no action detected in task"
  for any variation of local_task I tried

## v1.17.2

- Switch to local_action for local tasks
- Wrap IPv6 addresses (thanks @tbartelmess)

## v1.17.1

- Fix template filename (addresses #58)

## v1.17.0

- Updated configuration directory structure (thanks @groggemans)
 - Updated `consul_config_path` to point to `/etc/consul`
 - Added `consul_configd_path` defaulting to `/etc/consul.d`
- Added `consul_debug` variable - defaults to *no* (thanks @groggemans)
- Moved all config related tasks to `tasks/config.yml` (thanks @groggemans)
- Added ACL and TLS parameters to the main `config.json` (thanks @groggemans)
- Now using `/etc/consul/config.json` for all consul roles (thanks @groggemans)
- Fix small bug preventing RPC gossip key to be read (thanks @groggemans)
- Exposed `consul_node_role` as a fact (thanks @groggemans)
- Update documentation

## v1.16.3

- Consul 0.8.1
- Update documentation

## v1.16.2

- Standing corrected - put node_role back into defaults as it will still be
 overridden by host vars (sorry @groggemans)
- Update documentation

## v1.16.1

- Revert node_role addition to default vars so clusters will still properly
 come up since we basically lost access the bootstrap role

## v1.16.0

- Cleanup templates and default vars (thanks @groggemans)
- Add default consul_node_role (client) (thanks @groggemans)
- Update 'gather server facts' task/option (thanks @groggemans)
- Make user management optional + move to own file (thanks @groggemans)
- Properly name-space all vars (thanks @groggemans)
- Move directory settings to own file (thanks @groggemans)
- Replace unsupported Jinja do with if/else (thanks @groggemans)
- Fix missing endif in server configuration template (thanks @groggemans)
- Re-expose consul_bind_address as fact (thanks @groggemans)
- Template output improvements and style changes (thanks @groggemans)
- Add spaces at front end back of JSON arrays (thanks @groggemans)
- Update Vagrantfile
- Update documentation

## v1.15.0

- Add option to download binaries directly to remotes (thanks @jonhatalla)
- Add environment variable overrides for the following default variables:
 - `consul_bind_address`
 - `consul_datacenter`
 - `consul_domain`
 - `consul_group_name`
 - `consul_log_level`
 - `consul_syslog_enable`
 - `consul_acl_default_policy`
 - `consul_acl_down_policy`
 - Rename `consul_src_files` variable
 - Rename `consul_copy_keys` variable
 - Rename `consul_ca_crt` variable
 - Rename `consul_server_crt` variable
 - Rename `consul_tls_server_key` variable
 - Rename `consul_verify_outgoing` variable
 - Rename `consul_verify_server_hostname` variable
 - Move `consul_iface` default to value of `hostvars.consul_iface`
  - Override with elsewhere or with `CONSUL_IFACE` environment variable
  - Closes #40
- Update documentation

## v1.14.0

- Fix bootstrapping (thanks @groggemans)

## v1.13.1

- Finish documentation updates

## v1.13.0

- Cleanup of variables
- Fix statement preventing key transfer to new servers (thanks @groggemans)
- Change custom configuration naming convention
- Update documentation

## v1.12.1

- Fix defaults, shake fist at YAML

## v1.12.0

- Consul version 0.8.0
- Update documentation

## v1.11.3

- Update for config generation on only one host (thanks @misho-kr)
- Update meta

## v1.11.2

- Fix documentation formatting issues
- Add support for Ubuntu 15.04


## v1.11.1

- Updated known good versions
- Format file names
- Look for existing config on all hosts (thanks @misho-kr)
- Update CONTRIBUTORS

## v1.11.0

- File permission updates (thanks @arledesma)
- Explicit consul_user/consul_group ownership of configurations
 (thanks @arledesma)
- Use consul_bin_path throughout (thanks @arledesma)


## v1.10.5

- Additional fixes to debian init
- Add consul_config_custom for role users to specify new or overwrite
 existing configuration (thanks @arledesma)

## v1.10.4

- Corrections to config_debianint.j2 for #34
- Update main task to prefer open Consul HTTP API port over PID file
- Update package cache before installing OS packages
 (watch for and refuse reversion of this as it's occurred once now)

## v1.10.3

- Allow specification of ports object (thanks @arledesma)
- Strict TLS material file permissions (thanks @arledesma)
- Update permissions modes to add leading zero
- Random task cleanup
- Update documentation

## v1.10.2

- Update main task to create a mo better consul user (addresses #31)

## v1.10.1

- Fixup client hosts in template (thanks @violuke)
- Optimize systemd unit file

## v1.10.0

- Initial FreeBSD support
- Vagrantfile updated for FreeBSD
- Added checks for interface addresses for differences (obj vs. literal list)
 in ipv4 addresses as returned by Linux vs. BSD/SmartOS
- New `consul_os` var gets operating system name as lowercase string
- Add AMD64 pass-through/kludge to consul_architecture_map configuration
- Update Vagrantfile
 - Decrease RAM to 1024MB
 - Add FreeBSD specific checks in inline script
 - Add FreeBSD hard requirements (explicit MAC address, disable share, shell)
- Update documentation

## v1.9.7

- Initial ARM support (thanks @lanefu)
- Update CONTRIBUTORS

## v1.9.6

- Update license
- Update preinstall script
- Fix consul_bind_address (thanks @arledesma)
- Better config.json ingress with slurp (thanks @arledesma)

## v1.9.5

- Initial SmartOS support (thanks @sperreault)
- Updated CONTRIBUTORS

## v1.9.4

- Issue with ACL tasks

## v1.9.3

- Fix local_action tasks

## v1.9.2

- Keep gossip encryption in main tasks until we sort cross play var
- Compact YAML style for all tasks
- Fix task items, shorten timeouts
- Update documentation

## v1.9.1

- Split gossip encryption out into separate task file

## v1.9.0

- Local TLS keys (thanks @dggreenbaum)
- Remove Atlas support
- Update documentation

## v1.8.2

- Update Consul bin path in keygen task

## v1.8.1

- Consul 0.7.5
- Update documentation
- Contributors correction

## v1.8.0

- Consul 0.7.5
- BREAKING CHANGE: Deprecate read/write of ACL tokens from file system
 functionality and prefer setting tokens from existing cluster nodes with
 `CONSUL_ACL_MASTER_TOKEN` and `CONSUL_ACL_REPLICATION_TOKEN` environment
 variables instead
- Update documentation

## v1.7.4

- Consul 0.7.3
- Update documentation

## v1.7.3

- Version updates
- Task edits
- add CONTRIBUTING.md

## v1.7.2

- Fix non-working cleanup task
- Update README

## v1.7.0

- Consul version 0.7.2

## v1.6.3

- Ensure that all local_action tasks have become: no (thanks @itewk)

## v1.6.2

- Stop reconfiguring bootstrap node as it's not really necessary and
 spurious races cause failure to re-establish cluster quorum when doing so
- CONSUL_VERSION environment variable
- Deprecated default variables cleanup

## v1.6.1

- Drop Trusty support from meta for now (for #19)

## v1.6.0

- Update task logic around initscripts (for #19)
- Fix issues in initscripts
- Rename Debian init script template
- Update documentation
- Fixing bug with deleting file. Better regex. Formatting. (Thanks @violuke)
- Remember ACL master/replication tokens between runs.
 Actually set replication token. (Thanks @violuke)
- Typo fix (Thanks @violuke)
- Allowing re-running to add new nodes. More HA too. (Thanks @violuke)

## v1.5.7

- Remove unnecessary code (thanks @kostyrevaa)
- Determine binary's SHA 256 from releases.hashicorp.com (for #16)
- Update documentation

## v1.5.6

- Correct Atlas variable names

## v1.5.5

- Initial attempts at idempotency in main tasks (for #14, #15)

## v1.5.4

- Recursors as env var

## v1.5.3

- Update start_join for client configuration template

## v1.5.3

- Consul version 0.7.1
- Consistent template names
- Update documentation

## v1.5.1

- Fail when ethernet interface specified by consul_iface not found on
 the system (addresses #13)

## v1.5.0

- Add initial TLS support
- Update documentation

## v1.4.1

- Move Dnsmasq restart to inside of tasks
- Add client dependencies for further configuration (thanks @crumohr)
- Fix error using predefined encryption key (thanks @crumohr)
- Removal of redundant includes (thanks @crumohr)

## v1.4.0

- Compatibility with Ubuntu 16.04 (thanks @crumohr)
- iptables support (thanks @crumohr)
- Booleans instead of strings for variables (thanks @crumohr)
- Runnable if DNS is broken (thanks @crumohr)
- Remove unused variables
- Update block conditional for ACLs
- Update documentation

## v1.3.4

- Update documentation

## v1.3.3

- Update/validate CentOS 7 box
- Update documentation
- Updated failure cases for CentOS

# v1.3.2

- Correct CONSUL_DNSMASQ_ENABLE var name

## v1.3.1

- Correct variable names
- Add token display variables
- Update documentation
- Remove deprecated variables

## v1.3.0

- Initial ACL support
- Initial Atlas support
- Streamline main tasks
- Update documentation
- Update variables

## v1.2.16

- Clean up variables (thanks @jessedefer)
- Update documentation (thanks @jessedefer)
- Update CONTRIBUTORS

## v1.2.15

- Fail on older versions
- Move distro vars to defaults
- Remove vars

## v1.2.14

- Documentation updates

## v1.2.13

- Doc meta

## v1.2.12

- Update documentation

## v1.2.11

- Update supported versions
- Fix up unarchive task quoting

## v1.2.10

- Added consul_rpc_bind_address
- Updated documentation

## v1.2.9

- Download once, copy many for Consul binary
- Rename package variables

## v1.2.8

- Stop creating UI directory
- Set correct RAM in Vagrantfile

## v1.2.7

- Secondary nodes now join only the bootstrap node
- Added consul_bootstrap_interface variable
- Add PIDFile to systemd unit
- Updated documentation

## v1.2.6

- Update documentation
- Add `consul_node_name` variable
- Add `consul_dns_bind_address` variable
- Add `consul_http_bind_address` variable
- Add `consul_https_bind_address` variable
- Add initial ACL variables

## v1.2.5

- Add LICENSE.txt for Apache 2.0 license

## v1.2.4

- Updated README
- Undo 125bd4bb369bb85f58a09b5dc81839e2779bd29f as dots in node_name breaks
 DNS API (without recursor option) and also breaks dnsmasq option

## v1.2.3

- Still with the tests

## v1.2.3

- Updated README

## v1.2.1

- Tests work locally but not in Travis; trying an env var instead of cfg

## v1.2.0

- Consul version 0.7.0
- UI is built in now, so no longer downloaded / installed separately
- Usability improvements (thanks @Rodjers)

## v1.1.0

- Bare role now installs and bootstraps cluster; included site.yml will also
 reconfigure bootstrap node as server and optionally enable dnsmasq
 forwarding for all cluster agents
- Remove bad client_addr bind in favor of default (localhost)
 Some weirdness was occurring whereby the client APIs were listening on
 TCP6/UDP6 sockets but not TCP4/UDP4 when client_addr set to 0.0.0.0
- Adjust timeouts for cluster UI check
- Default configurable domain to "consul" so that examples from docs work, etc.
- Combine all OS vars into main (addresses undefined var warnings)
- Removed separate OS var files
- Updated known working software versions
- Any errors are fatal for the site.yml example playbook
- Explicit pid-file to use in wait_for
- Remove cruft from init script
- Update documentation

## v1.0.15

- Meta update

## v1.0.14

- Initial test
- Initial Travis CI setup

## v1.0.13

- Add initial dnsmasq front end bits
- Reconfigure bootstrap node for normal operation (remove bootstrap-expect)
 after initial cluster formation and restart bootstrap node

## v1.0.12

- FIX: No such file or directory /etc/init.d/functions (thanks @oliverprater)
- FIX: Using bare variables is deprecated (thanks @oliverprater)
- Added CONTRIBUTORS.md
- Updated documentation

## v1.0.11

- Renamed bootstrap template

## v1.0.10

- Remove extra datacenter definition

## v1.0.9

- Change datacenter value

## v1.0.8

- Update documentation

## v1.0.7

- Update supported versions
- Update documentation

## v1.0.6

- Updated to Consul 0.6.4
- Make bind_address configurable for #1
- Cleaned up deprecaed bare variables
- Updated supporting software versions
- Updated documentation

## v1.0.5

- Updated defaults and Consul version (thanks @bscott)
- Made cluster bootable and switch to become_user + other Ansibel best
 practices (thanks @Rodjers)
- Updated minimum Ansible version required in meta

## v1.0.4

- Renamed consul_nodes label for better compatibility with my other roles

## v1.0.3

- Prefix /usr/local/bin in PATH for cases where the consul binary is not found
- Changed UI path
- Add generic SysV init script
- Add Debian init script
- Use systemd for distribution major versions >= 7
- Remove Upstart script
- Updated configuration files

## v1.0.2

- Removed the need for cluster_nodes variable
- Fix client template task
- Fix invalid JSON in the config.json outputs
- Updated documentation

## v1.0.1

- Updated README

## v1.0.0

- Installs Consul and Consul UI to each node
- Installs example configuration for bootstrap, server, and client
- Installs example upstart script
