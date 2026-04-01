import mongoengine.connection as mongo_connection
from django.db import connection


def test_pytest_uses_test_mongo_database():
    default_connection = mongo_connection._connection_settings["default"]

    assert default_connection["name"] == "newsblur_test"


def test_pytest_uses_django_test_database():
    assert connection.settings_dict["NAME"] == "test_newsblur"
