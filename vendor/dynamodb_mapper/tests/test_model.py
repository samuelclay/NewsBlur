import unittest

import json

import mock

from dynamodb_mapper.model import (ConnectionBorg, DynamoDBModel,
    autoincrement_int, MaxRetriesExceededError, MAX_RETRIES,
    ConflictError, _python_to_dynamodb, _dynamodb_to_python, utc_tz,
    _get_default_value, SchemaError, MAGIC_KEY, OverwriteError, InvalidRegionError)
from boto.exception import DynamoDBResponseError
from boto.dynamodb.exceptions import DynamoDBConditionalCheckFailedError
import datetime

class mocked_region(object):
    def __init__(self, name):
        self.name = name


# Hash-only primary key
class DoomEpisode(DynamoDBModel):
    __table__ = "doom_episode"
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
        "name": unicode,
    }


# Composite primary key
class DoomMap(DynamoDBModel):
    __table__ = "doom_map"
    __hash_key__ = "episode_id"
    __range_key__ = "name"
    __schema__ = {
        "episode_id": int,
        "name": unicode,
        "world": unicode
    }


# autoincrement_int primary key
class LogEntry(DynamoDBModel):
    __table__ = "log_entry"
    __hash_key__ = "id"
    __schema__ = {
        "id": autoincrement_int,
        "text": unicode,
    }


# set attribute
class DoomCampaign(DynamoDBModel):
    __table__ = "doom_campaign"
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
        "name": unicode,
        "cheats": set,
    }


# boolean regression test
class DoomCampaignStatus(DynamoDBModel):
    __table__ = "doom_campaign_status"
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
        "name": unicode,
        "completed": bool,
    }

# list attribute
class DoomMonster(DynamoDBModel):
    __table__ = "doom_monster"
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
        "attacks": list,
    }


# dict attribute
class DoomMonsterMap(DynamoDBModel):
    __table__ = "doom_monster_map"
    __hash_key__ = "map_id"
    __schema__ = {
        "map_id": int,
        "monsters": dict,
    }


# datetime.datetime hash key
class Patch(DynamoDBModel):
    __table__ = "patch"
    __hash_key__ = "datetime"
    __schema__ = {
        "datetime": datetime.datetime,
        "description": unicode,
    }


# Composite key with list hash_key, datetime.datetime range_key
class GameReport(DynamoDBModel):
    __table__ = "game_report"
    __hash_key__ = "player_ids"
    __range_key__ = "datetime"
    __schema__ = {
        "player_ids": list,
        "datetime": datetime.datetime,
    }


# Field with a default value
class PlayerStrength(DynamoDBModel):
    __table__ = "player_strength"
    __hash_key__ = "player_id"
    __schema__ = {
        "player_id": int,
        "strength": unicode,
    }
    __defaults__ = {
        "strength": u'weak'
    }


class NoTableName(DynamoDBModel):
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
    }


class NoHashKey(DynamoDBModel):
    __table__ = "error"
    __schema__ = {
        "id": int,
    }


class NoSchema(DynamoDBModel):
    __table__ = "error"
    __hash_key__ = "id"


class IncompatibleKeys(DynamoDBModel):
    __table__ = "error"
    __hash_key__ = "id"
    __range_key__ = "date"
    __schema__ = {
        "id": autoincrement_int,
        "date": datetime.datetime,
    }


# Json export tester
class ToJsonTest(DynamoDBModel):
    __table__ = "to_json_test"
    __hash_key__ = "id"
    __schema__ = {
        "id": int,
        "set": set,
        "date": datetime.datetime,
    }


def return_42():
    return 42


