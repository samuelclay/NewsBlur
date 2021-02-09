# Ansible Letsecrypt

[![All Contributors](https://img.shields.io/badge/all_contributors-2-orange.svg?style=flat-square)](#contributors)
[![Ansible Galaxy](https://img.shields.io/badge/ansible--galaxy-letsenctypt-blue.svg?style=flat-square)](https://galaxy.ansible.com/auxilincom/letsencrypt)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square)](https://github.com/auxilin/ansible-letsencrypt/blob/master/LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)


[![Watch on GitHub](https://img.shields.io/github/watchers/auxilincom/ansible-letsencrypt.svg?style=social&label=Watch)](https://github.com/auxilincom/ansible-letsencrypt/watchers)
[![Star on GitHub](https://img.shields.io/github/stars/auxilincom/ansible-letsencrypt.svg?style=social&label=Stars)](https://github.com/auxilincom/ansible-letsencrypt/stargazers)
[![Tweet](https://img.shields.io/twitter/url/https/github.com/auxilincom/ansible-letsencrypt.svg?style=social)](https://twitter.com/intent/tweet?text=I%27m%20using%20Auxilin%20components%20to%20build%20my%20next%20product%20🚀.%20Check%20it%20out:%20https://github.com/auxilincom/ansible-letsencrypt)

The ansible role for generating [letsecrypt](https://letsencrypt.org/) certificates.

## Features

* 🔐 Ability to generate single certificates for specific domains/subdomains
* 🔐 Ability to generate wildcard certificates using settings for the corresponding DNS provider
* ⚡️️ Automatically renew certificates every month
* 🔧 Generated certificates stored in the directory `/etc/letsencrypt/live/{{app_domain}}` where `app_domain` is the name of domain/subdomain for which we generated certificates and ready for use with any HTTP-server

## Role Variables

Available variables:

|Name|Default|Description|
|:--:|:--:|:----------|
|**`use_dns_plugin`**|`no`|Use certbot dns provider (use this if you need wildcard sertificate) or certbot itselt.|
|**`certbot_version`**|`latest`|# Version of certbot or certbot dns plugin (if `use_dns_plugin` is `yes`), see other versions [here](https://hub.docker.com/r/certbot/certbot/tags)|
|**`dns_plugin`**|`cloudflare`|Dsn plugin that will be used with certbot (when `use_dns_plugin` is `yes`), list of plugins can be found [here](https://certbot.eff.org/docs/using.html#dns-plugins)|
|**`email`**|`Email that will be used for notifications`|Email that will be used for notifications|
|**`domains_list`**|`- "{{ ansible_fqdn }}"`|List of domain for which you want to get a certificates|


<details><summary>Additional variables for Cloudflare</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_email`**|`""`|DNS email|
|**`dns_api_key`**|`""`|DNS api key|

</p>
</details>

<details><summary>Additional variables for CloudXNS</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_api_key`**|`""`|DNS api key|
|**`dns_secret_key`**|`""`|DNS secret key|

</p>
</details>

<details><summary>Additional variables for DigitalOcean</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_token`**|`""`|DNS token|

</p>
</details>

<details><summary>Additional variables for DNSimple</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_token`**|`""`|DNS token|

</p>
</details>

<details><summary>Additional variables for DNS Made Easy</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_api_key`**|`""`|DNS api key|
|**`dns_secret_key`**|`""`|DNS secret key|

</p>
</details>

<details><summary>Additional variables for Linode</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_key`**|`""`|DNS key|

</p>
</details>

<details><summary>Additional variables for LuaDNS</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_email`**|`""`|DNS email|
|**`dns_token`**|`""`|DNS token|

</p>
</details>

<details><summary>Additional variables for NS1</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_api_key`**|`""`|DNS api key|

</p>
</details>

<details><summary>Additional variables for OVH</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_endpoint`**|`""`|DNS endpoint|
|**`dns_application_key`**|`""`|DNS application key|
|**`dns_application_secret`**|`""`|DNS application secret|
|**`dns_consumer_key`**|`""`|DNS consumer key|

</p>
</details>

<details><summary>Additional variables for RFC 2136</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_server`**|`""`|Target DNS server|
|**`dns_port`**|`""`|Target DNS port|
|**`dns_name`**|`""`|TSIG key name|
|**`dns_secret`**|`""`|TSIG key secret|
|**`dns_algorithm`**|`""`|TSIG key algorithm|

</p>
</details>

<details><summary>Additional variables for Route 53</summary>
<p>

|Name|Default|Description|
|:--:|:--:|:----------|
|**`dns_access_key_id`**|`""`|DNS access key id|
|**`dns_secret_access_key`**|`""`|DNS secret access key id|

</p>
</details>

## Dependencies

[Docker](https://www.docker.com/) must be installed on the server in order to use this role. If you don't have docker on your server we recommend [angstwad.docker_ubuntu](https://github.com/angstwad/docker.ubuntu) Ansible role.

Example of using `angstwad.docker_ubuntu`:
```yml
---
- name: Setup server
  hosts: server
  become: true
  roles:
    - { role: angstwad.docker_ubuntu }
```

## Quick example

Example of the playbook file:

```yml
---
- name: Setup server
  hosts: server
  become: true
  roles:
    - role: auxilincom.letsencrypt
      use_dns_plugin: yes
      certbot_version: v0.26.1
      dns_plugin: cloudflare
      email: ship@test.com
      domains_list:
        - "*.ship.com"
      dns_email: ship_dns@test.com
      dns_api_key: 0123456789abcdef0123456789abcdef01234567
```

## Change Log

This project adheres to [Semantic Versioning](http://semver.org/).
Every release is documented on the Github [Releases](https://github.com/auxilincom/ansible-letsencrypt/releases) page.

## License

Ansible-letsencrypt is released under the [MIT License](https://github.com/auxilincom/ansible-letsencrypt/blob/master/LICENSE).

## Contributing

Please read [CONTRIBUTING.md](https://github.com/auxilincom/ansible-letsencrypt/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Contributors

Thanks goes to these wonderful people ([emoji key](https://github.com/kentcdodds/all-contributors#emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/ezhivitsa"><img src="https://avatars2.githubusercontent.com/u/6461311?v=4" width="100px;" alt="Evgeny Zhivitsa"/><br /><sub><b>Evgeny Zhivitsa</b></sub></a><br /><a href="https://github.com/auxilin/ansible-letsencrypt/commits?author=ezhivitsa" title="Documentation">📖</a> <a href="#ideas-ezhivitsa" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/auxilin/ansible-letsencrypt/commits?author=ezhivitsa" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/anorsich"><img src="https://avatars3.githubusercontent.com/u/681396?v=4" width="100px;" alt="Andrew Orsich"/><br /><sub><b>Andrew Orsich</b></sub></a><br /><a href="#ideas-anorsich" title="Ideas, Planning, & Feedback">🤔</a> <a href="#review-anorsich" title="Reviewed Pull Requests">👀</a></td>
  </tr>
</table>

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification. Contributions of any kind welcome!
