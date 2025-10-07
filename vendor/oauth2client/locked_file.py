# Copyright 2011 Google Inc. All Rights Reserved.

"""Locked file interface that should work on Unix and Windows pythons.

This module first tries to use fcntl locking to ensure serialized access
to a file, then falls back on a lock file if that is unavialable.

Usage:
    f = LockedFile('filename', 'r+b', 'rb')
    f.open_and_lock()
    if f.is_locked():
      print 'Acquired filename with r+b mode'
      f.file_handle().write('locked data')
    else:
      print 'Aquired filename with rb mode'
    f.unlock_and_close()
"""

__author__ = "cache@google.com (David T McWherter)"

import errno
import logging
import os
import time

from oauth2client import util

logger = logging.getLogger(__name__)


class AlreadyLockedException(Exception):
    """Trying to lock a file that has already been locked by the LockedFile."""

    pass


class _Opener(object):
    """Base class for different locking primitives."""

    def __init__(self, filename, mode, fallback_mode):
        """Create an Opener.

        Args:
          filename: string, The pathname of the file.
          mode: string, The preferred mode to access the file with.
          fallback_mode: string, The mode to use if locking fails.
        """
        self._locked = False
        self._filename = filename
        self._mode = mode
        self._fallback_mode = fallback_mode
        self._fh = None

    def is_locked(self):
        """Was the file locked."""
        return self._locked

    def file_handle(self):
        """The file handle to the file.  Valid only after opened."""
        return self._fh

    def filename(self):
        """The filename that is being locked."""
        return self._filename

    def open_and_lock(self, timeout, delay):
        """Open the file and lock it.

        Args:
          timeout: float, How long to try to lock for.
          delay: float, How long to wait between retries.
        """
        pass

    def unlock_and_close(self):
        """Unlock and close the file."""
        pass


class _PosixOpener(_Opener):
    """Lock files using Posix advisory lock files."""

    def open_and_lock(self, timeout, delay):
        """Open the file and lock it.

        Tries to create a .lock file next to the file we're trying to open.

        Args:
          timeout: float, How long to try to lock for.
          delay: float, How long to wait between retries.

        Raises:
          AlreadyLockedException: if the lock is already acquired.
          IOError: if the open fails.
        """
        if self._locked:
            raise AlreadyLockedException("File %s is already locked" % self._filename)
        self._locked = False

        try:
            self._fh = open(self._filename, self._mode)
        except IOError as e:
            # If we can't access with _mode, try _fallback_mode and don't lock.
            if e.errno == errno.EACCES:
                self._fh = open(self._filename, self._fallback_mode)
                return

        lock_filename = self._posix_lockfile(self._filename)
        start_time = time.time()
        while True:
            try:
                self._lock_fd = os.open(lock_filename, os.O_CREAT | os.O_EXCL | os.O_RDWR)
                self._locked = True
                break

            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise
                if (time.time() - start_time) >= timeout:
                    logger.warn("Could not acquire lock %s in %s seconds" % (lock_filename, timeout))
                    # Close the file and open in fallback_mode.
                    if self._fh:
                        self._fh.close()
                    self._fh = open(self._filename, self._fallback_mode)
                    return
                time.sleep(delay)

    def unlock_and_close(self):
        """Unlock a file by removing the .lock file, and close the handle."""
        if self._locked:
            lock_filename = self._posix_lockfile(self._filename)
            os.unlink(lock_filename)
            os.close(self._lock_fd)
            self._locked = False
            self._lock_fd = None
        if self._fh:
            self._fh.close()

    def _posix_lockfile(self, filename):
        """The name of the lock file to use for posix locking."""
        return "%s.lock" % filename


try:
    import fcntl

    class _FcntlOpener(_Opener):
        """Open, lock, and unlock a file using fcntl.lockf."""

        def open_and_lock(self, timeout, delay):
            """Open the file and lock it.

            Args:
              timeout: float, How long to try to lock for.
              delay: float, How long to wait between retries

            Raises:
              AlreadyLockedException: if the lock is already acquired.
              IOError: if the open fails.
            """
            if self._locked:
                raise AlreadyLockedException("File %s is already locked" % self._filename)
            start_time = time.time()

            try:
                self._fh = open(self._filename, self._mode)
            except IOError as e:
                # If we can't access with _mode, try _fallback_mode and don't lock.
                if e.errno == errno.EACCES:
                    self._fh = open(self._filename, self._fallback_mode)
                    return

            # We opened in _mode, try to lock the file.
            while True:
                try:
                    fcntl.lockf(self._fh.fileno(), fcntl.LOCK_EX)
                    self._locked = True
                    return
                except IOError as e:
                    # If not retrying, then just pass on the error.
                    if timeout == 0:
                        raise e
                    if e.errno != errno.EACCES:
                        raise e
                    # We could not acquire the lock.  Try again.
                    if (time.time() - start_time) >= timeout:
                        logger.warn("Could not lock %s in %s seconds" % (self._filename, timeout))
                        if self._fh:
                            self._fh.close()
                        self._fh = open(self._filename, self._fallback_mode)
                        return
                    time.sleep(delay)

        def unlock_and_close(self):
            """Close and unlock the file using the fcntl.lockf primitive."""
            if self._locked:
                fcntl.lockf(self._fh.fileno(), fcntl.LOCK_UN)
            self._locked = False
            if self._fh:
                self._fh.close()