class TestConnectionBorg(unittest.TestCase):
    def setUp(self):
        ConnectionBorg()._connections.clear()
        ConnectionBorg._shared_state = {
            "_aws_access_key_id": None,
            "_aws_secret_access_key": None,
            "_region": None,
            "_connections": {},
        }

    def tearDown(self):
        ConnectionBorg()._connections.clear()
        ConnectionBorg._shared_state = {
            "_aws_access_key_id": None,
            "_aws_secret_access_key": None,
            "_region": None,
            "_connections": {},
        }

    def test_borgness(self):
        aws_access_key_id = "foo"
        aws_secret_access_key = "bar"

        borg1 = ConnectionBorg()
        borg2 = ConnectionBorg()

        borg1.set_credentials(aws_access_key_id, aws_secret_access_key)

        self.assertEquals(borg1._aws_access_key_id, aws_access_key_id)
        self.assertEquals(borg1._aws_secret_access_key, aws_secret_access_key)

        self.assertEquals(borg2._aws_access_key_id, aws_access_key_id)
        self.assertEquals(borg2._aws_secret_access_key, aws_secret_access_key)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_set_region_valid(self, m_boto):
        # Make sure internal state is set and shared
        m_regions = [
            mocked_region('us-east-1'),
            mocked_region('eu-west-1'),
        ]

        m_boto.dynamodb.regions.return_value = m_regions

        borg1 = ConnectionBorg()
        borg2 = ConnectionBorg()

        self.assertIs(None, borg1._region)
        self.assertIs(None, borg2._region)

        borg1.set_region("eu-west-1")

        self.assertIs(m_regions[1], borg1._region)
        self.assertIs(m_regions[1], borg2._region)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_set_region_invalid(self, m_boto):
        # Make sure internal state is set and shared
        m_regions = [
            mocked_region('us-east-1'),
            mocked_region('eu-west-1'),
        ]

        m_boto.dynamodb.regions.return_value = m_regions

        borg1 = ConnectionBorg()
        borg2 = ConnectionBorg()

        self.assertIs(None, borg1._region)
        self.assertIs(None, borg2._region)

        self.assertRaises(
            InvalidRegionError,
            borg1.set_region,
            "moon-hidden-1",
        )

        self.assertIs(None, borg1._region)
        self.assertIs(None, borg2._region)


    @mock.patch("dynamodb_mapper.model.boto")
    def test_set_credentials(self, m_boto):
        # Make sure internal state is set and shared
        m_get_table = m_boto.connect_dynamodb.return_value.get_table

        aws_access_key_id = "foo"
        aws_secret_access_key = "bar"
        table_name = "foo"

        borg1 = ConnectionBorg()
        borg2 = ConnectionBorg()

        borg1.set_credentials(aws_access_key_id, aws_secret_access_key)

        self.assertIs(borg1._aws_access_key_id ,aws_access_key_id)
        self.assertIs(borg2._aws_access_key_id ,aws_access_key_id)

        self.assertIs(borg1._aws_secret_access_key ,aws_secret_access_key)
        self.assertIs(borg2._aws_secret_access_key ,aws_secret_access_key)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_get_table_default(self, m_boto):
        m_get_table = m_boto.connect_dynamodb.return_value.get_table

        aws_access_key_id = "foo"
        aws_secret_access_key = "bar"
        table_name = "foo"

        borg1 = ConnectionBorg()

        borg1._aws_access_key_id = aws_access_key_id
        borg1._aws_secret_access_key = aws_secret_access_key

        ConnectionBorg().get_table(table_name)
        m_get_table.assert_called_with(table_name)

        m_boto.connect_dynamodb.assert_called_with(
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            region=None,
        )

    @mock.patch("dynamodb_mapper.model.boto")
    def test_get_table_eu_region(self, m_boto):
        m_get_table = m_boto.connect_dynamodb.return_value.get_table
        m_region = mocked_region('eu-west-1')

        aws_access_key_id = "foo"
        aws_secret_access_key = "bar"
        table_name = "foo"

        borg1 = ConnectionBorg()

        borg1._region = m_region
        borg1._aws_access_key_id = aws_access_key_id
        borg1._aws_secret_access_key = aws_secret_access_key

        ConnectionBorg().get_table(table_name)
        m_get_table.assert_called_with(table_name)

        m_boto.connect_dynamodb.assert_called_with(
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            region=m_region,
        )

    @mock.patch("dynamodb_mapper.model.boto")
    def test_new_batch_list_nominal(self, m_boto):
        m_new_batch_list = m_boto.connect_dynamodb.return_value.new_batch_list
        ConnectionBorg().new_batch_list()

        m_new_batch_list.assert_called_once()


    def test_create_table_no_name(self):
        self.assertRaises(
            SchemaError,
            ConnectionBorg().create_table,
            NoTableName, 10, 5, False
        )

    def test_create_table_no_hash(self):
        self.assertRaises(
            SchemaError,
            ConnectionBorg().create_table,
            NoHashKey, 10, 5, False
        )

    def test_create_table_no_schema(self):
        self.assertRaises(
            SchemaError,
            ConnectionBorg().create_table,
            NoSchema, 10, 5, False
        )

    def test_create_table_autoinc_with_range(self):
        self.assertRaises(
            SchemaError,
            ConnectionBorg().create_table,
            IncompatibleKeys, 10, 5, False
        )

    @mock.patch("dynamodb_mapper.model.boto")
    def test_create_table_hash_key(self, m_boto):
        m_connection = m_boto.connect_dynamodb.return_value
        m_create_schema = m_connection.create_schema
        m_create_table = m_connection.create_table

        table = ConnectionBorg().create_table(DoomEpisode, 10, 5, False)

        m_create_schema.assert_called_once_with(
            hash_key_name=DoomEpisode.__hash_key__,
            hash_key_proto_value=0,
            range_key_name=None,
            range_key_proto_value=None
        )

        m_create_table.assert_called_once_with(
            DoomEpisode.__table__, m_create_schema.return_value, 10, 5)

        table.refresh.assert_called_once_with(wait_for_active=False)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_create_table_hash_key_autoinc(self, m_boto):
        # create a table with autoinc index. Wait should automatically be set to True
        m_connection = m_boto.connect_dynamodb.return_value
        m_create_schema = m_connection.create_schema
        m_create_table = m_connection.create_table

        table = ConnectionBorg().create_table(LogEntry, 10, 5, False)

        m_create_schema.assert_called_once_with(
            hash_key_name=LogEntry.__hash_key__,
            hash_key_proto_value=0,
            range_key_name=None,
            range_key_proto_value=None
        )

        m_create_table.assert_called_once_with(
            LogEntry.__table__, m_create_schema.return_value, 10, 5)

        table.refresh.assert_called_once_with(wait_for_active=True)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_create_table_key_date_dict(self, m_boto):
        # check that datetime/list may successfully be used as key
        m_connection = m_boto.connect_dynamodb.return_value
        m_create_schema = m_connection.create_schema
        m_create_table = m_connection.create_table

        table = ConnectionBorg().create_table(GameReport, 10, 5, False)

        m_create_schema.assert_called_once_with(
            hash_key_name=GameReport.__hash_key__,
            hash_key_proto_value=u"",
            range_key_name=GameReport.__range_key__,
            range_key_proto_value=u""
        )

        m_create_table.assert_called_once_with(
            GameReport.__table__, m_create_schema.return_value, 10, 5)

        table.refresh.assert_called_once_with(wait_for_active=False)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_create_table_composite_key(self, m_boto):
        m_connection = m_boto.connect_dynamodb.return_value
        m_create_schema = m_connection.create_schema
        m_create_table = m_connection.create_table

        table = ConnectionBorg().create_table(DoomMap, 10, 5, True)

        m_create_schema.assert_called_once_with(
            hash_key_name=DoomMap.__hash_key__,
            hash_key_proto_value=0,
            range_key_name=DoomMap.__range_key__,
            range_key_proto_value=""
        )

        m_create_table.assert_called_once_with(
            DoomMap.__table__, m_create_schema.return_value, 10, 5)

        table.refresh.assert_called_once_with(wait_for_active=True)


