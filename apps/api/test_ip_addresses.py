from pathlib import Path
from unittest import TestCase

from jinja2 import Environment, StrictUndefined


class Test_IpAddressInventory(TestCase):
    def render_addresses(self, hostvars):
        template_path = (
            Path(__file__).resolve().parents[2] / "ansible/roles/web/templates/ip_addresses.txt.j2"
        )
        template = Environment(trim_blocks=True, undefined=StrictUndefined).from_string(
            template_path.read_text()
        )
        return template.render(hostvars=hostvars)

    def test_publishes_both_address_families_for_existing_server_roles(self):
        for host in ("happ-web-01", "happ-refresh-1", "hnode-page-1", "hwww", "htask-celery-01"):
            with self.subTest(host=host):
                addresses = self.render_addresses(
                    {host: {"ansible_host": "192.0.2.1", "public_ipv6": "2001:db8::1"}}
                )
                self.assertEqual(addresses, "192.0.2.1\n2001:db8::1\n")

    def test_ipv4_only_hosts_still_render_without_blank_lines(self):
        addresses = self.render_addresses(
            {
                "happ-web-01": {"ansible_host": "192.0.2.1"},
                "htask-work-1": {"ansible_host": "192.0.2.2", "public_ipv6": ""},
            }
        )
        self.assertEqual(addresses, "192.0.2.1\n192.0.2.2\n")

    def test_does_not_publish_other_server_roles(self):
        addresses = self.render_addresses(
            {
                "hdb-postgres-1": {"ansible_host": "192.0.2.1", "public_ipv6": "2001:db8::1"},
                "hstaging": {"ansible_host": "192.0.2.2", "public_ipv6": "2001:db8::2"},
                "hforum": {"ansible_host": "192.0.2.3", "public_ipv6": "2001:db8::3"},
            }
        )
        self.assertEqual(addresses, "")
