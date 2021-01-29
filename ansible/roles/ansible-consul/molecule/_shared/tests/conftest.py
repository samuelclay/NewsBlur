"""PyTest Fixtures."""
from __future__ import absolute_import
import os
import pytest


def pytest_runtest_setup(item):
    """Run tests only when under molecule with testinfra installed."""
    try:
        import testinfra
    except ImportError:
        pytest.skip("Test requires testinfra", allow_module_level=True)
    if "MOLECULE_INVENTORY_FILE" in os.environ:
        pytest.testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
            os.environ["MOLECULE_INVENTORY_FILE"]
        ).get_hosts("all")
    else:
        pytest.skip(
            "Test should run only from inside molecule.",
            allow_module_level=True
        )
