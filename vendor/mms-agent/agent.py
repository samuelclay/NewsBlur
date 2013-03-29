"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import settings as _settings
import logConfig

# Python
import sys, socket, time, os, hmac, urllib2, threading, subprocess, traceback

try:
    import hashlib
except ImportError:
    sys.exit( 'ERROR - you must have hashlib installed - see README for more info' )

_logger = logConfig.initLogger()

socket.setdefaulttimeout( _settings.socket_timeout )

_pymongoVersion = None

_processPid = os.getpid()

# Try and reduce the stack size.
try:
    threading.stack_size( 409600 )
except:
    pass

if _settings.mms_key == '@API_KEY@':
    sys.exit( 'ERROR - you must set your @API_KEY@ - see https://mms.10gen.com/settings' )

if _settings.secret_key == '@SECRET_KEY@':
    sys.exit( 'ERROR - you must set your @SECRET_KEY@ - see https://mms.10gen.com/settings' )

if sys.version_info < ( 2, 4 ):
    sys.exit( 'ERROR - old Python - the MMS agent requires Python 2.4 or higher' )

# Make sure pymongo is installed
try:
    import pymongo
    import bson
except ImportError:
    sys.exit( 'ERROR - pymongo not installed - see: http://api.mongodb.org/python/ - run: easy_install pymongo' )

# Check the version of pymongo.
pyv = pymongo.version
if "partition" in dir( pyv ):
    pyv = pyv.partition( "+" )[0]
    _pymongoVersion = pyv
    if map( int, pyv.split('.') ) < [ 1, 9]:
        sys.exit( 'ERROR - The MMS agent requires pymongo 1.9 or higher: easy_install -U pymongo' )

    if _settings.useSslForAllConnections:
        if map( int, pyv.split('.') ) < [ 2, 1, 1]:
            sys.exit( 'ERROR - The MMS agent requires pymongo 2.1.1 or higher to use SSL: easy_install -U pymongo' )

_pymongoVersion = pymongo.version

class AgentProcessContainer( object ):
    """ Store the handle and lock to the agent process. """

    def __init__( self ):
        """ Init the lock and init process to none """
        self.lock = threading.Lock()
        self.agent = None

    def pingAgentProcess( self ):
        """ Ping the agent process """
        try:
            self.lock.acquire()

            if self.agent is None or self.agent.poll() is not None:
                return

            self.agent.stdin.write( 'hello\n' )
            self.agent.stdin.flush()
        finally:
            self.lock.release()

    def stopAgentProcess( self ):
        """ Send the stop message to the agent process """
        try:
            self.lock.acquire()

            if self.agent is None or self.agent.poll() is not None:
                return

            self.agent.stdin.write( 'seeya\n' )
            self.agent.stdin.flush()

            time.sleep( 1 )
            self.agent = None

        finally:
            self.lock.release()

class AgentShutdownListenerThread( threading.Thread ):
    """ Disabled by default. When enabled listens for shutdown messages. """

    def __init__( self, loggerObj, settingsObj ):
        """ Initialize the object """
        self.logger = loggerObj
        self.settings = settingsObj
        threading.Thread.__init__( self )

    def run( self ):
        """ Listen for the shutdown messages """
        try:
            sock = socket.socket( socket.AF_INET,  socket.SOCK_DGRAM )
            sock.bind( ( self.settings.shutdownAgentBindAddr, self.settings.shutdownAgentBindPort ) )
        except Exception, e:
            self.logger.error( traceback.format_exc( e ) )

        self.logger.info( 'Shutdown listener bound to address %s on port %d' % ( self.settings.shutdownAgentBindAddr, self.settings.shutdownAgentBindPort ) )

        while True:
            try:
                time.sleep( 5 )
                data, addr = sock.recvfrom( 1024 )
                if data != self.settings.shutdownAgentBindChallenge:
                    self.logger.error( 'received bad shutdown message from: %s' % addr[0] )
                else:
                    self.logger.info( 'received valid shutdown message from: %s - exiting' % addr[0] )
                    os._exit( 0 )
            except:
                pass

