import cStringIO
from hashlib import md5, sha1
import os

from compress.conf import settings
from compress.utils import concat, get_output_filename
from compress.versioning.base import VersioningBase

class HashVersioningBase(VersioningBase):
    def __init__(self, hash_method):
        self.hash_method = hash_method
    
    def needs_update(self, output_file, source_files, version):
        output_file_name = get_output_filename(output_file, version)
        ph = settings.COMPRESS_VERSION_PLACEHOLDER
        of = output_file
        try:
            phi = of.index(ph)
            old_version = output_file_name[phi:phi+len(ph)-len(of)]
            return (version != old_version), version
        except ValueError:
            # no placeholder found, do not update, manual update if needed
            return False, version
            
    def get_version(self, source_files):
        buf = concat(source_files)
        s = cStringIO.StringIO(buf)
        version = self.get_hash(s)
        s.close()
        return version            
            
    def get_hash(self, f, CHUNK=2**16):
        m = self.hash_method()
        while 1:
            chunk = f.read(CHUNK)
            if not chunk:
                break
            m.update(chunk)
        return m.hexdigest()

class MD5Versioning(HashVersioningBase):
    def __init__(self):
        super(MD5Versioning, self).__init__(md5)

class SHA1Versioning(HashVersioningBase):
    def __init__(self):
        super(SHA1Versioning, self).__init__(sha1)