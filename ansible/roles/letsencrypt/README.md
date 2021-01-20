# ansible-letsencrypt
An ansible role to generate TLS certificates and get them signed by Let's Encrypt.

Currently attempts first to use the `webroot` authenticator, then if that fails to create certificates,
it will use the standalone authenticator. This is handy for generating certs on a fresh machine before
the web server has been configured or even installed.

I've tested this on a couple of Debian Jessie boxes with nginx, if you test it on other things please let me know
the results (positive or otherwise) so I can document them here/fix the issue.

# Usage
First, read Let's Encrypt's TOS and EULA. Only proceed if you agree to them.

The following variables are available:

`letsencrypt_webroot_path` is the root path that gets served by your web server. Defaults to `/var/www`.

`letsencrypt_email` needs to be set to your email address. Let's Encrypt wants it. Defaults to `webmaster@{{ ansible_fqdn }}`.

`letsencrypt_cert_domains` is a list of domains you wish to get a certificate for. It defaults to a single item with the value of `{{ ansible_fqdn }}`.

`letsencrypt_install_directory` should probably be left alone, but if you set it, it will change where the letsencrypt program is installed.

`letsencrypt_server` sets the auth server. Set to `https://acme-staging.api.letsencrypt.org/directory` to use the staging server (far higher rate limits, but certs are not trusted, intended for testing)

The [Let's Encrypt client](https://github.com/letsencrypt/letsencrypt) will put the certificate and accessories in `/etc/letsencrypt/live/<first listed domain>/`. For more info, see the [Let's Encrypt documentation](https://letsencrypt.readthedocs.org/en/latest/using.html#where-are-my-certificates).

# Example Playbook
```
---
 - hosts: tls_servers
   user: root
   roles:
     - role: letsencrypt
       letsencrypt_webroot_path: /var/www/html
       letsencrypt_email: user@example.net
       letsencrypt_cert_domains:
        - www.example.net
        - example.net
```
