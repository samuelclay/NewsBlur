def get_cache_key_for_pk(model, pk):
    return '%s:%s' % (model._meta.db_table, pk)
