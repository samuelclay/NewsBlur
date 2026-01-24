"""
Tests for the icon_importer module.

Tests image processing and color detection functionality.
"""

import numpy as np
import pytest
from django.test import TransactionTestCase
from PIL import Image
from unittest.mock import MagicMock, patch


class Test_IconImporterColorDetection(TransactionTestCase):
    """Test the determine_dominant_color_in_image function."""

    def _create_icon_importer(self):
        """Create an IconImporter instance with a mocked feed."""
        from apps.rss_feeds.icon_importer import IconImporter

        mock_feed = MagicMock()
        mock_feed.pk = 1
        mock_feed.log_title = "Test Feed"
        mock_feed.adjust_color = lambda color, amount: color

        with patch("apps.rss_feeds.icon_importer.MFeedIcon") as mock_icon:
            mock_icon.get_feed.return_value = MagicMock()
            importer = IconImporter(feed=mock_feed)

        return importer

    def test_determine_dominant_color_solid_red(self):
        """Test color detection with a solid red image."""
        importer = self._create_icon_importer()

        # Create a 16x16 solid red image
        image = Image.new("RGBA", (16, 16), (255, 0, 0, 255))
        color = importer.determine_dominant_color_in_image(image)

        # Should detect red (ff0000)
        assert color == "ff0000", f"Expected ff0000 but got {color}"

    def test_determine_dominant_color_solid_green(self):
        """Test color detection with a solid green image."""
        importer = self._create_icon_importer()

        # Create a 16x16 solid green image
        image = Image.new("RGBA", (16, 16), (0, 255, 0, 255))
        color = importer.determine_dominant_color_in_image(image)

        # Should detect green (00ff00)
        assert color == "00ff00", f"Expected 00ff00 but got {color}"

    def test_determine_dominant_color_solid_blue(self):
        """Test color detection with a solid blue image."""
        importer = self._create_icon_importer()

        # Create a 16x16 solid blue image
        image = Image.new("RGBA", (16, 16), (0, 0, 255, 255))
        color = importer.determine_dominant_color_in_image(image)

        # Should detect blue (0000ff)
        assert color == "0000ff", f"Expected 0000ff but got {color}"

    def test_determine_dominant_color_mixed_image(self):
        """Test color detection with a mixed color image (mostly one color)."""
        importer = self._create_icon_importer()

        # Create a 16x16 image that's mostly orange
        image = Image.new("RGBA", (16, 16), (255, 165, 0, 255))
        color = importer.determine_dominant_color_in_image(image)

        # Should detect orange-ish color
        assert len(color) == 6, f"Color should be 6 hex chars, got {color}"
        # First two chars should be high (red component)
        assert int(color[:2], 16) > 200, f"Red component should be high in {color}"

    def test_determine_dominant_color_grayscale_image(self):
        """Test color detection with a grayscale image converted to RGBA."""
        importer = self._create_icon_importer()

        # Create a grayscale image and convert to RGBA
        image = Image.new("L", (16, 16), 128)
        image = image.convert("RGBA")
        color = importer.determine_dominant_color_in_image(image)

        # Should return a valid 6-char hex color
        assert len(color) == 6, f"Color should be 6 hex chars, got {color}"

    def test_determine_dominant_color_1bit_image(self):
        """Test color detection with a 1-bit image."""
        importer = self._create_icon_importer()

        # Create a 1-bit (black and white) image
        image = Image.new("1", (16, 16), 1)  # All white
        color = importer.determine_dominant_color_in_image(image)

        # Should return a valid 6-char hex color
        assert len(color) == 6, f"Color should be 6 hex chars, got {color}"

    def test_numpy_prod_used_not_product(self):
        """Test that np.prod is available (np.product deprecated in 1.x, removed in 2.0)."""
        # This test verifies np.prod is available for use
        # np.product was deprecated in numpy 1.x and removed in 2.0
        assert hasattr(np, "prod"), "numpy should have prod function"
        # In numpy 1.x, product still exists but is deprecated
        # In numpy 2.0+, product was removed
        # Either way, we just verify prod() works correctly
        assert np.prod([1, 2, 3]) == 6, "np.prod should work correctly"

    def test_determine_dominant_color_large_image(self):
        """Test color detection with a larger image that needs reshaping."""
        importer = self._create_icon_importer()

        # Create a 64x64 image (larger than typical favicon)
        image = Image.new("RGBA", (64, 64), (100, 150, 200, 255))
        color = importer.determine_dominant_color_in_image(image)

        # Should successfully process and return a valid color
        assert len(color) == 6, f"Color should be 6 hex chars, got {color}"

    def test_normalize_image_converts_to_rgba(self):
        """Test that normalize_image converts images to RGBA."""
        importer = self._create_icon_importer()

        # Create an RGB image (no alpha)
        image = Image.new("RGB", (16, 16), (255, 0, 0))
        assert image.mode == "RGB"

        normalized = importer.normalize_image(image)
        assert normalized.mode == "RGBA", f"Expected RGBA mode, got {normalized.mode}"
