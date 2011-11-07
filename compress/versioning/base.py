class VersioningBase(object):

    def get_version(self, source_files):
        raise NotImplementedError
        
    def needs_update(self, output_file, source_files, version):
        raise NotImplementedError
        
class VersioningError(Exception):
    """
    This exception is raised when version creation fails
    """
    pass