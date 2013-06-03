"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, pymongo, traceback, warnings, datetime

warnings.simplefilter( 'ignore', DeprecationWarning )

nonBlockingStatsAgentVersion = "1.5.7"

class NonBlockingMongoStatsThread( threading.Thread ):
    """ Pull the non-blocking data from the various hosts. """

    def __init__( self, hostKey, mmsAgent ):
        """ Initialize the object """
        self.hostKey = hostKey
        self.mmsAgent = mmsAgent
        self.logger = mmsAgent.logger
        self.running = True
        self.host = mmsAgent.extractHostname( hostKey )
        self.port = mmsAgent.extractPort( hostKey )

        threading.Thread.__init__( self )

    def stopThread( self ):
        """ Stop the thread """
        self.running = False


    def run( self ):
        """ The thread to collect stats """

        self.logger.info( 'starting non-blocking stats monitoring: ' + self.hostKey )

        sleepTime = ( self.mmsAgent.collectionInterval / 2 ) - 1

        if ( sleepTime < 1 ):
            sleepTime = 1

        monitorConn = None

        passes = 0

        while not self.mmsAgent.done and self.running:
            try:
                time.sleep( sleepTime )
                passes = passes + 1

                # Close the connection periodically
                if passes % 60 == 0:
                    monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

                if not monitorConn:
                    monitorConn = self.mmsAgent.getDbConnection( self.hostKey )

                if not self._collectNonBlockingStats( monitorConn ):
                    monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

            except Exception, e:
                monitorConn = self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )
                self.logger.error( 'Problem collecting non-blocking data from: ' + self.hostKey + " - exception: " + traceback.format_exc( e ) )

        self.logger.info( 'stopping non-blocking stats monitoring: ' + self.hostKey )
        self.mmsAgent.closeDbConnection( self.hostKey, monitorConn )

    def _collectNonBlockingStats( self, monitorConn ):
        """ Collect the non-blocking stats """
        try:
            if not self.mmsAgent.haveHostDef( self.hostKey ):
                return False

            # Verify the connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, monitorConn ):
                return False

            stats = self._collectStats( monitorConn )

            stats['host'] = self.host
            stats['port'] = self.port

            # Make sure we ended up with the same connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, monitorConn ):
                return False

            self.mmsAgent.setHostState( self.hostKey, 'mongoNonBlocking', stats )

            return True

        except Exception, e:
            self.logger.warning( 'Problem collecting non-blocking data from (check if it is up and DNS): ' + self.hostKey + ' - ' +  traceback.format_exc( e ) )
            return False

    def _collectStats( self, monitorConn ):
        """ Make the call to mongo host and collect the data """
        root = {}

        # Set the agent version and hostname.
        root['agentVersion'] = self.mmsAgent.agentVersion
        root['agentHostname'] = self.mmsAgent.agentHostname
        root['agentSessionKey'] = self.mmsAgent.sessionKey

        cmdStartTime = datetime.datetime.now()
        root['serverStatus'] = monitorConn.admin.command( 'serverStatus' )
        cmdExecTime = datetime.datetime.now() - cmdStartTime
        root['serverStatusExecTimeMs'] = ( cmdExecTime.days * 24 * 60 * 60 + cmdExecTime.seconds ) * 1000 + cmdExecTime.microseconds / 1000.0

        # The server build info
        root['buildInfo'] = monitorConn.admin.command( 'buildinfo' )

        # Try and get the command line operations
        try:
            root['cmdLineOpts'] = monitorConn.admin.command( 'getCmdLineOpts' )
        except Exception, e:
            self.mmsAgent.handleOperationFailure( self.hostKey, 'getCmdLineOpts', e )

        # Get the connection pool stats.
        try:
            root['connPoolStats'] = monitorConn.admin.command( 'connPoolStats' )
        except Exception, e:
            self.mmsAgent.handleOperationFailure( self.hostKey, 'connPoolStats', e )

        # Look for any startup warnings if this is a valid version of mongo.
        if self.mmsAgent.hasCommand( 'getLog', self.hostKey, monitorConn ):
            try:
                root['startupWarnings'] = monitorConn.admin.command( { 'getLog' : 'startupWarnings' } )
            except Exception, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'getLog.startupWarnings', e )


        # See if we can get hostInfo.
        if self.mmsAgent.hasCommand( 'hostInfo', self.hostKey, monitorConn ):
            try:
                root['hostInfo'] = monitorConn.admin.command( { 'hostInfo' : 1 } )
            except Exception, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'hostInfo', e )

        # Try and get the isSelf data
        try:
            root['isSelf'] = monitorConn.admin.command( '_isSelf' )
        except Exception, e:
            self.mmsAgent.handleOperationFailure( self.hostKey, '_isSelf', e )

        # Get the params.
        try:
            root['getParameterAll'] = monitorConn.admin.command( { 'getParameter' : '*' } )
        except Exception, e:
            self.mmsAgent.handleOperationFailure( self.hostKey, 'getParameter.*', e )

        # Check occasionally to see if we can discover nodes
        isMaster = monitorConn.admin.command( 'ismaster' )
        root['isMaster'] = isMaster

        # Try and get the shard version
        if isMaster['ismaster'] and 'msg' in isMaster:
            if isMaster['msg'] != 'isdbgrid':

                try:
                    root['shardVersion'] = monitorConn.admin.command( { 'getShardVersion' : 'mdbfoo.foo' } )
                except Exception, e:
                    self.mmsAgent.handleOperationFailure( self.hostKey, 'getShardVersion.mdbfoo.foo', e )

        elif isMaster['ismaster']:
            try:
                root['shardVersion'] = monitorConn.admin.command( { 'getShardVersion' : 'mdbfoo.foo' } )
            except Exception, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'getShardVersion.mdbfoo.foo', e )

        # Check to see if this is a mongod host
        try:
            if isMaster['ismaster'] and isMaster.get('msg', '') == 'isdbgrid':
                root['netstat'] = monitorConn.admin.command( 'netstat' )
        except pymongo.errors.OperationFailure, e:
            self.mmsAgent.handleOperationFailure( self.hostKey, 'netstat', e )

        if 'repl' in root['serverStatus']:
            try:
                root['replStatus'] = monitorConn.admin.command( 'replSetGetStatus' )
            except pymongo.errors.OperationFailure, e:
                self.mmsAgent.handleOperationFailure( self.hostKey, 'replSetGetStatus', e )

        return root