class TestTypeConversions(unittest.TestCase):
    def test_python_to_dynamodb_number(self):
        self.assertEquals(0, _python_to_dynamodb(0))
        self.assertEquals(0.0, _python_to_dynamodb(0.0))
        self.assertEquals(10, _python_to_dynamodb(10))
        self.assertEquals(10.0, _python_to_dynamodb(10.0))
        self.assertEquals(0, _python_to_dynamodb(False))
        self.assertEquals(1, _python_to_dynamodb(True))

    def test_dynamodb_to_python_number(self):
        self.assertEquals(0, _dynamodb_to_python(int, 0))
        self.assertEquals(0.0, _dynamodb_to_python(float, 0.0))
        self.assertEquals(10, _dynamodb_to_python(int, 10))
        self.assertEquals(10.0, _dynamodb_to_python(float, 10.0))
        self.assertEquals(False, _dynamodb_to_python(bool, 0))
        self.assertEquals(True, _dynamodb_to_python(bool, 1))

    def test_python_to_dynamodb_unicode(self):
        self.assertEquals(u"hello", _python_to_dynamodb(u"hello"))
        # Empty strings become missing attributes
        self.assertIsNone(_python_to_dynamodb(u""))

    def test_dynamodb_to_python_unicode(self):
        self.assertEquals(u"hello", _dynamodb_to_python(unicode, u"hello"))
        # Missing attributes become None
        self.assertIsNone(_dynamodb_to_python(unicode, None))

    def test_python_to_dynamodb_set(self):
        self.assertEquals(set([1, 2, 3]), _python_to_dynamodb(set([1, 2, 3])))
        self.assertEquals(
            set(["foo", "bar", "baz"]),
            _python_to_dynamodb(set(["foo", "bar", "baz"])))
        # Empty sets become missing attributes
        self.assertIsNone(_python_to_dynamodb(set()))

    def test_dynamodb_to_python_set(self):
        self.assertEquals(set([1, 2, 3]), _dynamodb_to_python(set, set([1, 2, 3])))
        self.assertEquals(
            set(["foo", "bar", "baz"]),
            _dynamodb_to_python(set, set(["foo", "bar", "baz"])))
        # Empty sets become None
        self.assertIsNone(_dynamodb_to_python(set, None))

    def test_python_to_dynamodb_list(self):
        attacks = [
            {'name': 'fireball', 'damage': 10},
            {'name': 'punch', 'damage': 5}
        ]

        self.assertEquals(
            json.dumps(attacks, sort_keys=True),
            _python_to_dynamodb(attacks))
        self.assertEquals("[]", _python_to_dynamodb([]))

    def test_dynamodb_to_python_list(self):
        attacks = [
            {'name': 'fireball', 'damage': 10},
            {'name': 'punch', 'damage': 5}
        ]

        self.assertEquals(
            attacks,
            _dynamodb_to_python(list, json.dumps(attacks, sort_keys=True)))
        self.assertEquals([], _dynamodb_to_python(list, "[]"))

    def test_python_to_dynamodb_dict(self):
        monsters = {
            "cacodemon": [
                {"x": 10, "y": 20},
                {"x": 10, "y": 30}
            ],
            "imp": [],
            "cyberdemon": []
        }

        self.assertEquals(
            json.dumps(monsters, sort_keys=True),
            _python_to_dynamodb(monsters))
        self.assertEquals("{}", _python_to_dynamodb({}))

    def test_dynamodb_to_python_dict(self):
        monsters = {
            "cacodemon": [
                {"x": 10, "y": 20},
                {"x": 10, "y": 30}
            ],
            "imp": [],
            "cyberdemon": []
        }

        self.assertEquals(
            monsters,
            _dynamodb_to_python(dict, json.dumps(monsters, sort_keys=True)))
        self.assertEquals({}, _dynamodb_to_python(dict, "{}"))

    def test_dynamodb_to_python_datetime(self):
        self.assertEquals(
            datetime.datetime(2012, 05, 31, 12, 0, 0, tzinfo=utc_tz),
            _dynamodb_to_python(datetime.datetime,
                                "2012-05-31T12:00:00.000000+00:00"))
        self.assertEquals(
            datetime.datetime(2010, 11, 1, 4, 0, 0, tzinfo=utc_tz),
            _dynamodb_to_python(datetime.datetime,
                                "2010-11-01T04:00:00.000000Z"))

    def test_dynamodb_to_python_default(self):
        self.assertIsNone(_dynamodb_to_python(datetime.datetime, None))

    def test_dynamodb_to_python_datetime_notz(self):
        # Timezone info is mandatory
        self.assertRaises(
            ValueError,
            _dynamodb_to_python, datetime.datetime, "2012-05-31T12:00:00.000000")

    def test_python_to_dynamodb_datetime(self):
        self.assertEquals(
            "2012-05-31T12:00:00.000000+00:00",
            _python_to_dynamodb(datetime.datetime(2012, 05, 31, 12, 0, 0, tzinfo=utc_tz)))

    def test_python_to_dynamodb_datetime_notz(self):
        self.assertRaises(
            ValueError,
            _python_to_dynamodb, datetime.datetime(2012, 05, 31, 12, 0, 0))


