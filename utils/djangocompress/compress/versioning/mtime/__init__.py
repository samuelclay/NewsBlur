import os

from compress.utils import get_output_filename, media_root
from compress.versioning.base import VersioningBase

class MTimeVersioning(VersioningBase):

    def get_version(self, source_files):

        # Return the modification time for the newest source file
        return str(max([int(os.stat(media_root(f)).st_mtime) for f in source_files]))

    def needs_update(self, output_file, source_files, version):

        output_file_name = get_output_filename(output_file, version)
        compressed_file_full = media_root(output_file_name)

        return (int(os.stat(compressed_file_full).st_mtime) < int(version)), version

