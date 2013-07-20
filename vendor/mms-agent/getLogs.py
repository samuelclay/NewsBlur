"""
(C) Copyright 2012, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, traceback, warnings, sets

warnings.simplefilter( 'ignore', DeprecationWarning )

getLogsAgentVersion = "1.5.7"

class GetLogsThread( threading.Thread ):
    """ When enabled pull log data from hosts. """

    def __init__( self, hostKey, mmsAgent):
        """ Initialize the object """
        threading.Thread.__init__( self )
        self.hostKey = hostKey
        self.mmsAgent = mmsAgent
        self.logger = mmsAgent.logger
        self.running = True
        self.lastLogEntries = sets.Set()

    def stopThread( self ):
        """ Stop the thread """
        self.running = False

    def run( self ):
        """ Pull the data from the various hosts. """

        self.logger.info( 'starting log data collection: ' + self.hostKey )

        sleepTime = self.mmsAgent.logCollectionInterval

        if ( sleepTime < 1 ):
            sleepTime = 5

        logConn = None
        passes = 0

        while not self.mmsAgent.done and self.running:
            try:
                enabled = self.mmsAgent.hostDefValue( self.hostKey, 'getLogs' )

                if not enabled:
                    return

                passes = passes + 1

                # Close the connection every so often.
                if passes % 120 == 0:
                    logConn = self.mmsAgent.closeDbConnection( self.hostKey, logConn )

                if not logConn:
                    logConn = self.mmsAgent.getDbConnection( self.hostKey )

                time.sleep( sleepTime )

                if not self._processLogs( logConn ):
                    logConn = self.mmsAgent.closeDbConnection( self.hostKey, logConn )

            except Exception, e:
                logConn = self.mmsAgent.closeDbConnection( self.hostKey, logConn )
                self.logger.error( 'Problem collecting log data from: ' + self.hostKey + " - exception: " + traceback.format_exc( e ) )

        self.logger.info( 'stopping log data collection: ' + self.hostKey )
        self.mmsAgent.closeDbConnection( self.hostKey, logConn )


    def _processLogs( self, logConn ):
        """ Process the logs """

        try:
            if not self.mmsAgent.haveHostDef( self.hostKey ):
                return False

            # Verify the connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, logConn ):
                return False

            if not self.mmsAgent.hasCommand( 'getLog', self.hostKey, logConn ):
                self.logger.error( 'This version of MongoDB does not support the getLog command' )
                time.sleep( 60 )
                return False

            logs = self._collectLogs( logConn )

            # Make sure we ended up with the same connection.
            if not self.mmsAgent.isValidMonitorConn( self.hostKey, logConn ):
                return False

            self.mmsAgent.setHostState( self.hostKey, 'logs', logs )

            return True

        except Exception, e:
            self.logger.error( 'Problem collecting log data from: ' + self.hostKey + " - exception: " + traceback.format_exc( e ) )
            return False

    def _collectLogs( self, logConn ):
        """ Make the call to mongo host and pull the log data """
        root = { }

        logEntries = []

        entries = logConn.admin.command( { 'getLog' : 'global' } )

        if not entries or not entries.get('log'):
            self.lastLogEntries.clear()
            return root

        for logEntry in entries['log']:
            if logEntry in self.lastLogEntries:
                continue

            logEntries.append( logEntry )

        if len ( logEntries ) == 0:
            return root

        self.lastLogEntries.clear()

        for logEntry in entries['log']:
            self.lastLogEntries.add( logEntry )

        root['entries'] = logEntries

        return root

