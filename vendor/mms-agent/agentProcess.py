"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# Mongo
import pymongo, bson

if '_closed' in dir( pymongo.connection ):
    pymongo.connection._closed = lambda sock: False

# App
import settings as _settings
from mmsAgent import MmsAgent
from confPull import ConfPullThread
import logConfig

# Python
import os, sys, platform, time, threading, socket, traceback, random, hashlib, tempfile

socket.setdefaulttimeout( _settings.socket_timeout )

_agentVersion = "1.5.7"

_pymongoVersion = pymongo.version

_pymongoHasC = False

try:
    _pymongoHasC = pymongo.has_c()
except:
    pass

# Try and reduce the stack size.
try:
    threading.stack_size(409600)
except:
    pass

class AgentProcess( threading.Thread ):
    """ The parent process - monitors agent process and checks for updates etc """

    def __init__( self, loggerObj, agentDir, existingSessionKey ):
        """ Construct the object """
        self.logger = loggerObj
        self.agentDir = agentDir
        self.mmsAgent = MmsAgent( _settings, _agentVersion, platform.python_version(), _pymongoVersion, _pymongoHasC, platform.uname()[1], self.logger, existingSessionKey )
        threading.Thread.__init__( self )

    def stop( self ):
        """ Stop the agent process """
        try:
            self.mmsAgent.done = True
            self.mmsAgent.stopAll()

        except Exception, fe:
            self.logger.error( traceback.format_exc( fe ) )

    def run( self ):
        """ The agent process """
        try:
            # Start the configuration request
            confThread = ConfPullThread( _settings, self.mmsAgent )
            confThread.setName( 'ConfPullThread' )
            confThread.start()

            hostStateMonitorThread = MonitorHostState( self.logger, self.mmsAgent )
            hostStateMonitorThread.setName( 'MonitorHostState' )
            hostStateMonitorThread.start()

            # Loop through and send data back to the MMS servers.
            while not self.mmsAgent.done:
                try:
                    try:
                        self.mmsAgent.sendDataToMms()

                    except Exception, e:
                        self.logger.error( traceback.format_exc( e ) )
                finally:
                    try:
                        time.sleep( self.mmsAgent.collectionInterval )
                    except:
                        pass

        except Exception, e:
            self.logger.error( traceback.format_exc( e ) )

class ParentProcessMonitor( threading.Thread ):
    """ The parent process monitor - monitors to see if the parent process is sending heartbeats """

    def __init__( self, agentProcessObj ):
        """ Construct the object """
        self.mmsAgent = agentProcessObj.mmsAgent
        self.logger = self.mmsAgent.logger
        self.agentProcess = agentProcessObj
        self.lock = threading.Lock()
        self.lastHeartbeat = time.time()
        self.running = True
        threading.Thread.__init__( self )

    def run( self ):
        """ Verify the parent process is sending pings """
        while self.running:
            time.sleep( 2 )
            try:
                self._check()
            except Exception, ex:
                self.logger.error( traceback.format_exc( ex ) )
                raise

    def _check( self ):
        """ Verify the heartbeat """
        try:
            self.lock.acquire()

            secsSinceHeartbeat = ( time.time() - self.lastHeartbeat )

            if secsSinceHeartbeat > 10:
                self.agentProcess.stop()
                os._exit( 0 )
        finally:
            self.lock.release()

    def stop( self ):
        """ Stop the process """
        self.running = False

    def heartbeat( self ):
        """ Update the last time a message was sent from the parent. """
        try:
            self.lock.acquire()
            self.lastHeartbeat = time.time()
        finally:
            self.lock.release()

