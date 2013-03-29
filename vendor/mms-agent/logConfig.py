"""
(C) Copyright 2011, 10gen

This is a label on a mattress. Do not modify this file!
"""

# App
import settings as _settings

# Mongo
import pymongo, bson

# Python
import logging, threading, time, logging.handlers, urllib2, platform, socket, Queue

socket.setdefaulttimeout( _settings.socket_timeout )

class LogRelayThread( threading.Thread ):
    """ The log relay thread - batch messages """

    def __init__( self, recordQueue ):
        """ Construct the object """
        self.recordQueue = recordQueue
        self.logUrl = _settings.logging_url % { 'key' : _settings.mms_key }
        self.pythonVersion = platform.python_version()

        try:
            self.hostname = platform.uname()[1]
        except:
            self.hostname = 'UNKNOWN'

        self.pymongoVersion = pymongo.version
        threading.Thread.__init__( self )

    def run( self ):
        """ The agent process """
        while True:
            try:
                # Let the records batch for five seconds
                time.sleep( 5 )

                self._processRecords()

            except Exception:
                pass

    def _processRecords( self ):
        """ Process the log records """
        records = []

        try:
            while not self.recordQueue.empty():

                record = self.recordQueue.get( True, 1 )

                if record is None:
                    break

                data = { }
                data['levelname'] = record.levelname
                data['msg'] = record.msg
                data['filename'] = record.filename
                data['threadName'] = record.threadName

                # This is to deal with older versions of python.
                try:
                    data['funcName'] = record.funcName
                except Exception:
                    pass

                data['process'] = record.process
                data['lineno'] = record.lineno
                data['pymongoVersion'] = self.pymongoVersion
                data['pythonVersion'] = self.pythonVersion
                data['hostname'] = self.hostname

                records.append( data )

                if len( records ) >= 10:
                    break

        except Queue.Empty:
            pass

        if len( records ) == 0:
            return

        # Send the data back to mms.
        res = None
        try:
            res = urllib2.urlopen( self.logUrl, bson.BSON.encode( { 'records' : records }, check_keys=False ) )
            res.read()
        finally:
            if res is not None:
                res.close()

class MmsRemoteHandler( logging.Handler ):
    """ The mms remote log handler """
    def __init__( self ):
        """ Construct a new object """
        logging.Handler.__init__( self )
        self.recordQueue = Queue.Queue( 250 )
        self.logRelay = LogRelayThread( self.recordQueue )
        self.logRelay.setName( 'LogRelay' )
        self.logRelay.start()

    def emit( self, record ):
        """ Send the record to the remote servers """
        try:
            if record is not None:
                self.recordQueue.put_nowait( record )
        except Exception:
            pass

def initLogger( ):
    """ Initialize the logger """
    logger = logging.getLogger('MMS')
    streamHandler = logging.StreamHandler()
    streamHandler.setFormatter( logging.Formatter('%(asctime)s %(levelname)s %(message)s') )
    logger.addHandler( streamHandler )
    logging.handlers.MmsRemoteHandler = MmsRemoteHandler
    logger.addHandler( logging.handlers.MmsRemoteHandler() )
    logger.setLevel( logging.INFO )
    return logger