class TestGetDefaultValue(unittest.TestCase):
    @mock.patch("dynamodb_mapper.model.datetime")
    def test_datetime(self, m_datetime):
        # Plain default date should be now
        m_datetime.now.return_value = now = datetime.datetime.now(tz=utc_tz)
        self.assertEquals(
            now,
            _get_default_value(m_datetime))
        self.assertEquals(utc_tz.tzname(now), "UTC")

        # default date with supplied fallback
        fallback = datetime.datetime(2012, 05, 31, 12, 0, 0, tzinfo=utc_tz)
        self.assertEquals(
            fallback,
            _get_default_value(datetime.datetime, fallback))

    def test_int(self):
        # Plain default int
        self.assertEquals(0, _get_default_value(int))
        # Default int with fallback
        self.assertEquals(42, _get_default_value(int, 42))
        # Default int with callable fallback
        self.assertEquals(42, _get_default_value(int, return_42))

    def test_incompatible_types_crash_constant(self):
        # Default unicode with int fallback should fail
        self.assertRaises(
            TypeError,
            _get_default_value,
            unicode, 42
        )

    def test_incompatible_types_crash_callable(self):
        # Default unicode with callable int fallback should fail
        self.assertRaises(
            TypeError,
            _get_default_value,
            unicode, return_42
        )


