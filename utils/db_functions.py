import pymongo

PRIMARY_STATE = 1
SECONDARY_STATE = 2

def mongo_max_replication_lag(connection):
    try:
        status = connection.admin.command('replSetGetStatus')
    except pymongo.errors.OperationFailure:
        return 0
        
    members = status['members']
    primary_optime = None
    oldest_secondary_optime = None
    for member in members:
        member_state = member['state']
        optime = member['optime']
        if member_state == PRIMARY_STATE:
            primary_optime = optime.time
        elif member_state == SECONDARY_STATE:
            if not oldest_secondary_optime or optime.time < oldest_secondary_optime:
                oldest_secondary_optime = optime.time

    if not primary_optime or not oldest_secondary_optime:
        return 0

    return primary_optime - oldest_secondary_optime