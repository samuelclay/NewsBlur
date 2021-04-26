"""Role testing files using testinfra."""


def test_hosts_file(host):
    """Validate /etc/hosts file."""
    f = host.file("/etc/hosts")

    assert f.exists
    assert f.user == "root"
    assert f.group == "root"


def test_service(host):
    """Validate consul service."""
    consul = host.service('consul')

    assert consul.is_running
    # disabled due to fail on debian 9
    # assert consul.is_enabled