except ImportError:
    _FcntlOpener = None


try:
    import pywintypes
    import win32con
    import win32file

    class _Win32Opener(_Opener):
        """Open, lock, and unlock a file using windows primitives."""

        # Error #33:
        #  'The process cannot access the file because another process'
        FILE_IN_USE_ERROR = 33

        # Error #158:
        #  'The segment is already unlocked.'
        FILE_ALREADY_UNLOCKED_ERROR = 158

        def open_and_lock(self, timeout, delay):
            """Open the file and lock it.

            Args:
              timeout: float, How long to try to lock for.
              delay: float, How long to wait between retries

            Raises:
              AlreadyLockedException: if the lock is already acquired.
              IOError: if the open fails.
            """
            if self._locked:
                raise AlreadyLockedException("File %s is already locked" % self._filename)
            start_time = time.time()

            try:
                self._fh = open(self._filename, self._mode)
            except IOError as e:
                # If we can't access with _mode, try _fallback_mode and don't lock.
                if e.errno == errno.EACCES:
                    self._fh = open(self._filename, self._fallback_mode)
                    return

            # We opened in _mode, try to lock the file.
            while True:
                try:
                    hfile = win32file._get_osfhandle(self._fh.fileno())
                    win32file.LockFileEx(
                        hfile,
                        (win32con.LOCKFILE_FAIL_IMMEDIATELY | win32con.LOCKFILE_EXCLUSIVE_LOCK),
                        0,
                        -0x10000,
                        pywintypes.OVERLAPPED(),
                    )
                    self._locked = True
                    return
                except pywintypes.error as e:
                    if timeout == 0:
                        raise e

                    # If the error is not that the file is already in use, raise.
                    if e[0] != _Win32Opener.FILE_IN_USE_ERROR:
                        raise

                    # We could not acquire the lock.  Try again.
                    if (time.time() - start_time) >= timeout:
                        logger.warn("Could not lock %s in %s seconds" % (self._filename, timeout))
                        if self._fh:
                            self._fh.close()
                        self._fh = open(self._filename, self._fallback_mode)
                        return
                    time.sleep(delay)

        def unlock_and_close(self):
            """Close and unlock the file using the win32 primitive."""
            if self._locked:
                try:
                    hfile = win32file._get_osfhandle(self._fh.fileno())
                    win32file.UnlockFileEx(hfile, 0, -0x10000, pywintypes.OVERLAPPED())
                except pywintypes.error as e:
                    if e[0] != _Win32Opener.FILE_ALREADY_UNLOCKED_ERROR:
                        raise
            self._locked = False
            if self._fh:
                self._fh.close()

except ImportError:
    _Win32Opener = None


class LockedFile(object):
    """Represent a file that has exclusive access."""

    @util.positional(4)
    def __init__(self, filename, mode, fallback_mode, use_native_locking=True):
        """Construct a LockedFile.

        Args:
          filename: string, The path of the file to open.
          mode: string, The mode to try to open the file with.
          fallback_mode: string, The mode to use if locking fails.
          use_native_locking: bool, Whether or not fcntl/win32 locking is used.
        """
        opener = None
        if not opener and use_native_locking:
            if _Win32Opener:
                opener = _Win32Opener(filename, mode, fallback_mode)
            if _FcntlOpener:
                opener = _FcntlOpener(filename, mode, fallback_mode)

        if not opener:
            opener = _PosixOpener(filename, mode, fallback_mode)

        self._opener = opener

    def filename(self):
        """Return the filename we were constructed with."""
        return self._opener._filename

    def file_handle(self):
        """Return the file_handle to the opened file."""
        return self._opener.file_handle()

    def is_locked(self):
        """Return whether we successfully locked the file."""
        return self._opener.is_locked()

    def open_and_lock(self, timeout=0, delay=0.05):
        """Open the file, trying to lock it.

        Args:
          timeout: float, The number of seconds to try to acquire the lock.
          delay: float, The number of seconds to wait between retry attempts.

        Raises:
          AlreadyLockedException: if the lock is already acquired.
          IOError: if the open fails.
        """
        self._opener.open_and_lock(timeout, delay)

    def unlock_and_close(self):
        """Unlock and close a file."""
        self._opener.unlock_and_close()
