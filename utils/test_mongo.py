from mongoengine.connection import connect, disconnect


def configure_test_mongo_connection(settings_obj, aliases=("default", "test")):
    mongo_config = dict(getattr(settings_obj, "MONGO_DB", {}))
    db_name = mongo_config.pop("name", getattr(settings_obj, "MONGO_DB_NAME", "newsblur_test"))
    mongo_config.pop("alias", None)
    mongo_config.setdefault("connect", False)
    mongo_config.setdefault("unicode_decode_error_handler", "ignore")

    for alias in aliases:
        try:
            disconnect(alias=alias)
        except Exception:
            pass

    settings_obj.MONGO_DB_NAME = db_name
    settings_obj.MONGODB = connect(db_name, alias="default", **mongo_config)

    if "test" in aliases:
        connect(db_name, alias="test", **mongo_config)

    return db_name