class AgentProcessMonitorThread( threading.Thread ):
    """ Make sure the agent process is running """

    def __init__( self, logger, agentDir, processContainerObj ):
        """ Initialize the object """
        self.logger = logger
        self.agentDir = agentDir
        self.processContainer = processContainerObj
        threading.Thread.__init__( self )

    def _launchAgentProcess( self ):
        """ Execute the agent process and keep a handle to it. """
        return subprocess.Popen( [ sys.executable, os.path.join( sys.path[0], 'agentProcess.py' ), str( _processPid ) ], stdin=subprocess.PIPE, stdout=subprocess.PIPE )

    def run( self ):
        """ If the agent process is not alive, start the process """
        while True:
            try:
                time.sleep( 5 )
                self._monitorProcess()
            except Exception, e:
                self.logger.error( traceback.format_exc( e ) )

    def _monitorProcess( self ):
        """ Monitor the child process """
        self.processContainer.lock.acquire()
        try:
            try:
                if self.processContainer.agent is None or self.processContainer.agent.poll() is not None:
                    self.processContainer.agent = self._launchAgentProcess()
            except Exception, e:
                self.logger.error( traceback.format_exc( e ) )
        finally:
            self.processContainer.lock.release()

class AgentUpdateThread( threading.Thread ):
    """ Check to see if updates are available - if so download and restart agent process """

    def __init__( self, logger, agentDir, settingsObj, processContainerObj ):
        """ Initialize the object """
        self.logger = logger
        self.agentDir = agentDir
        self.settings = settingsObj
        self.processContainer = processContainerObj
        threading.Thread.__init__( self )

    def run( self ):
        """ Update the agent if possible """
        while True:
            try:
                time.sleep( 300 )
                self._checkForUpdate()
            except Exception, e:
                self.logger.error( 'Problem with upgrade check: ' + traceback.format_exc( e ) )

    def _checkForUpdate( self ):
        """ Update the agent if possible """

        res = urllib2.urlopen( self.settings.version_url % { 'key' : self.settings.mms_key } )

        resBson = None
        try:
            resBson = bson.decode_all( res.read() )
        finally:
            if res is not None:
                res.close()
                res = None

        if len(resBson) != 1:
            return

        versionResponse = resBson[0]

        if 'status' not in versionResponse or versionResponse['status'] != 'ok':
            return

        if 'agentVersion' not in versionResponse or 'authCode' not in versionResponse:
            return

        remoteAgentVersion = versionResponse['agentVersion']
        authCode =  versionResponse['authCode']

        if authCode != hmac.new( self.settings.secret_key, remoteAgentVersion, digestmod=hashlib.sha1 ).hexdigest():
            self.logger.error( 'Invalid auth code - please confirm your secret key (defined on Settings page) is correct and hmac is properly installed - http://mms.10gen.com/help/' )
            return

        if self._shouldUpgradeAgent( self.settings.settingsAgentVersion, remoteAgentVersion ):
            self._upgradeAgent( remoteAgentVersion )

    def _shouldUpgradeAgent( self, localVersion, remoteVersion ):
        """ Returns true if the agent should upgrade itself. """
        try:
            for l, r in zip( localVersion.split('.'), remoteVersion.split('.') ):
                if int( l ) < int( r ):
                    return True
                if int( l ) > int( r ):
                    return False
        except StandardError:
            self.logger.error( "Upgrade problem with versions - local: '%s' - remote: '%s'" % ( localVersion, remoteVersion ) )

        return False

    def _upgradeAgent( self, newAgentVersion ):
        """ Pull down the files, verify  and then stop the current process """

        res = urllib2.urlopen( self.settings.upgrade_url % { 'key' : self.settings.mms_key } )

        resBson = None
        try:
            resBson = bson.decode_all( res.read() )
        finally:
            if res is not None:
                res.close()
                res = None

        if len(resBson) != 1:
            return

        upgradeResponse = resBson[0]

        if 'status' not in upgradeResponse or upgradeResponse['status'] != 'ok' or 'files' not in upgradeResponse:
            return

        # Verify the auth codes for all files and names first.
        for fileInfo in upgradeResponse['files']:
            if fileInfo['fileAuthCode'] != hmac.new( self.settings.secret_key, fileInfo['file'], digestmod=hashlib.sha1 ).hexdigest():
                self.logger.error( 'Invalid file auth code for upgrade - cancelling' )
                return

            if fileInfo['fileNameAuthCode'] != hmac.new( self.settings.secret_key, fileInfo['fileName'], digestmod=hashlib.sha1 ).hexdigest():
                self.logger.error( 'Invalid file name auth code for upgrade - cancelling' )
                return

        # Write the files.
        for fileInfo in upgradeResponse['files']:

            fileContent = fileInfo['file']
            fileName = fileInfo['fileName']

            # If the user has a global username/password defined, make sure it is set in the new settings.py file.
            if fileName == 'settings.py' and getattr( self.settings, 'globalAuthUsername', None ) is not None and getattr( self.settings, 'globalAuthPassword', None ) is not None:
                fileContent = fileContent.replace( 'globalAuthPassword = None', 'globalAuthPassword=%r' % self.settings.globalAuthPassword )
                fileContent = fileContent.replace( 'globalAuthUsername = None', 'globalAuthUsername=%r' % self.settings.globalAuthUsername )

            fileSystemName = os.path.join( self.agentDir, fileName )
            newFile = open( fileSystemName, 'w' )

            try:
                newFile.write( fileContent )
            finally:
                if newFile is not None:
                    newFile.close()

        # Stop the current agent process
        try:
            self.processContainer.stopAgentProcess()
            self.settings.settingsAgentVersion = newAgentVersion
            self.logger.info( 'Agent upgraded to version: ' + newAgentVersion + ' - there is up to a five minute timeout before data will be sent again' )
        except Exception, e:
            self.logger.error( 'Problem restarting agent process: ' + traceback.format_exc( e ) )