class TestDynamoDBModel(unittest.TestCase):
    def setUp(self):
        ConnectionBorg()._connections.clear()

    def tearDown(self):
        ConnectionBorg()._connections.clear()

    def test_to_json_dict(self):
        testdate = datetime.datetime(2012, 5, 31, 12, 0, 0, tzinfo=utc_tz)
        testSet = set(["level 52","level 1"])

        d = ToJsonTest()
        d.id = 42
        d.set = testSet
        d.date = testdate

        d_dict = d.to_json_dict()
        self.assertEquals(d_dict["id"], 42)
        self.assertEquals(d_dict["set"], sorted(testSet))
        self.assertEquals(d_dict["date"], testdate.astimezone(utc_tz).isoformat())

    def test_build_default_values(self):
        d = DoomEpisode()
        self.assertEquals(d.id, 0)
        self.assertEquals(d.name, u"")

        # Using to_json_dict because _to_db_dict omits empty values
        d_dict = d.to_json_dict()
        self.assertEquals(d_dict["id"], d.id)
        self.assertEquals(d_dict["name"], d.name)

    @mock.patch("dynamodb_mapper.model._get_default_value")
    def test_build_default_values_with_defaults(self, m_defaulter):
        m_defaulter.return_value = u"weak"
        d = PlayerStrength()

        m_defaulter.assert_called_with(unicode, u"weak")
        self.assertEquals(d.strength, u"weak")

    def test_init_from_args(self):
        d = DoomEpisode(id=1, name=u"Knee-deep in the Dead")
        self.assertEquals({}, d._raw_data)
        self.assertEquals(1, d.id)
        self.assertEquals(u"Knee-deep in the Dead", d.name)

    def test_build_from_dict(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        d_dict = {"id": 1, "name": "Knee-deep in the Dead"}
        d = DoomEpisode._from_db_dict(d_dict)
        self.assertEquals(d_dict, d._raw_data)
        self.assertEquals(d_dict["id"], d.id)
        self.assertEquals(d_dict["name"], d.name)

    def test_build_from_dict_missing_attrs(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        d = DoomCampaign._from_db_dict({})
        self.assertEquals(d.id, 0)
        self.assertEquals(d.name, u"")
        self.assertEquals(d.cheats, set())

    def test_build_from_dict_json_list(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        attacks = [
            {'name': 'fireball', 'damage': 10},
            {'name': 'punch', 'damage': 5}
        ]

        m = DoomMonster._from_db_dict({
            "id": 1,
            "attacks": json.dumps(attacks, sort_keys=True)
        })

        self.assertEquals(m.attacks, attacks)

        # Test default values
        m2 = DoomMonster._from_db_dict({"id": 1})
        self.assertEquals(m2.attacks, [])

    def test_build_from_dict_json_dict(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        monsters = {
            "cacodemon": [
                {"x": 10, "y": 20},
                {"x": 10, "y": 30}
            ],
            "imp": [],
            "cyberdemon": []
        }

        e = DoomMonsterMap._from_db_dict({
            "map_id": 1,
            "monsters": json.dumps(monsters, sort_keys=True)
        })
        self.assertEquals(e.monsters, monsters)

        e2 = DoomMonsterMap._from_db_dict({"map_id": 1})
        self.assertEquals(e2.monsters, {})

    def test_build_from_db_dict(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        d_dict = {"id": 1, "name": "Knee-deep in the Dead"}
        d = DoomEpisode._from_db_dict(d_dict)
        self.assertEquals(d_dict, d._raw_data)

    def test_build_from_db_dict_json_dict(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        monsters = {
            "cacodemon": [
                {"x": 10, "y": 20},
                {"x": 10, "y": 30}
            ],
            "imp": [],
            "cyberdemon": []
        }

        raw_dict = {
            "map_id": 1,
            "monsters": json.dumps(monsters, sort_keys=True)
        }

        e = DoomMonsterMap._from_db_dict(raw_dict)
        self.assertEquals(e.monsters, monsters)
        self.assertEquals(raw_dict["map_id"], e._raw_data["map_id"])
        self.assertEquals(raw_dict["monsters"], e._raw_data["monsters"])

    def test_to_db_dict_json_list(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        attacks = [
            {'name': 'fireball', 'damage': 10},
            {'name': 'punch', 'damage': 5}
        ]

        m = DoomMonster()
        m.id = 1
        m.attacks = attacks

        d = m._to_db_dict()

        self.assertEquals(d["id"], 1)
        self.assertEquals(d["attacks"], json.dumps(attacks, sort_keys=True))

    def test_to_db_dict_json_dict(self):
        #FIXME: can it be removed as this feature is implicitly tested elsewhere ?
        monsters = {
            "cacodemon": [
                {"x": 10, "y": 20},
                {"x": 10, "y": 30}
            ],
            "imp": [],
            "cyberdemon": []
        }

        e = DoomMonsterMap()
        e.map_id = 1
        e.monsters = monsters

        d = e._to_db_dict()

        self.assertEquals(d["map_id"], 1)
        self.assertEquals(d["monsters"], json.dumps(monsters, sort_keys=True))


    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_simple_types(self, m_boto, m_item):
        DoomEpisode().save()

        m_item.return_value.put.assert_called_once()

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_sets(self, m_boto, m_item):
        l = DoomCampaign()
        l.id = 1
        l.name = "Knee-deep in the Dead"
        l.cheats = set(["iddqd", "idkfa", "idclip"])
        l.save()

        m_item.assert_called_once_with(
            mock.ANY, attrs={"id": l.id, "name": l.name, "cheats": l.cheats})

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_empty_sets(self, m_boto, m_item):
        l = DoomCampaign()
        l.id = 1
        l.cheats = set()
        l.save()

        m_item.assert_called_once_with(mock.ANY, attrs={"id": 1})

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_empty_strings(self, m_boto, m_item):
        e = DoomEpisode()
        e.id = 0
        e.save()

        m_item.assert_called_once_with(mock.ANY, attrs={"id": 0})

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_get_by_hash_key(self, m_get_table):
        m_table = m_get_table.return_value

        DoomEpisode.get(1)
        m_table.get_item.assert_called_once_with(hash_key=1, range_key=None, consistent_read=False)

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_get_by_composite_key(self, m_get_table):
        m_table = m_get_table.return_value

        DoomMap.get(1, "Knee-deep in the dead")
        m_table.get_item.assert_called_once_with(
            hash_key=1, range_key="Knee-deep in the dead", consistent_read=False)

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_get_by_hash_key_magic_types(self, m_get_table):
        m_table = m_get_table.return_value
        d = datetime.datetime(2012, 5, 31, 12, 0, 0, tzinfo=utc_tz)
        d_text = "2012-05-31T12:00:00.000000+00:00"
        m_table.get_item.return_value = {"datetime": d_text}

        p = Patch.get(d)
        self.assertEquals(d_text, p._raw_data["datetime"])
        m_table.get_item.assert_called_once_with(
            hash_key=d_text, range_key=None, consistent_read=False)

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_get_by_composite_key_magic_types(self, m_get_table):
        m_table = m_get_table.return_value
        d = datetime.datetime(2012, 5, 31, 12, 0, 0, tzinfo=utc_tz)
        d_text = "2012-05-31T12:00:00.000000+00:00"
        players = ["duke", "doomguy", "blackowicz"]
        players_text = json.dumps(players)
        m_table.get_item.return_value = {
            "player_ids": players_text,
            "datetime": d_text
        }

        r = GameReport.get(players, d)
        self.assertEquals(d_text, r._raw_data["datetime"])
        self.assertEquals(players_text, r._raw_data["player_ids"])
        m_table.get_item.assert_called_once_with(
            hash_key=players_text, range_key=d_text, consistent_read=False)

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_autoincrement_int(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        m_item_instance.hash_key_name = "id"
        max_item = m_item_instance.table.new_item.return_value

        max_item.save.return_value = {
            'Attributes': {
                '__max_hash_key__': 3
            }
        }

        l = LogEntry()
        l.text = "Everybody's dead, Dave."
        l.save()

        m_item.assert_called_with(mock.ANY, attrs={"id": 0, "text": l.text})
        m_item.return_value.__setitem__.assert_called_with("id", 3)
        m_item_instance.save.assert_called()

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_autoincrement_int_conflict(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        m_item_instance.hash_key_name = "id"
        max_item = m_item_instance.table.new_item.return_value

        max_item.save.return_value = {
            'Attributes': {
                '__max_hash_key__': 3
            }
        }

        # The first call (id=3) will be rejected.
        error = DynamoDBResponseError(
            None, None, {"__type": "ConditionalCheckFailedException"})

        def err(*args, **kw):
            # Clear the error then fail
            m_item_instance.put.side_effect = None
            raise error

        m_item_instance.put.side_effect = err

        l = LogEntry()
        l.text = "Everybody's dead, Dave."
        l.save()

        m_item.return_value.__setitem__.assert_called_with("id", 3)
        self.assertEquals(m_item.return_value.__setitem__.call_count, 2)

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_autoincrement_int_max_retries(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        m_item_instance.hash_key_name = "id"
        max_item = m_item_instance.table.get_item.return_value
        max_item.__getitem__.return_value = 2
        error = DynamoDBResponseError(
            None, None, {"__type": "ConditionalCheckFailedException"})
        # the put call will never succeed
        m_item_instance.put.side_effect = error

        l = LogEntry()
        l.text = "Everybody's dead, Dave."
        self.assertRaises(MaxRetriesExceededError, l.save)

        self.assertEquals(m_item_instance.put.call_count, MAX_RETRIES)

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_autoincrement_int_unhandled_exception(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        m_item_instance.hash_key_name = "id"
        max_item = m_item_instance.table.get_item.return_value
        max_item.__getitem__.return_value = 2
        error = DynamoDBResponseError(
            None, None, {"__type": "ResourceNotFoundException"})
        # the put call will note succeed
        m_item_instance.put.side_effect = error

        l = LogEntry()
        l.text = "Everybody's dead, Dave."
        self.assertRaises(DynamoDBResponseError, l.save)

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_autoincrement_magic_overwrite(self, m_boto, m_item):
        l = LogEntry()
        l.text = "Everybody's dead, Dave."
        l.id = MAGIC_KEY

        self.assertRaises(SchemaError, l.save)

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_raise_on_conflict(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        error = DynamoDBResponseError(
            None, None, {"__type": "ConditionalCheckFailedException"})
        m_item_instance.put.side_effect = error

        name = "Knee-deep in the Dead"
        cheats = set(["iddqd", "idkfa"])

        c = DoomCampaign()

        c._raw_data["id"] = 1
        c._raw_data["name"] = name
        #simulate empty field in DB
        #c._raw_data["cheats"] = cheats

        c.id = 1
        c.name = name
        c.cheats = cheats

        self.assertRaises(ConflictError, c.save, raise_on_conflict=True)
        m_item_instance.put.assert_called_with({"id": 1, "name": name, "cheats": False})

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_raise_on_conflict_boolean(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        error = DynamoDBResponseError(
            None, None, {"__type": "ConditionalCheckFailedException"})
        m_item_instance.put.side_effect = error

        name = "Knee-deep in the Dead"
        completed = False

        c = DoomCampaignStatus()

        c._raw_data["id"] = 1
        c._raw_data["name"] = name
        c._raw_data["completed"] = int(False) # DynamoDB stores int and unicode only

        c.id = 0
        c.name = name
        c.completed = completed

        self.assertRaises(ConflictError, c.save, raise_on_conflict=True)
        m_item_instance.put.assert_called_with({"id": 1, "name": name, "completed": 0})

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_no_overwrite_composite_fails(self, m_boto, m_item):
        """Save raised OverwriteError when new object has the same ID"""
        m_item_instance = m_item.return_value
        error = DynamoDBResponseError(
            None, None, {"__type": "ConditionalCheckFailedException"})
        m_item_instance.put.side_effect = error

        c = DoomMap()
        c.episode_id = 0
        c.name = "Knee-deep in the Dead"

        self.assertRaises(
            OverwriteError,
            c.save, raise_on_conflict=True
        )
        m_item_instance.put.assert_called_with({"episode_id": False, "name": False})

    @mock.patch("dynamodb_mapper.model.Item")
    @mock.patch("dynamodb_mapper.model.boto")
    def test_save_unhandled_exception(self, m_boto, m_item):
        m_item_instance = m_item.return_value
        error = DynamoDBResponseError(
            None, None, {"__type": "ResourceNotFoundException"})
        m_item_instance.put.side_effect = error

        c = DoomMap()
        c.episode_id = 0
        c.name = "Knee-deep in the Dead"

        self.assertRaises(DynamoDBResponseError, c.save)

    @mock.patch("dynamodb_mapper.model.boto")
    def test_get_batch_hash_key(self, m_boto):
        m_batch_list = m_boto.connect_dynamodb.return_value.new_batch_list.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value
        # Mock empty answer as we only observe the way the request is build
        # FIXME: make sure _raw_data is filled
        m_batch_list.submit.return_value = {
            u"Responses": {
                DoomEpisode.__table__: {
                    u"Items": []
                }
            }
        }

        DoomEpisode.get_batch(range(2));
        m_batch_list.add_batch.assert_called_with(m_table, [0,1])
        assert m_batch_list.submit.called

    @mock.patch("dynamodb_mapper.model.boto")
    def test_get_batch_hash_range_key(self, m_boto):
        m_batch_list = m_boto.connect_dynamodb.return_value.new_batch_list.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value
        # Mock empty answer as we only observe the way the request is build
        # FIXME: make sure _raw_data is filled
        m_batch_list.submit.return_value = {
            u"Responses": {
                DoomMap.__table__: {
                    u"Items": []
                }
            }
        }

        DoomMap.get_batch([(0, u"level1"), (1, u"level2")]);
        m_batch_list.add_batch.assert_called_with(m_table, [(0, u'level1'), (1, u'level2')])
        assert m_batch_list.submit.called

    def test_get_batch_over_100(self):
        self.assertRaises(
            ValueError,
            DoomEpisode.get_batch,
            range(101)
        )

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_query(self, m_get_table):
        m_table = m_get_table.return_value
        m_table.query.return_value = []
        # FIXME: make sure _raw_data is filled

        from boto.dynamodb import condition
        DoomMap.query(1, condition.BEGINS_WITH(u"level"), True)

        m_table.query.assert_called_with(1, condition.BEGINS_WITH(u"level"), consistent_read=True, scan_index_forward=True, max_results=None)

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_query_reverse_limit(self, m_get_table):
        m_table = m_get_table.return_value
        m_table.query.return_value = []

        from boto.dynamodb import condition
        DoomMap.query(1, condition.BEGINS_WITH(u"level"), True, reverse=True, limit=42)

        m_table.query.assert_called_with(1, condition.BEGINS_WITH(u"level"), consistent_read=True, scan_index_forward=False, max_results=42)

    @mock.patch("dynamodb_mapper.model.ConnectionBorg.get_table")
    def test_scan(self, m_get_table):
        # FIXME: test the generator. autoinc keys should be hidden from the results
        # FIXME: make sure _raw_data is filled
        m_table = m_get_table.return_value
        m_table.scan.return_value = []

        from boto.dynamodb import condition
        scan_filter = {
            'name': condition.BEGINS_WITH(u"level")
        }
        DoomEpisode.scan(scan_filter)

        m_table.scan.assert_called_with(scan_filter)

    @mock.patch("dynamodb_mapper.model.boto")
    @mock.patch("dynamodb_mapper.model.Item")
    def test_delete_hash_key(self, m_item, m_boto):
        m_item_instance = m_item.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value

        python_date = datetime.datetime(2012, 05, 31, 12, 0, 0, tzinfo=utc_tz)
        dynamodb_date = _python_to_dynamodb(python_date)

        raw_data = {
            u"datetime":dynamodb_date
        }

        # Simulate obj from DB
        d = Patch._from_db_dict(raw_data)

        d.delete()

        self.assertEquals(d._raw_data, {})
        m_item.assert_called_once_with(m_table, dynamodb_date, None)
        assert m_item_instance.delete.called

    @mock.patch("dynamodb_mapper.model.boto")
    @mock.patch("dynamodb_mapper.model.Item")
    def test_delete_composite_keys(self, m_item, m_boto):
        m_item_instance = m_item.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value

        raw_data = {
            u"episode_id": 42,
            u"name": "level super geek"
        }

        # Simulate obj from DB, composite keys
        d = DoomMap._from_db_dict(raw_data)

        d.delete()

        self.assertEquals(d._raw_data, {})
        m_item.assert_called_once_with(m_table, 42, "level super geek")
        assert m_item_instance.delete.called

    @mock.patch("dynamodb_mapper.model.boto")
    @mock.patch("dynamodb_mapper.model.Item")
    def test_delete_new_object_roc(self, m_item, m_boto):
        m_item_instance = m_item.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value

        # Create a new object
        d = DoomEpisode()
        d.id = "42"

        self.assertRaises(
            ConflictError,
            d.delete,
            raise_on_conflict=True
        )

        self.assertEquals(d._raw_data, {}) #still "new"

    @mock.patch("dynamodb_mapper.model.boto")
    @mock.patch("dynamodb_mapper.model.Item")
    def test_delete_object_roc(self, m_item, m_boto):
        m_item_instance = m_item.return_value
        m_table = m_boto.connect_dynamodb.return_value.get_table.return_value
        m_item_instance.delete.side_effect = DynamoDBConditionalCheckFailedError(404, "mock")

        raw_data = {
            u"episode_id": 42,
            u"name": "level super geek"
        }

        # Simulate obj from DB
        d = DoomMap._from_db_dict(raw_data)

        self.assertRaises(
            ConflictError,
            d.delete,
            raise_on_conflict=True
        )

        m_item_instance.delete.assert_called_with({
            u'name': 'level super geek',
            u'episode_id': 42,
            u'world': False
        })

        self.assertEquals(d._raw_data, raw_data) #no change
