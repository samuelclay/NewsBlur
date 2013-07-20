"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import pymongo, munin, nonBlockingStats, blockingStats, getLogs, traceback

# Mongo
import bson

# Python
import threading, urllib, urllib2, socket, zlib, time, sets, re, gc

mmsAgentVersion = "1.5.7"

class MmsAgent( object ):
    """ The mms agent object """

    def __init__( self, settings, agentVersion, pythonVersion, pymongoVersion, pymongoHasC, agentHostname, logger, sessionKey ):
        """ Constructor """
        self.logger = logger

        self.sessionKey = sessionKey

        self.settings = settings

        self.pythonVersion = pythonVersion
        self.pymongoVersion = pymongoVersion
        self.pymongoHasC = pymongoHasC
        self.agentHostname = agentHostname
        self.agentVersion = agentVersion
        self.srcVersion = self.settings.src_version

        self.collectionInterval = settings.collection_interval
        self.logCollectionInterval = settings.log_interval
        self.confInterval  = settings.conf_interval

        self.disableProfileDataCollection = settings.disableProfileDataCollection
        self.disableGetLogsDataCollection = settings.disableGetLogsDataCollection

        self.hostStateLock = threading.Lock()
        self.hostState = { }
        self.hostStateLastUpdate = { }

        self.operationFailureUrl  = settings.operationFailureUrl % settings.mms_key

        self.serverHostDefs = { }
        self.serverHostDefsLock = threading.Lock()

        self.serverUniqueHosts = { }
        self.serverUniqueHostsLock = threading.Lock()

        self.pingUrl = settings.ping_url % settings.mms_key

        self.disableDbstats = False

        self.done = False

        socket.setdefaulttimeout( settings.socket_timeout )

    def closeDbConnection( self, hostKey, connection ):
        """ Close the connection and reset """
        self.serverHostDefsLock.acquire()
        try:
            try:
                if hostKey in self.serverHostDefs:
                    if 'availableCmds' in self.serverHostDefs[hostKey]:
                        del self.serverHostDefs[hostKey]['availableCmds']
            except:
                pass
        finally:
            self.serverHostDefsLock.release()

        if connection is not None:
            try:
                connection.disconnect()
            except:
                pass

        return None

    def getDbConnection( self, hostKey ):
        """ Returns a database connection """

        hostDef = None
        self.serverHostDefsLock.acquire()
        try:
            if hostKey in self.serverHostDefs:
                hostDef = self.serverHostDefs[hostKey]

        finally:
            self.serverHostDefsLock.release()

        if not hostDef:
            return None

        if not self.settings.useSslForAllConnections:
            useSsl = False
            if 'ssl' in hostDef:
                useSsl = hostDef['ssl']

            if useSsl:
                return pymongo.Connection( hostDef['mongoUri'] , slave_okay=True, ssl=True, document_class=bson.son.SON )
            else:
                return pymongo.Connection( hostDef['mongoUri'] , slave_okay=True, document_class=bson.son.SON )
        else:
            return pymongo.Connection( hostDef['mongoUri'] , slave_okay=True, ssl=True, document_class=bson.son.SON )

    def handleOperationFailure( self, hostKey, operation, exception ):
        """ Process a query or command operation failure """
        try:
            msg = { }

            exceptionStr = traceback.format_exc( exception )

            # These are excpected and we do not need to log.
            if exceptionStr.find( 'unrecognized command:' ) > -1:
                return

            if exceptionStr.find( 'failed: not running with --replSet' ) > -1:
                return

            if exceptionStr.find( 'failed: ns not found' ) > -1:
                return

            if exceptionStr.find( 'not master or secondary' ) > -1:
                return

            msg['hostnameAndPort'] = hostKey
            msg['operation'] = operation
            msg['exception'] = exceptionStr

            res = None
            try:
                res = urllib2.urlopen( self.operationFailureUrl, bson.binary.Binary( bson.BSON.encode( msg, check_keys=False ) ) )
                res.read()
            finally:
                if res is not None:
                    res.close()
        except:
            pass

    def haveHostDef( self, hostKey ):
        """ Returns true if this is a known host """
        self.serverHostDefsLock.acquire()
        try:
            return hostKey in self.serverHostDefs
        finally:
            self.serverHostDefsLock.release()

    def _removeHostState( self, hostKey ):
        """ Delete the state for a host """
        self.hostStateLock.acquire()
        try:
            if hostKey in self.hostState:
                del self.hostState[hostKey]
        finally:
            self.hostStateLock.release()

    def extractHostname( self, hostKey ):
        """ Extract the hostname from the hostname:port hostKey """
        return hostKey[0 : hostKey.find( ':' )]

    def extractPort( self, hostKey ):
        """ Extract the port from the hostname:port hostKey """
        return int( hostKey[ ( hostKey.find(':' ) + 1 ) : ] )

    def setMuninHostState( self, hostname, state ):
        """ Set the state inside of the lock - there are multiple threads who set state here """
        if state is None:
            return

        # Compress only once for munin data
        stateData = bson.binary.Binary( zlib.compress( bson.BSON.encode( state, check_keys=False ), 9 ) )

        try:
            self.hostStateLock.acquire()

            for hostKey in self.hostState.keys():
                if hostname == self.extractHostname( hostKey ):
                    state['port'] = self.extractPort( hostKey )
                    self._setHostStateValue( hostKey, 'munin', stateData )
        finally:
            self.hostStateLock.release()

    def cleanHostState( self ):
        """ Make sure the host state data is current """
        try:
            self.hostStateLock.acquire()
            now = time.time()

            toDel = []

            for hostKey in self.hostState:
                if hostKey not in self.hostStateLastUpdate:
                    continue

                if ( now - self.hostStateLastUpdate[hostKey] ) > 60:
                    toDel.append( hostKey )

            for hostKey in toDel:
                del self.hostState[hostKey]

        finally:
            self.hostStateLock.release()

    def setHostState( self, hostKey, stateType, state ):
        """ Set the state inside of the lock - there are multiple threads who set state here """
        if state is None:
            return

        try:
            self.hostStateLock.acquire()
            self._setHostStateValue( hostKey, stateType, state )
        finally:
            self.hostStateLock.release()

    def _setHostStateValue( self, hostKey, stateType, state):
        """ Set the host state. This can only be called when a host state lock is in place """

        if hostKey not in self.hostState:
            self.hostState[hostKey] = { }

        if stateType == 'logs':
            if 'logs' not in self.hostState[hostKey] or self.hostState[hostKey][stateType] is None:
                self.hostState[hostKey][stateType] = []

            self.hostState[hostKey][stateType].append(bson.binary.Binary( zlib.compress( bson.BSON.encode( state, check_keys=False ), 9 ) ) )

        elif stateType == 'munin':

            self.hostState[hostKey][stateType] = state

        else:
            self.hostState[hostKey][stateType] = bson.binary.Binary( zlib.compress( bson.BSON.encode( state, check_keys=False ), 9 ) )

        self.hostStateLastUpdate[hostKey] = time.time()

    def checkChangedHostDef( self, hostDef, hostDefLast ):
        """ Check to see if this host definition has changed. If it has, stop the thread and
        start a new one. This assumes it is called inside of serverHostDefsLock """

        if not hostDefLast:
            return

        hostKey = hostDef['hostKey']

        changed = False

        # The ssl configuration
        if hostDef['ssl'] and not hostDefLast['ssl']:
            changed = True

        if not hostDef['ssl'] and hostDefLast['ssl']:
            changed = True

        # The profiler configuration
        if not self.disableProfileDataCollection and hostDef['profiler'] and not hostDefLast['profiler']:
            changed = True

        if not self.disableProfileDataCollection and not hostDef['profiler'] and hostDefLast['profiler']:
            changed = True

        # The getLogs configuration
        if not self.disableProfileDataCollection and hostDef['getLogs'] and not hostDefLast['getLogs']:
            changed = True

        if not self.disableProfileDataCollection and not hostDef['getLogs'] and hostDefLast['getLogs']:
            changed = True

        # The mongo URI configuration
        if hostDef['mongoUri'] != hostDefLast['mongoUri']:
            changed = True

        hostDefLast = None

        if not changed:
            return

        self.stopAndClearHost( hostKey )

        # Start the new thread and set the host def.
        self.startMonitoringThreads( hostDef )

    def hostDefValue( self, hostKey, key ):
        """ Returns the host def value """

        hostDef = None
        self.serverHostDefsLock.acquire()
        try:
            if hostKey in self.serverHostDefs:
                hostDef = self.serverHostDefs[hostKey]
        finally:
            self.serverHostDefsLock.release()

        if not hostDef or key not in hostDef:
            return None

        return hostDef[key]

    def hasCommand( self, command, hostKey, connection ):
        """ Returns True if this command is contained """
        cmd = command.lower()

        hostDef = None
        self.serverHostDefsLock.acquire()
        try:
            if hostKey in self.serverHostDefs:
                hostDef = self.serverHostDefs[hostKey]
        finally:
            self.serverHostDefsLock.release()

        if not hostDef:
            return False

        if 'availableCmds' in hostDef:
            return cmd in hostDef['availableCmds']

        availableCmds = sets.Set()

        for field, value in connection.admin.command( 'listCommands' )['commands'].items():
            availableCmds.add( field.lower() )

        hostDef['availableCmds'] = availableCmds

        return cmd in hostDef['availableCmds']

    def startMonitoringThreads( self, hostDef ):
        """ Start server status and munin threads. This assumes it is called inside of serverHostDefsLock """

        hostKey = hostDef['hostKey']

        # Start the non-blocking stats thread
        hostDef['nonBlockingStatsThread'] = nonBlockingStats.NonBlockingMongoStatsThread( hostKey, self )
        hostDef['nonBlockingStatsThread'].setName( ( 'NonBlockingMongoStatsThread-' + hostKey ) )
        hostDef['nonBlockingStatsThread'].start()

        # Start the blocking stats thread
        hostDef['blockingStatsThread'] = blockingStats.BlockingMongoStatsThread( hostKey, self )
        hostDef['blockingStatsThread'].setName( ( 'BlockingMongoStatsThread-' + hostKey ) )
        hostDef['blockingStatsThread'].start()

        if not self.disableProfileDataCollection and hostDef['getLogs']:
            hostDef['getLogsThread'] = getLogs.GetLogsThread( hostKey, self )
            hostDef['getLogsThread'].setName( ( 'GetLogsThread-' + hostKey ) )
            hostDef['getLogsThread'].start()

        # Start the munin thread for the server, if there is not one running.
        self._startMuninThread( hostDef['hostname'] )

        self.serverHostDefs[hostDef['hostKey']] = hostDef

    def _startMuninThread( self, hostname ):
        """ Start the munin thread if one is not running """
        if not getattr(self.settings, 'enableMunin', True):
            return

        try:
            self.serverUniqueHostsLock.acquire()
            if hostname not in self.serverUniqueHosts:
                self.serverUniqueHosts[hostname] = munin.MuninThread( hostname, self )
                self.serverUniqueHosts[hostname].setName( ( 'MuninThread-' + hostname ) )
                self.serverUniqueHosts[hostname].start()
        finally:
            self.serverUniqueHostsLock.release()

    def hasUniqueServer( self, hostname ):
        """ Return true if there hostname is in the list """
        try:
            self.serverUniqueHostsLock.acquire()
            return hostname in self.serverUniqueHosts
        finally:
            self.serverUniqueHostsLock.release()

    def extractHostDef( self, host ):
        """ Return the host def for the host """

        hostKey = host['hostKey']

        hostDef = None
        hostDefLast = None

        # Check to see if we already have this object.
        if hostKey not in self.serverHostDefs:
            hostDef = { }
            hostDef['hostname'] = host['hostname']
            hostDef['id'] = host['id']
            hostDef['hostKey'] = host['hostKey']
            hostDef['port'] = host['port']
        else:
            hostDefLast = { }
            hostDef = self.serverHostDefs[hostKey]
            hostDefLast['ssl'] = hostDef['ssl']
            hostDefLast['profiler'] = hostDef['profiler']
            hostDefLast['getLogs'] = hostDef['getLogs']
            hostDefLast['mongoUri'] = hostDef['mongoUri']

        mongoUri = host['uri']

        # Check to see if the global username/password is set in the settings.py file.
        if getattr( self.settings, 'globalAuthUsername', None ) is not None and getattr( self.settings, 'globalAuthPassword', None ) is not None:

            # Assemble the credentials string.
            credentials = '%(username)s:%(password)s' % {
                'username' : urllib.quote_plus( self.settings.globalAuthUsername ),
                'password' : urllib.quote_plus( self.settings.globalAuthPassword )
            }

            if not '@' in mongoUri:
                # This means that we do have an existing password (from the central servers).
                mongoUri = re.sub( '(^mongodb://)(.+)', 'mongodb://' + credentials + '@\\2', mongoUri )
            else:
                # This means a password was sent by the central servers.
                mongoUri = re.sub( '(^mongodb://.+:.+@)(.+)', 'mongodb://' + credentials + '@\\2', mongoUri )

        hostDef['mongoUri'] = mongoUri

        hostDef['munin'] = host['munin']
        hostDef['profiler'] = host['profiler']

        if 'sslEnabled' not in host:
            hostDef['ssl'] = False
        else:
            hostDef['ssl'] = host['sslEnabled']

        if 'getLogs' not in host:
            hostDef['getLogs'] = False
        else:
            hostDef['getLogs'] = host['getLogs']

        return ( hostDef, hostDefLast )

    def isValidMonitorConn( self, hostKey, conn ):
        """ In pymongo <= 1.9, even with slave_okay set, we will re-route to master if the secondary we're talking to goes down - this should work around that """
        if not conn:
            return False

        hostDef = None
        self.serverHostDefsLock.acquire()
        try:
            if hostKey in self.serverHostDefs:
                hostDef = self.serverHostDefs[hostKey]
        finally:
            self.serverHostDefsLock.release()

        if not hostDef:
            return False

        if conn.host is not None:
            if conn.host != hostDef['hostname'] or str( conn.port ) != str( hostDef['port'] ):
                self.logger.warning( 'replica set switched hosts, disconnecting - wanted: ' + str( hostDef['mongoUri'] ) + ' - got: mongodb://' + str( conn.host ) + ':' + str( conn.port ) )
                if conn is not None:
                    conn.disconnect()
                return False
            else:
                return True
        else:
            return True

    def _handleRemote( self, req ):
        """ Send the data to the central MMS servers """
        try:
            if req is None:
                return

            res = None

            try:
                res = urllib2.urlopen( self.pingUrl, req )
                res.read()
            finally:
                if res is not None:
                    res.close()

        except Exception:
            self.logger.warning( "Problem sending data to MMS (check firewall and network)" )

    def _assemblePingRequest( self ):
        """ Create the ping data request """
        try:
            if self.hostState is None:
                return None

            req = { 'key' : self.settings.mms_key, 'hosts' : self.hostState }

            req['agentVersion'] = self.agentVersion
            req['agentHostname'] = self.agentHostname
            req['pythonVersion'] = self.pythonVersion
            req['pymongoVersion'] = self.pymongoVersion
            req['pymongoHasC'] = self.pymongoHasC
            req['agentSessionKey'] = self.sessionKey
            req['srcVersion'] = self.srcVersion
            req['dataFormat'] = 1
            req['disableProfileDataCollection'] = self.disableProfileDataCollection
            req['disableGetLogsDataCollection'] = self.disableGetLogsDataCollection

            return bson.BSON.encode( req, check_keys=False )

        finally:
            del self.hostState
            self.hostState = { }

    def sendDataToMms( self ):
        """ Assemble the ping request and send the data to MMS """
        data = None

        try:
            self.hostStateLock.acquire()
            # Empty dictionary is False
            #if self.hostState:
            if ( self.hostState is not None and len( self.hostState ) > 0 ):
                data = self._assemblePingRequest()
        finally:
            self.hostStateLock.release()

        if data is None:
            return

        self._handleRemote( data )

    def stopAll( self ):
        """ Stop all the threads """
        try:
            self.serverHostDefsLock.acquire()
            for hostKey in self.serverHostDefs.keys():
                self.stopAndClearHost( hostKey )
        finally:
            self.serverHostDefsLock.release()

    def stopAndClearHost( self, hostKey ):
        """ Stop the data collection for this host. This assumes a server host def lock """

        if hostKey not in self.serverHostDefs:
            return

        # Stop the current thread and delete the definition
        self.serverHostDefs[hostKey]['nonBlockingStatsThread'].stopThread()
        self.serverHostDefs[hostKey]['blockingStatsThread'].stopThread()

        if 'getLogsThread' in self.serverHostDefs[hostKey]:
            self.serverHostDefs[hostKey]['getLogsThread'].stopThread()

        self._removeHostState( hostKey )

        # Check and see if this is the last definition of the unique server
        self._stopAndClearUniqueHost( self.serverHostDefs[hostKey]['hostname'] )

        # Remove the object from the dictionary.
        del self.serverHostDefs[hostKey]

    def _stopAndClearUniqueHost( self, hostname ):
        """ If this is the last reference to a hostname, remove. This requires a host def lock wrapping """
        try:
            self.serverUniqueHostsLock.acquire()

            foundCount = 0

            for hostKey in self.serverHostDefs.keys():
                if self.serverHostDefs[hostKey]['hostname'] == hostname:
                    foundCount = foundCount + 1

            if foundCount <= 1 and hostname in self.serverUniqueHosts:
                self.serverUniqueHosts[hostname].stopThread()
                del self.serverUniqueHosts[hostname]
        finally:
            self.serverUniqueHostsLock.release()


