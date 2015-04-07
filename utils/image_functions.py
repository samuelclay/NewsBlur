"""Operations for images through the PIL."""

from PIL import Image
from PIL import ImageOps as PILOps
from PIL.ExifTags import TAGS
from StringIO import StringIO
from vendor import reseekfile

PROFILE_PICTURE_SIZES = {
    'fullsize': (256, 256),
    'thumbnail': (64, 64)
}

class ImageOps:
    """Module that holds all image operations. Since there's no state, 
    everything is a classmethod."""
    
    @classmethod
    def resize_image(cls, image_body, size, fit_to_size=False):
        """Takes a raw image (in image_body) and resizes it to fit given
        dimensions. Returns a  file-like object in the form of a StringIO. 
        This must happen in this function because PIL is transforming the 
        original as it works."""
        
        image_file = StringIO(image_body)
        try:
            image = Image.open(image_file)
        except IOError:
            # Invalid image file
            return False
                        
        # Get the image format early, as we lose it after perform a `thumbnail` or `fit`.
        format = image.format
        
        # Check for rotation
        image = cls.adjust_image_orientation(image)
        
        if not fit_to_size:
            image.thumbnail(PROFILE_PICTURE_SIZES[size], Image.ANTIALIAS)
        else:
            image = PILOps.fit(image, PROFILE_PICTURE_SIZES[size], 
                               method=Image.ANTIALIAS, 
                               centering=(0.5, 0.5))
        
        output = StringIO()
        if format.lower() == 'jpg':
            format = 'jpeg'
        image.save(output, format=format, quality=95)
        
        return output
    
    @classmethod
    def adjust_image_orientation(cls, image):
        """Since the iPhone will store an image on its side but with EXIF
        data stating that it should be rotated, we need to find that
        EXIF data and correctly rotate the image before storage."""
        
        if hasattr(image, '_getexif'):
            exif = image._getexif()
            if exif:
                for tag, value in exif.items():
                    decoded = TAGS.get(tag, tag)
                    if decoded == 'Orientation':
                        if value == 6:
                            image = image.rotate(-90)
                        if value == 8:
                            image = image.rotate(90)
                        if value == 3:
                            image = image.rotate(180)
                        break
        return image
    
    @classmethod
    def image_size(cls, datastream):
        datastream = reseekfile.ReseekFile(datastream)
        image = Image.open(datastream)
        return image.size
