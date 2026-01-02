#!/usr/bin/env python3
"""
Generate app icon PNG from the Flutter MblAppIcon design.
This recreates the icon design using Python PIL/Pillow.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon():
    """Create the MBL app icon matching the Flutter design."""
    size = 1024
    
    # Create image with white background
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Helper function for percentages
    def pct(percentage):
        return int(size * percentage)
    
    # Background decorative circles
    # Top-left blue circle (subtle)
    draw.ellipse(
        [pct(0.048), pct(0.048), pct(0.244), pct(0.244)],
        fill=(59, 130, 246, 13)
    )
    
    # Bottom-right green circle
    draw.ellipse(
        [pct(0.737), pct(0.737), pct(0.971), pct(0.971)],
        fill=(16, 185, 129, 13)
    )
    
    # Main blue container with rounded corners
    main_rect = [
        pct(0.158), pct(0.158),
        pct(0.842), pct(0.842)
    ]
    corner_radius = pct(0.156)
    
    # Draw shadow (simple approach - multiple blurred rectangles)
    for i in range(5):
        shadow_offset = i * 2
        shadow_alpha = max(0, 25 - i * 5)
        draw.rounded_rectangle(
            [
                main_rect[0] + shadow_offset,
                main_rect[1] + shadow_offset,
                main_rect[2] + shadow_offset,
                main_rect[3] + shadow_offset
            ],
            radius=corner_radius,
            fill=(0, 0, 0, shadow_alpha)
        )
    
    # Blue gradient container (approximated with solid blue)
    draw.rounded_rectangle(
        main_rect,
        radius=corner_radius,
        fill=(46, 121, 230, 255)  # Mid-point between gradient colors
    )
    
    # Inner decorative circles (white with opacity)
    draw.ellipse(
        [pct(0.215), pct(0.215), pct(0.371), pct(0.371)],
        fill=(255, 255, 255, 23)
    )
    draw.ellipse(
        [pct(0.609), pct(0.609), pct(0.805), pct(0.805)],
        fill=(255, 255, 255, 23)
    )
    
    # Top curved accent line (approximated with arc)
    draw.arc(
        [pct(0.244), pct(0.220), pct(0.756), pct(0.320)],
        start=0, end=180,
        fill=(255, 255, 255, 46),
        width=pct(0.008)
    )
    
    # MBL Text
    try:
        # Try different font paths for different systems
        font_paths = [
            '/System/Library/Fonts/Supplemental/Arial Bold.ttf',  # macOS
            '/Library/Fonts/Arial Bold.ttf',  # macOS alternative
            '/System/Library/Fonts/Helvetica.ttc',  # macOS
            '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',  # Linux
            'C:\\Windows\\Fonts\\arialbd.ttf',  # Windows
        ]
        
        font_size = pct(0.273)
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                try:
                    font = ImageFont.truetype(font_path, font_size)
                    break
                except:
                    continue
        
        if font is None:
            font = ImageFont.load_default()
    except Exception as e:
        print(f"Warning: Could not load font: {e}")
        font = ImageFont.load_default()
    
    # Draw "MBL" text
    text = "MBL"
    
    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Calculate position to center text
    text_x = (size - text_width) // 2
    text_y = pct(0.42)
    
    # Draw text shadow
    for offset in range(1, 4):
        draw.text(
            (text_x + offset, text_y + offset),
            text,
            font=font,
            fill=(0, 0, 0, 40)
        )
    
    # Draw main text
    draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 255))
    
    # Bottom accent line with dots
    line_y = pct(0.684)
    draw.line(
        [pct(0.324), line_y, pct(0.676), line_y],
        fill=(255, 255, 255, 90),
        width=pct(0.006)
    )
    
    # Left dot (green)
    draw.ellipse(
        [pct(0.297), pct(0.676), pct(0.313), pct(0.692)],
        fill=(16, 185, 129, 242)
    )
    
    # Right dot (orange)
    draw.ellipse(
        [pct(0.687), pct(0.676), pct(0.703), pct(0.692)],
        fill=(245, 158, 11, 242)
    )
    
    # Corner decorative dots
    dot_radius = pct(0.012)
    corner_dots = [
        (pct(0.225), pct(0.225)),
        (pct(0.775), pct(0.225)),
        (pct(0.225), pct(0.775)),
        (pct(0.775), pct(0.775)),
    ]
    
    for dot_x, dot_y in corner_dots:
        draw.ellipse(
            [dot_x - dot_radius, dot_y - dot_radius,
             dot_x + dot_radius, dot_y + dot_radius],
            fill=(255, 255, 255, 46)
        )
    
    return img

def main():
    # Create assets/icon directory if it doesn't exist
    os.makedirs('assets/icon', exist_ok=True)
    
    # Generate the main icon (1024x1024)
    print("Generating app icon...")
    icon = create_app_icon()
    icon.save('assets/icon/app_icon.png')
    print("✅ Created: assets/icon/app_icon.png")
    
    # Also save as foreground (same design)
    icon.save('assets/icon/app_icon_foreground.png')
    print("✅ Created: assets/icon/app_icon_foreground.png")
    
    print("\n✨ Icon generation complete!")
    print("📱 Now run: dart run flutter_launcher_icons")
    print("\nNext steps:")
    print("1. Run: flutter pub get (if needed)")
    print("2. Run: dart run flutter_launcher_icons")
    print("3. Rebuild your app to see the new icon")

if __name__ == '__main__':
    main()