class ParentMsgReader( threading.Thread ):
    """ The parent process message reader """

    def __init__( self, loggerObj, agentProcessObj, parentMonitorObj ):
        """ Construct the object """
        self.logger = loggerObj
        self.parentMonitor = parentMonitorObj
        self.agentProcess = agentProcessObj
        threading.Thread.__init__( self )

    def run( self ):
        """ Read the data from stdin and process """
        while True:
            try:
                time.sleep( 1 )
                self._readParentMessage()

            except Exception, exc:
                self.logger.error( traceback.format_exc( exc ) )

    def _readParentMessage( self ):
        """ Read the heartbeat or stop message from the parent process """
        line = sys.stdin.readline()

        if not line:
            return

        if line == 'hello\n':
            self.parentMonitor.heartbeat()
            return

        if line == 'seeya\n':
            try:
                self.agentProcess.stop()
                self.parentMonitor.stop()
            finally:
                os._exit( 0 )

class MonitorHostState( threading.Thread ):
    """ Check to see if we're not getting updates to host state - if not, flush """

    def __init__( self, loggerObj, mmsAgentObj ):
        """ Construct the object """
        self.logger = loggerObj
        self.mmsAgent = mmsAgentObj
        threading.Thread.__init__( self )

    def run( self ):
        """ Make sure the data is current, if not remove """
        while True:
            try:
                self.mmsAgent.cleanHostState()
            except Exception, e:
                self.logger.error( traceback.format_exc( e ) )

            time.sleep( 10 )

def generateSessionKey( *args ):
    """ Generate a session key """
    t = time.time() * 1000
    r = random.random()*100000000000000000
    try:
        a = platform.uname()[1]
    except:
        a = random.random()*100000000000000000

    return hashlib.md5( ( '%(time)s %(random)s %(host)s %(args)s' % {'time' : t, 'random': r, 'host' : a, 'args' : str( args ) } ) ).hexdigest()

def readTmpFile( processPid ):
    """ Read the temp file """
    fileName = os.path.join( tempfile.gettempdir(), 'mms-' + str( processPid ) )

    if not os.path.isfile( fileName ):
        return None

    f = open( fileName )

    try:
        fileContent = f.read()

        # Handle the legacy json files
        if fileContent.startswith( '{' ):
            os.remove( fileName )
            return None

        resBson = bson.decode_all( fileContent )

        if len(resBson) != 1:
            return None

        return resBson[0]

    finally:
        f.close()

def writeTmpFile( processPid, content ):
    """ Write the temp file """
    fileName = os.path.join( tempfile.gettempdir(), 'mms-' + str( processPid ) )

    f = open( fileName, 'wb', 0 )

    try:
        f.write( bson.BSON.encode( content) )
    finally:
        f.close()

if __name__ == "__main__":

    logger = logConfig.initLogger()

    logger.info( 'Starting agent process - version %s' % ( _agentVersion ) )

    sessionKey = generateSessionKey()

    parentPid = None

    try:
        if len( sys.argv ) > 1:
            parentPid = sys.argv[1]
            currentState = readTmpFile( parentPid )
            if currentState is not None:
                if 'sessionKey' in currentState:
                    sessionKey = currentState['sessionKey']
                else:
                    currentState['sessionKey'] = sessionKey
            else:
                currentState = { }
                currentState['sessionKey'] = sessionKey

            writeTmpFile( parentPid, currentState )

    except Exception, ec:
        logger.error( traceback.format_exc( ec ) )

    try:
        # Star the agent monitor thread.
        agentProcess = AgentProcess( logger, sys.path[0], sessionKey )
        agentProcess.setName( 'AgentProcess' )
        agentProcess.start()

        parentMonitor = ParentProcessMonitor( agentProcess )
        parentMonitor.setName( 'ParentProcessMonitor' )
        parentMonitor.start()

        msgReader = ParentMsgReader( logger, agentProcess, parentMonitor)
        msgReader.setName( 'ParentMsgReader' )
        msgReader.start()

        logger.info( 'Started agent process - parent pid: %s - version: %s'  % ( str( parentPid ), _agentVersion ) )

    except Exception, ec:
        logger.error( traceback.format_exc( ec ) )

