"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, datetime, pymongo, traceback, socket, warnings

warnings.simplefilter( 'ignore', DeprecationWarning )

blockingStatsAgentVersion = "1.5.7"

class BlockingMongoStatsThread( threading.Thread ):
    """ Pull the blocking data from the various hosts. """

    def __init__( self, hostKey, mmsAgent):
        """ Initialize the object """

        self.hostKey = hostKey
        self.mmsAgent = mmsAgent
        self.logger = mmsAgent.logger
        self.slowDbStats = False
        self.lastDbStatsCheck = time.time()
        self.running = True
        self.host = mmsAgent.extractHostname( hostKey )
        self.port = mmsAgent.extractPort( hostKey )

        threading.Thread.__init__( self )

    def stopThread( self ):
        """ Stop the thread """
        self.running = False

    def run( self ):
        """ Pull the data from the various hosts. """

        self.logger.info( 'starting blocking stats monitoring: ' + self.hostKey )

        sleepTime = ( self.mmsAgent.collectionInterval / 2 ) - 1

        if ( sleepTime < 1 ):
            sleepTime = 1

        monitorConn = None

        passes = 0

        while not self.mmsAgent.done and self.running:
            try:
                time.sleep( sleepTime )
                passes = passes + 1

                if passes % 60 == 0:
                    monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

                if not monitorConn:
                    monitorConn = self.mmsAgent.getDbConnection( self.hostKey )

                if not self._collectBlockingStats( passes, monitorConn ):
                    monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

            except Exception, e:
                monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )
                self.logger.error( 'Problem collecting blocking data from: ' + self.hostKey + " - exception: " + traceback.format_exc( e ) )

        self.logger.info( 'stopping blocking stats monitoring: ' + self.hostKey )
        self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

    def _collectBlockingStats( self, passes, monitorConn ):
        """ Collect the blocking stats from the hosts """

        try:
            if not self.mmsAgent.haveHostDef( self.hostKey ):
                return False

            # Close the connection once per hour
            # Verify the connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, monitorConn ):
                return False

            stats = self._collectStats( passes, monitorConn )

            try:
                stats['hostIpAddr'] = socket.gethostbyname(self.hostKey[0 : self.hostKey.find( ':' )])
            except Exception, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'hostIpAddr', e )

            stats['host'] = self.host
            stats['port'] = self.port

            # Make sure we ended up with the same connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, monitorConn ):
                return False

            self.mmsAgent.setHostState( self.hostKey, 'mongoBlocking', stats )

            return True

        except Exception, e:
            self.logger.error( 'Problem collecting blocking data from (check if it is up and DNS): ' + self.hostKey + " - exception: " + traceback.format_exc( e ) )
            return False

    def _collectStats( self, passes, monitorConn ):
        """ Make the call to mongo host and collect the blocking data """
        root = {}

        # Set the agent version and hostname.
        root['agentVersion'] = self.mmsAgent.agentVersion
        root['agentHostname'] = self.mmsAgent.agentHostname

        isMaster = monitorConn.admin.command( 'ismaster' )
        root['isMaster'] = isMaster

        isMongos = ( 'msg' in isMaster and isMaster['msg'] == 'isdbgrid' )

        # Check to see if this is a mongod host
        try:
            if isMaster['ismaster'] == True and isMongos:
                # Look at the shards
                root['shards'] = list( monitorConn.config.shards.find() )

                # Pull from config.locks
                try:
                    root['locks'] = list( monitorConn.config.locks.find( limit=200, sort=[ ( "$natural" , pymongo.DESCENDING ) ]) )
                except Exception, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'config.locks.find', e )

                # Pull from config.collections if enabled
                try:
                    if self.mmsAgent.settings.configCollectionsEnabled:
                        root['configCollections'] = list( monitorConn.config.collections.find( limit=200, sort=[ ( "$natural" , pymongo.DESCENDING ) ] ) )
                except Exception, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'config.collections.find', e )

                # Pull from config.databases if enabled
                try:
                    if self.mmsAgent.settings.configDatabasesEnabled:
                        root['configDatabases'] = list( monitorConn.config.databases.find( limit=200, sort=[ ( "$natural" , pymongo.DESCENDING ) ] ) )
                except Exception, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'config.databases.find', e )

                try:
                    root['configLockpings'] = list( monitorConn.config.lockpings.find( limit=200, sort=[ ( "$natural" , pymongo.DESCENDING ) ] ) )
                except Exception, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'config.lockpings.find', e )

                # Look at the mongos instances - only pull hosts that have a ping time
                # updated in the last twenty minutes (and max 1k).
                queryTime = datetime.datetime.utcnow() - datetime.timedelta( seconds=1200 )
                root['mongoses'] = list( monitorConn.config.mongos.find( { 'ping' : { '$gte' : queryTime } } ).limit( 1000 ) )

                # Get the shard chunk counts.
                shardChunkCounts = []
                positions =  { }
                counter = 0

                if passes % 10 == 0:
                    for chunk in monitorConn.config.chunks.find():
                        key = chunk['ns'] + chunk['shard']
                        if key not in positions:
                            count = {}
                            positions[key] = counter
                            shardChunkCounts.append( count )
                            counter = counter + 1
                            count['count'] = 0
                            count['ns'] = chunk['ns']
                            count['shard'] = chunk['shard']

                        shardChunkCounts[positions[key]]['count'] = shardChunkCounts[positions[key]]['count'] + 1

                    root['shardChunkCounts'] = shardChunkCounts
        except pymongo.errors.OperationFailure:
            pass

        root['serverStatus'] = monitorConn.admin.command( 'serverStatus' )

        isReplSet = False
        isArbiter = False

        if 'repl' in root['serverStatus']:
            #  Check to see if this is a replica set
            try:
                root['replStatus'] = monitorConn.admin.command( 'replSetGetStatus' )
                if root['replStatus']['myState'] == 7:
                    isArbiter = True

                isReplSet = True
            except pymongo.errors.OperationFailure:
                pass

            if isReplSet:
                oplog = "oplog.rs"
            else:
                oplog = "oplog.$main"

            try:
                root['localSystemReplSet'] = monitorConn.local.system.replset.find_one()
            except pymongo.errors.OperationFailure, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'local.system.replset.findOne', e )

            localConn = monitorConn.local

            oplogStats = {}

            #  Get oplog status
            if isArbiter:
                # Do nothing for the time being
                pass
            elif isMaster['ismaster'] == True or isReplSet:
                try:
                    oplogStats["start"] = localConn[oplog].find( limit=1, sort=[ ( "$natural" , pymongo.ASCENDING ) ], fields={ 'ts' : 1 }  )[0]["ts"]

                    oplogStats["end"] = localConn[oplog].find( limit=1, sort=[ ( "$natural" , pymongo.DESCENDING ) ], fields={ 'ts' : 1} )[0]["ts"]

                    oplogStats['rsStats'] = localConn.command( {'collstats' : 'oplog.rs' } )

                except pymongo.errors.OperationFailure, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'local.' + oplog + '.find', e )
            else:
                # Slave
                try:
                    oplogStats["sources"] = {}
                    for s in localConn.sources.find():
                        oplogStats["sources"][s["host"]] = s
                except pymongo.errors.OperationFailure, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'local.sources.find', e )

            root["oplog"] = oplogStats

        # Load the config.gettings collection (balancer info etc.)
        if not isArbiter:
            try:
                root['configSettings'] = list( monitorConn.config.settings.find() )
            except Exception, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'config.settings.find', e )

        # per db info - mongos doesn't allow calls to local
        root['databases'] = { }
        root['dbProfiling'] = { }
        root['dbProfileData'] = { }

        profilerEnabled = self.mmsAgent.hostDefValue( self.hostKey, 'profiler' )

        if ( passes % 20 == 0 or profilerEnabled ) and not isArbiter and not isMongos:

            count = 0
            for x in monitorConn.database_names():
                try:
                    if passes % 20 == 0:
                        if self.slowDbStats and ( ( time.time() - self.lastDbStatsCheck ) < 7200 ):
                            continue

                        if not self.mmsAgent.disableDbstats:

                            count += 1

                            if count > 100:
                                break

                            startTime = time.time()

                            temp = monitorConn[x].command( 'dbstats' )
                            # work around Python 2.4 and older bug
                            for f in temp:
                                # this is super hacky b/c of Python 2.4
                                if isinstance( temp[f] , (int, long, float, complex)) and str(temp[f]) == "-inf":
                                    temp[f] = 0
                            root['databases'][x] = temp

                            if ( time.time() - startTime ) > 6:
                                self.slowDbStats = True
                            else:
                                self.slowDbStats = False

                            self.lastDbStatsCheck = time.time()

                    # If the profiler is enabled in MMS, collect data
                    if profilerEnabled and not isArbiter and not self.mmsAgent.settings.disableProfileDataCollection:
                        try:
                            # Get the most recent entries.
                            profileData = list( monitorConn[x].system.profile.find( spec=None, fields=None, skip=0, limit=20, sort=[ ( "$natural", pymongo.DESCENDING ) ] ) )

                            if len( profileData ) > 0:
                                root['dbProfileData'][x] = profileData
                        except Exception, e:
                            self.mmsAgent.handleOperationFailure( self.hostKey, 'system.profile.find-' + x, e )

                    # Check to see if the profiler is enabled
                    try:
                        profiling = monitorConn[x].command( { 'profile' : -1 } )
                        if profiling is not None and 'ok' in profiling:
                            del profiling['ok']
                        root['dbProfiling'][x] = profiling
                    except Exception:
                        pass

                except:
                    continue

        if 'serverStatus' in root:
            del root['serverStatus']

        return root