#
# Run the process monitor and update threads.
#
if __name__ == "__main__":
    try:
        _logger.info( 'Starting agent parent process - version: %s' % ( _settings.settingsAgentVersion ) )
        _logger.info( 'Note: If you have hundreds or thousands of databases, disable dbstats on the settings page before running the MMS agent.' )

        processContainer = AgentProcessContainer()

        # Star the agent monitor thread.
        monitorThread = AgentProcessMonitorThread( _logger, sys.path[0], processContainer )
        monitorThread.setName( 'AgentProcessMonitorThread' )
        monitorThread.setDaemon( True )
        monitorThread.start()

        # If enabled, start the shutdown listener thread (disabled by default).
        if _settings.shutdownAgentBindAddr is not None:
            shutdownListenerThread = AgentShutdownListenerThread( _logger, _settings  )
            shutdownListenerThread.setName( 'AgentShutdownListenerThread' )
            shutdownListenerThread.setDaemon( True )
            shutdownListenerThread.start()

        if _settings.autoUpdateEnabled:
            updateThread = AgentUpdateThread( _logger, sys.path[0], _settings, processContainer )
            updateThread.setName( 'AgentUpdateThread' )
            updateThread.setDaemon( True )
            updateThread.start()

        _logger.info( 'Started agent parent process - version: %s' % ( _settings.settingsAgentVersion ) )

        # The parent process will let the child process know it's alive.
        while True:
            try:
                time.sleep( 2 )
                processContainer.pingAgentProcess()
            except Exception, exc:
                _logger.error( traceback.format_exc( exc ) )

    except KeyboardInterrupt:
        processContainer.stopAgentProcess()
    except Exception, ex:
        _logger.error( traceback.format_exc( ex )  )

