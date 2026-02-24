#!/usr/bin/env python3
"""
Convert Lucide and Heroicons SVG files to PNG format for iOS.

This script converts all SVG icons from the web app's icon directories to PNG format
at @2x and @3x resolutions for iOS.

Usage:
    pip install cairosvg pillow
    python convert_icons_to_pdf.py

Output:
    Creates PNG files in clients/ios/Resources/Icons/lucide/ and heroicons-solid/
"""

import os
import sys
from pathlib import Path

try:
    import cairosvg
except ImportError:
    print("Error: cairosvg is required. Install with: pip install cairosvg")
    sys.exit(1)


def convert_svg_to_png(svg_path: Path, png_path: Path, scale: int = 2) -> bool:
    """Convert an SVG file to PNG format at specified scale."""
    try:
        # Read SVG content
        with open(svg_path, 'r') as f:
            svg_content = f.read()

        # Replace currentColor with black (will be tinted at runtime)
        svg_content = svg_content.replace('stroke="currentColor"', 'stroke="#000000"')
        svg_content = svg_content.replace('fill="currentColor"', 'fill="#000000"')

        # Convert to PNG at specified scale (base size is 24x24)
        output_size = 24 * scale
        cairosvg.svg2png(
            bytestring=svg_content.encode('utf-8'),
            write_to=str(png_path),
            output_width=output_size,
            output_height=output_size
        )
        return True
    except Exception as e:
        print(f"  Error converting {svg_path.name}: {e}")
        return False


def main():
    # Determine paths relative to this script
    script_dir = Path(__file__).parent.resolve()
    ios_dir = script_dir.parent
    project_root = ios_dir.parent.parent

    # Source SVG directories
    lucide_src = project_root / "media" / "img" / "icons" / "lucide"
    heroicons_src = project_root / "media" / "img" / "icons" / "heroicons-solid"

    # Destination directories
    icons_dest = ios_dir / "Resources" / "Icons"
    lucide_dest = icons_dest / "lucide"
    heroicons_dest = icons_dest / "heroicons-solid"

    # Create output directories
    lucide_dest.mkdir(parents=True, exist_ok=True)
    heroicons_dest.mkdir(parents=True, exist_ok=True)

    print(f"Converting icons to PNG...")
    print(f"  Lucide source: {lucide_src}")
    print(f"  Heroicons source: {heroicons_src}")
    print(f"  Output: {icons_dest}")
    print()

    # Convert Lucide icons
    print("Converting Lucide icons...")
    lucide_count = 0
    lucide_errors = 0
    for svg_file in sorted(lucide_src.glob("*.svg")):
        # Create @2x version (48x48)
        png_file = lucide_dest / f"{svg_file.stem}@2x.png"
        if convert_svg_to_png(svg_file, png_file, scale=2):
            # Also create @3x version (72x72)
            png_file_3x = lucide_dest / f"{svg_file.stem}@3x.png"
            convert_svg_to_png(svg_file, png_file_3x, scale=3)
            lucide_count += 1
        else:
            lucide_errors += 1
    print(f"  Converted {lucide_count} Lucide icons ({lucide_errors} errors)")

    # Convert Heroicons
    print("Converting Heroicons...")
    heroicons_count = 0
    heroicons_errors = 0
    for svg_file in sorted(heroicons_src.glob("*.svg")):
        # Create @2x version (48x48)
        png_file = heroicons_dest / f"{svg_file.stem}@2x.png"
        if convert_svg_to_png(svg_file, png_file, scale=2):
            # Also create @3x version (72x72)
            png_file_3x = heroicons_dest / f"{svg_file.stem}@3x.png"
            convert_svg_to_png(svg_file, png_file_3x, scale=3)
            heroicons_count += 1
        else:
            heroicons_errors += 1
    print(f"  Converted {heroicons_count} Heroicons ({heroicons_errors} errors)")

    print()
    print(f"Total: {lucide_count + heroicons_count} icons converted")


if __name__ == "__main__":
    main()
