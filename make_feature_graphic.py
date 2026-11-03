from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

width = 1024
height = 500

# Create base image with clean, elegant gradient background
# Dark slate / deep navy: #0F172A to #1E293B
base = Image.new("RGBA", (width, height), (15, 23, 42, 255))
draw = ImageDraw.Draw(base)

# Draw subtle gradient
for y in range(height):
    ratio = y / height
    r = int(15 + (30 - 15) * ratio)
    g = int(23 + (58 - 23) * ratio)
    b = int(42 + (90 - 42) * ratio)
    draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

# Draw subtle decorative background circles/glow
overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
ov_draw = ImageDraw.Draw(overlay)
ov_draw.ellipse([700, -100, 1150, 350], fill=(25, 118, 210, 45))
ov_draw.ellipse([50, 200, 400, 550], fill=(31, 138, 91, 35))
overlay = overlay.filter(ImageFilter.GaussianBlur(60))
base = Image.alpha_composite(base, overlay)

# Load Logo
logo_path = r"c:\xampp\htdocs\yardimciogretmen\app\logo.png"
logo = Image.open(logo_path).convert("RGBA")

# Resize logo to 320x320
logo_size = 310
logo = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)

# Create rounded card for the logo
card_size = 330
card = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
card_draw = ImageDraw.Draw(card)
# Rounded rect with slight shadow
card_draw.rounded_rectangle([0, 0, card_size, card_size], radius=44, fill=(255, 255, 255, 255))

# Paste logo inside card
logo_offset = (card_size - logo_size) // 2
card.paste(logo, (logo_offset, logo_offset), logo)

# Paste card on base
card_x = 90
card_y = (height - card_size) // 2
base.paste(card, (card_x, card_y), card)

# Setup Fonts
font_dir = r"C:\Windows\Fonts"
font_title = ImageFont.truetype(os.path.join(font_dir, "segoeuib.ttf"), 54)
font_subtitle = ImageFont.truetype(os.path.join(font_dir, "segoeui.ttf"), 24)
font_badge = ImageFont.truetype(os.path.join(font_dir, "segoeuib.ttf"), 16)

draw = ImageDraw.Draw(base)

# Badge: "AKILLI ASİSTAN"
badge_text = "DERS & SINIF YÖNETİMİ"
badge_x = 470
badge_y = 125
badge_w = 230
badge_h = 32
draw.rounded_rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + badge_h], radius=8, fill=(31, 138, 91, 220))
draw.text((badge_x + 16, badge_y + 4), badge_text, font=font_badge, fill=(255, 255, 255, 255))

# Title: ÖğretmenCep
draw.text((470, 175), "ÖğretmenCep", font=font_title, fill=(255, 255, 255, 255))

# Subtitle / Features
draw.text((470, 255), "Öğretmenler İçin Kapsamlı Mobil Asistan", font=font_subtitle, fill=(226, 232, 240, 255))

# Bullet points / feature highlights
features = [
    "•  Haftalık Ders Programı & Plan Takibi",
    "•  Yoklama, Not Çizelgesi & Excel Entegrasyonu",
    "•  %100 Çevrimdışı & Güvenli Veri Saklama"
]
font_features = ImageFont.truetype(os.path.join(font_dir, "segoeui.ttf"), 18)

fy = 310
for feat_line in features:
    draw.text((470, fy), feat_line, font=font_features, fill=(148, 163, 184, 255))
    fy += 32

out_path = r"c:\xampp\htdocs\yardimciogretmen\app\playstore_feature_graphic_1024x500.png"
base.convert("RGB").save(out_path, quality=95)
print(f"Saved feature graphic to {out_path}")
