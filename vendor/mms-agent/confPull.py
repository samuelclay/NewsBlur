"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

import threading, time, urllib2, traceback

import bson

confPullAgentVersion = "1.5.7"

class ConfPullThread( threading.Thread ):
    """ The remote configuration pull thread object """

    def __init__( self, settings, mmsAgent):
        """ Initialize the object """
        self.settings = settings
        self.logger = mmsAgent.logger
        self.mmsAgent = mmsAgent

        self.confUrl = self.settings.config_url % {
            'key' : self.settings.mms_key,
            'hostname' :  self.mmsAgent.agentHostname,
            'sessionKey' : self.mmsAgent.sessionKey,
            'agentVersion' : self.mmsAgent.agentVersion,
            'srcVersion' : self.mmsAgent.srcVersion
        }

        threading.Thread.__init__( self )

    def run( self ):
        """ Pull the configuration from the cloud (if enabled) """

        while not self.mmsAgent.done:
            self._pullRemoteConf()
            time.sleep( self.mmsAgent.confInterval )

    def _pullRemoteConf( self ):
        """ Pull the remote configuration data """

        uniqueHostnames = []

        res = None

        try:

            res = urllib2.urlopen( self.confUrl )

            resBson = None
            try:
                resBson = bson.decode_all( res.read() )
            finally:
                if res is not None:
                    res.close()
                    res = None

            if len(resBson) != 1:
                return

            confResponse = resBson[0]

            if 'hosts' not in confResponse:
                self.mmsAgent.stopAll()
                return

            if 'disableDbstats' in confResponse:
                self.mmsAgent.disableDbstats = confResponse['disableDbstats']
            else:
                self.mmsAgent.disableDbstats = False

            hosts = confResponse['hosts']

            self.mmsAgent.serverHostDefsLock.acquire()
            try:
                # Extract the host information
                if hosts is not None:
                    for host in hosts:

                        hostDef, hostDefLast = self.mmsAgent.extractHostDef( host )

                        hostKey = hostDef['hostKey']
                        uniqueHostnames.append( hostKey )

                        if hostKey not in self.mmsAgent.serverHostDefs:
                            self.mmsAgent.startMonitoringThreads( hostDef )
                        else:
                            self.mmsAgent.checkChangedHostDef( hostDef, hostDefLast )

                        hostDef = None
                        hostDefLast = None

                # Check to see if anything was removed
                for hostDef in self.mmsAgent.serverHostDefs.values():
                    if hostDef['hostKey'] not in uniqueHostnames:
                        self.mmsAgent.stopAndClearHost( hostDef['hostKey'] )
            finally:
                self.mmsAgent.serverHostDefsLock.release()

        except Exception, e:
            if res is not None:
                try:
                    res.close()
                    res = None
                except:
                    pass

            self.logger.warning( "Problem pulling configuration data from MMS (check firewall and network): " +  traceback.format_exc( e ) )

