#!/usr/bin/env python3
"""
Generate app icons for My Business Ledger
Creates a professional icon with MBL initials
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon():
    # Icon size (1024x1024 is recommended for both iOS and Android)
    size = 1024
    
    # Create base image with gradient background
    img = Image.new('RGB', (size, size), '#1A1A2E')
    draw = ImageDraw.Draw(img)
    
    # Draw gradient effect (dark blue to purple)
    for i in range(size):
        # Calculate color for each row
        r = int(15 + (83 - 15) * (i / size))
        g = int(26 + (52 - 26) * (i / size))
        b = int(46 + (131 - 46) * (i / size))
        draw.line([(0, i), (size, i)], fill=(r, g, b))
    
    # Draw a circular background
    circle_margin = size // 6
    draw.ellipse(
        [circle_margin, circle_margin, size - circle_margin, size - circle_margin],
        fill='#0F3460',
        outline='#667EEA',
        width=15
    )
    
    # Try to use a bold font, fallback to default if not available
    try:
        # Try different font paths for different systems
        font_paths = [
            '/System/Library/Fonts/Helvetica.ttc',  # macOS
            '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',  # Linux
            'C:\\Windows\\Fonts\\arialbd.ttf',  # Windows
        ]
        
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                font = ImageFont.truetype(font_path, 380)
                break
        
        if font is None:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
    
    # Draw "MBL" text in the center
    text = "MBL"
    
    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Calculate position to center text
    x = (size - text_width) // 2
    y = (size - text_height) // 2 - 40
    
    # Draw text shadow
    draw.text((x + 8, y + 8), text, fill='#000000', font=font)
    
    # Draw main text
    draw.text((x, y), text, fill='#FFFFFF', font=font)
    
    # Draw subtitle below
    try:
        small_font = ImageFont.truetype(font_paths[0], 80) if os.path.exists(font_paths[0]) else ImageFont.load_default()
    except:
        small_font = ImageFont.load_default()
    
    subtitle = "Business Ledger"
    bbox2 = draw.textbbox((0, 0), subtitle, font=small_font)
    subtitle_width = bbox2[2] - bbox2[0]
    subtitle_x = (size - subtitle_width) // 2
    subtitle_y = y + text_height + 50
    
    draw.text((subtitle_x, subtitle_y), subtitle, fill='#E0E0E0', font=small_font)
    
    # Save main icon
    output_path = 'assets/icon/app_icon.png'
    img.save(output_path, 'PNG', quality=100)
    print(f"✓ Created main icon: {output_path}")
    
    # Create foreground for adaptive icon (Android)
    # Foreground should be transparent with just the icon elements
    fg_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    fg_draw = ImageDraw.Draw(fg_img)
    
    # Draw circle outline
    circle_margin = size // 4
    fg_draw.ellipse(
        [circle_margin, circle_margin, size - circle_margin, size - circle_margin],
        outline='#667EEA',
        width=20
    )
    
    # Draw text
    fg_draw.text((x + 8, y + 8), text, fill=(0, 0, 0, 128), font=font)
    fg_draw.text((x, y), text, fill='#FFFFFF', font=font)
    fg_draw.text((subtitle_x, subtitle_y), subtitle, fill='#E0E0E0', font=small_font)
    
    fg_output_path = 'assets/icon/app_icon_foreground.png'
    fg_img.save(fg_output_path, 'PNG', quality=100)
    print(f"✓ Created foreground icon: {fg_output_path}")
    
    print("\n✓ App icons generated successfully!")
    print("\nNext steps:")
    print("1. Run: flutter pub get")
    print("2. Run: dart run flutter_launcher_icons")
    print("3. Rebuild your app to see the new icon")

if __name__ == '__main__':
    create_app_icon()
