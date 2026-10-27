import os
import sys
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Gorselleri"
BACKUP_DIR = os.path.join(BASE_DIR, "00_Ham_Ekran_Goruntuleri_Emulator")
ICON_SOURCE = r"c:\Projeler\AkilliTahtaSistemi\mobile\TeacherMobile\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png"

# Target output directories
DIR_APP_69 = os.path.join(BASE_DIR, "01_Apple_AppStore_6.9_iPhone_1320x2868")
DIR_APP_67 = os.path.join(BASE_DIR, "02_Apple_AppStore_6.7_iPhone_1290x2796")
DIR_APP_65 = os.path.join(BASE_DIR, "03_Apple_AppStore_6.5_iPhone_1284x2778")
DIR_APP_55 = os.path.join(BASE_DIR, "04_Apple_AppStore_5.5_iPhone_1242x2208")
DIR_APP_IPAD = os.path.join(BASE_DIR, "05_Apple_AppStore_13.0_iPadPro_2048x2732")

DIR_PLAY_PHONE = os.path.join(BASE_DIR, "06_GooglePlay_Telefon_1080x2400")
DIR_PLAY_FEATURE = os.path.join(BASE_DIR, "07_GooglePlay_Tanitim_Gorseli_1024x500")
DIR_PLAY_ICON = os.path.join(BASE_DIR, "08_GooglePlay_Uygulama_Simgesi_512x512")
DIR_PLAY_TABLET = os.path.join(BASE_DIR, "09_GooglePlay_Tablet_Gorselleri")

def ensure_dirs():
    for d in [
        BACKUP_DIR,
        DIR_APP_69,
        DIR_APP_67,
        DIR_APP_65,
        DIR_APP_55,
        DIR_APP_IPAD,
        DIR_PLAY_PHONE,
        DIR_PLAY_FEATURE,
        DIR_PLAY_ICON,
        DIR_PLAY_TABLET,
    ]:
        os.makedirs(d, exist_ok=True)

def find_source_file(fname, store_type="appstore"):
    """Finds source showcase image across potential backup or active locations."""
    short_name = fname.replace("AppStore_", "").replace("GooglePlay_", "")
    candidates = []
    if store_type == "appstore":
        candidates = [
            os.path.join(BASE_DIR, "AppStore_1290x2796", fname),
            os.path.join(BACKUP_DIR, "_Orijinal_Kaynak_Yedek", "AppStore_1290x2796", fname),
            os.path.join(r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Tasarimlari\App_Store_1290x2796", short_name),
            os.path.join(DIR_APP_67, fname),
        ]
    else:  # googleplay
        candidates = [
            os.path.join(BASE_DIR, "GooglePlay_1080x2400", fname),
            os.path.join(BACKUP_DIR, "_Orijinal_Kaynak_Yedek", "GooglePlay_1080x2400", fname),
            os.path.join(r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Tasarimlari\Google_Play_1080x2400", short_name),
            os.path.join(DIR_PLAY_PHONE, fname),
        ]

    for c in candidates:
        if os.path.exists(c):
            return c
    raise FileNotFoundError(f"Source file not found for {fname} in candidates: {candidates}")

def step1_organize_raw_emulator_files():
    """Moves raw emulator screenshots out of root into 00_Ham_Ekran_Goruntuleri_Emulator."""
    print("--- Step 1: Organizing raw emulator files ---")
    moved_count = 0
    if os.path.exists(BASE_DIR):
        for item in os.listdir(BASE_DIR):
            item_path = os.path.join(BASE_DIR, item)
            # Only move loose PNGs in root
            if os.path.isfile(item_path) and item.lower().endswith(".png"):
                dest_path = os.path.join(BACKUP_DIR, item)
                shutil.move(item_path, dest_path)
                moved_count += 1
                print(f"Moved raw file to backup: {item}")
    print(f"Total raw files moved to {BACKUP_DIR}: {moved_count}")

def save_clean_rgb_png(img, out_path, dpi=(72, 72)):
    """Saves image strictly as 24-bit RGB PNG without alpha channel."""
    if img.mode != "RGB":
        rgb_img = Image.new("RGB", img.size, (11, 15, 25))
        if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
            alpha = img.convert("RGBA").split()[-1]
            rgb_img.paste(img.convert("RGBA"), (0, 0), alpha)
        else:
            rgb_img = img.convert("RGB")
        rgb_img.save(out_path, format="PNG", dpi=dpi, optimize=True)
    else:
        img.save(out_path, format="PNG", dpi=dpi, optimize=True)

def expand_gradient_horizontal(scaled_img, target_w, target_h):
    """
    Pastes scaled_img centered on a target_w x target_h canvas,
    seamlessly extending the leftmost and rightmost column colors across the margins.
    """
    canvas = Image.new("RGB", (target_w, target_h), (11, 15, 25))
    cw, ch = scaled_img.size
    offset_x = (target_w - cw) // 2
    offset_y = (target_h - ch) // 2

    # Fill left margin by repeating the left column of scaled_img
    left_col = scaled_img.crop((0, 0, 1, ch))
    if offset_x > 0:
        left_strip = left_col.resize((offset_x, ch), Image.Resampling.NEAREST)
        canvas.paste(left_strip, (0, offset_y))

    # Fill right margin by repeating the right column of scaled_img
    right_col = scaled_img.crop((cw - 1, 0, cw, ch))
    right_margin = target_w - (offset_x + cw)
    if right_margin > 0:
        right_strip = right_col.resize((right_margin, ch), Image.Resampling.NEAREST)
        canvas.paste(right_strip, (offset_x + cw, offset_y))

    # Fill top/bottom margins if any
    if offset_y > 0:
        top_row = canvas.crop((0, offset_y, target_w, offset_y + 1))
        top_strip = top_row.resize((target_w, offset_y), Image.Resampling.NEAREST)
        canvas.paste(top_strip, (0, 0))

    bottom_margin = target_h - (offset_y + ch)
    if bottom_margin > 0:
        bot_row = canvas.crop((0, offset_y + ch - 1, target_w, offset_y + ch))
        bot_strip = bot_row.resize((target_w, bottom_margin), Image.Resampling.NEAREST)
        canvas.paste(bot_strip, (0, offset_y + ch))

    # Paste the central image
    canvas.paste(scaled_img, (offset_x, offset_y))
    return canvas

def generate_apple_67(files):
    """Generates Apple 6.7\" (1290 x 2796 px) screenshots (iPhone 15 Pro Max, 14 Pro Max)."""
    print("\n--- Generating Apple 6.7\" (1290 x 2796) ---")
    for fname in files:
        src = find_source_file(fname, "appstore")
        dst = os.path.join(DIR_APP_67, fname)
        with Image.open(src) as im:
            if im.size != (1290, 2796):
                im = im.resize((1290, 2796), Image.Resampling.LANCZOS)
            save_clean_rgb_png(im, dst)
            print(f"Generated 6.7\": {fname} -> (1290, 2796) RGB")

def generate_apple_69(files):
    """Generates Apple 6.9\" (1320 x 2868 px) screenshots (iPhone 16 Pro Max)."""
    print("\n--- Generating Apple 6.9\" (1320 x 2868) ---")
    target_w, target_h = 1320, 2868
    for fname in files:
        src = find_source_file(fname, "appstore")
        out_name = fname.replace("AppStore_", "AppStore_6.9_")
        dst = os.path.join(DIR_APP_69, out_name)
        with Image.open(src) as im:
            # Scale proportionally by height (2868 / 2796)
            scale = target_h / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, target_h), Image.Resampling.LANCZOS)
            # Crop tiny horizontal overflow (scaled_w is ~1323, crop 1-2px)
            left = (scaled_w - target_w) // 2
            cropped = scaled.crop((left, 0, left + target_w, target_h))
            save_clean_rgb_png(cropped, dst)
            print(f"Generated 6.9\": {out_name} -> (1320, 2868) RGB")

def generate_apple_65(files):
    """Generates Apple 6.5\" (1284 x 2778 px) screenshots (iPhone 11 Pro Max, 13 Pro Max, XS Max)."""
    print("\n--- Generating Apple 6.5\" (1284 x 2778) ---")
    target_w, target_h = 1284, 2778
    for fname in files:
        src = find_source_file(fname, "appstore")
        out_name = fname.replace("AppStore_", "AppStore_6.5_")
        dst = os.path.join(DIR_APP_65, out_name)
        with Image.open(src) as im:
            scale = target_h / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, target_h), Image.Resampling.LANCZOS)
            res = expand_gradient_horizontal(scaled, target_w, target_h)
            save_clean_rgb_png(res, dst)
            print(f"Generated 6.5\": {out_name} -> (1284, 2778) RGB")

def generate_apple_55(files):
    """Generates Apple 5.5\" (1242 x 2208 px) screenshots (iPhone 8 Plus, 7 Plus)."""
    print("\n--- Generating Apple 5.5\" (1242 x 2208) ---")
    target_w, target_h = 1242, 2208
    for fname in files:
        src = find_source_file(fname, "appstore")
        out_name = fname.replace("AppStore_", "AppStore_5.5_")
        dst = os.path.join(DIR_APP_55, out_name)
        with Image.open(src) as im:
            scale = target_h / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, target_h), Image.Resampling.LANCZOS)
            res = expand_gradient_horizontal(scaled, target_w, target_h)
            save_clean_rgb_png(res, dst)
            print(f"Generated 5.5\": {out_name} -> (1242, 2208) RGB")

def generate_apple_ipad(files):
    """Generates Apple 13.0\" iPad Pro (2048 x 2732 px) screenshots."""
    print("\n--- Generating Apple 13.0\" iPad Pro (2048 x 2732) ---")
    target_w, target_h = 2048, 2732
    for fname in files:
        src = find_source_file(fname, "appstore")
        out_name = fname.replace("AppStore_", "AppStore_iPad_")
        dst = os.path.join(DIR_APP_IPAD, out_name)
        with Image.open(src) as im:
            scale = target_h / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, target_h), Image.Resampling.LANCZOS)
            res = expand_gradient_horizontal(scaled, target_w, target_h)
            save_clean_rgb_png(res, dst)
            print(f"Generated iPad: {out_name} -> (2048, 2732) RGB")

def generate_googleplay_phone(files):
    """Generates Google Play Phone (1080 x 2400 px) screenshots."""
    print("\n--- Generating Google Play Phone (1080 x 2400) ---")
    for fname in files:
        src = find_source_file(fname, "googleplay")
        dst = os.path.join(DIR_PLAY_PHONE, fname)
        with Image.open(src) as im:
            if im.size != (1080, 2400):
                im = im.resize((1080, 2400), Image.Resampling.LANCZOS)
            save_clean_rgb_png(im, dst)
            print(f"Generated Play Phone: {fname} -> (1080, 2400) RGB")

def generate_googleplay_tablets(files):
    """Generates Google Play Tablet screenshots (2048 x 2732 px and 1536 x 2048 px)."""
    print("\n--- Generating Google Play Tablet Screenshots ---")
    for fname in files:
        src = find_source_file(fname, "appstore")
        # 10-inch Tablet (2048 x 2732 px)
        out_name_10 = fname.replace("AppStore_", "Play_Tablet_10in_")
        dst_10 = os.path.join(DIR_PLAY_TABLET, out_name_10)
        with Image.open(src) as im:
            scale = 2732 / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, 2732), Image.Resampling.LANCZOS)
            res = expand_gradient_horizontal(scaled, 2048, 2732)
            save_clean_rgb_png(res, dst_10)

        # 7-inch Tablet (1536 x 2048 px)
        out_name_7 = fname.replace("AppStore_", "Play_Tablet_7in_")
        dst_7 = os.path.join(DIR_PLAY_TABLET, out_name_7)
        with Image.open(src) as im:
            scale = 2048 / im.height
            scaled_w = int(round(im.width * scale))
            scaled = im.resize((scaled_w, 2048), Image.Resampling.LANCZOS)
            res = expand_gradient_horizontal(scaled, 1536, 2048)
            save_clean_rgb_png(res, dst_7)

        print(f"Generated Play Tablet: {fname} -> (2048x2732 & 1536x2048) RGB")

def generate_googleplay_app_icon():
    """Generates Google Play 512 x 512 px master App Icon."""
    print("\n--- Generating Google Play App Icon (512 x 512) ---")
    dst = os.path.join(DIR_PLAY_ICON, "AppIcon_Sinif360_512x512.png")
    if os.path.exists(ICON_SOURCE):
        with Image.open(ICON_SOURCE) as im:
            icon_512 = im.resize((512, 512), Image.Resampling.LANCZOS)
            save_clean_rgb_png(icon_512, dst)
            print(f"Generated App Icon: {dst} -> (512, 512) RGB")
    else:
        print(f"ERROR: Master icon not found at {ICON_SOURCE}")

def generate_googleplay_feature_graphic():
    """Generates Google Play 1024 x 500 px Feature Graphic (Tanıtım Görseli) with pristine badges and phone frame."""
    print("\n--- Generating Google Play Feature Graphic (1024 x 500) ---")
    W, H = 1024, 500
    im = Image.new("RGB", (W, H), (10, 15, 29))
    draw = ImageDraw.Draw(im)

    # Background gradient: deep navy to slate indigo to cyber blue
    for y in range(H):
        ratio = y / H
        r = int(9 * (1 - ratio) + 16 * ratio)
        g = int(14 * (1 - ratio) + 24 * ratio)
        b = int(28 * (1 - ratio) + 52 * ratio)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Ambient glow orbs
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([640, -40, 1060, 420], fill=(24, 75, 170))
    glow_draw.ellipse([20, 200, 480, 560], fill=(14, 45, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    im = Image.blend(im, glow, 0.45)
    draw = ImageDraw.Draw(im)

    # Fonts
    font_title = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 44)
    font_sub = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 19)
    font_badge = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 12)
    font_pill_title = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 14)
    font_pill_tag = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 11)

    # Master App Icon with squircle mask and border
    if os.path.exists(ICON_SOURCE):
        with Image.open(ICON_SOURCE) as icon_src:
            icon_sz = 96
            icon = icon_src.convert("RGBA").resize((icon_sz, icon_sz), Image.Resampling.LANCZOS)
            mask = Image.new("L", (icon_sz, icon_sz), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, icon_sz, icon_sz], radius=22, fill=255)
            im.paste(icon, (50, 44), mask)
            draw.rounded_rectangle([49, 43, 49 + icon_sz + 1, 43 + icon_sz + 1], radius=23, outline=(59, 130, 246), width=1)

    # Category Tag
    draw.rounded_rectangle([165, 46, 410, 74], radius=6, fill=(30, 58, 138), outline=(59, 130, 246), width=1)
    draw.text((176, 52), "MEB ETKİLEŞİMLİ TAHTA SİSTEMİ", fill=(147, 197, 253), font=font_badge)

    # App Title & Subtitle
    draw.text((165, 80), "Sınıf360", fill=(255, 255, 255), font=font_title)
    draw.text((50, 155), "Akıllı Tahta & Mobil Öğretmen Yönetimi", fill=(203, 213, 225), font=font_sub)

    # 4 Key Feature Badges with clean styled badges (NO BROKEN TOFU CHARACTERS!)
    features = [
        ("QR", (16, 185, 129), "Dinamik QR Kod ile Anında Kilit Açma"),
        ("TOTP", (59, 130, 246), "%100 Çevrimdışı Güvenlik Algoritması"),
        ("ZİL", (245, 158, 11), "Canlı Ders Süresi & Otomatik Kilit"),
        ("YÖNETİM", (168, 85, 247), "Okul İdaresi ve Öğretmen Kadrosu")
    ]

    py = 208
    for tag, color, text in features:
        # Card container
        draw.rounded_rectangle([50, py, 640, py + 40], radius=8, fill=(15, 23, 42), outline=(30, 41, 59), width=1)
        # Badge
        draw.rounded_rectangle([58, py + 8, 125, py + 32], radius=5, fill=color)
        tbbox = font_pill_tag.getbbox(tag)
        tw = tbbox[2] - tbbox[0]
        draw.text((58 + (67 - tw) // 2, py + 12), tag, fill=(255, 255, 255), font=font_pill_tag)
        # Text
        draw.text((138, py + 11), text, fill=(241, 245, 249), font=font_pill_title)
        py += 48

    # Phone mockup preview on right - full frame intact with realistic alpha drop shadow
    src_mockup = find_source_file("01_AppStore_Canli_Derslik_Takibi.png", "appstore")
    if os.path.exists(src_mockup):
        with Image.open(src_mockup) as card:
            # Full phone crop: x from 205 to 1085, y from 585 to 2440 (complete top bezel and dynamic island)
            phone = card.crop((205, 585, 1085, 2440))
            ph = 450
            pw = int(round(phone.width * (ph / phone.height)))
            phone_resized = phone.resize((pw, ph), Image.Resampling.LANCZOS)

            # Soft blur shadow
            shadow = Image.new("RGBA", (pw + 40, ph + 40), (0, 0, 0, 0))
            sdraw = ImageDraw.Draw(shadow)
            sdraw.rounded_rectangle([12, 12, pw + 28, ph + 28], radius=32, fill=(0, 0, 0, 140))
            shadow = shadow.filter(ImageFilter.GaussianBlur(12))

            px = 750
            py = 25
            im.paste(shadow, (px - 20, py - 10), shadow)
            im.paste(phone_resized, (px, py))

    dst = os.path.join(DIR_PLAY_FEATURE, "FeatureGraphic_Sinif360_1024x500.png")
    save_clean_rgb_png(im, dst)
    print(f"Generated Feature Graphic: {dst} -> (1024, 500) RGB")

def step_cleanup_googleplay_phone_folder():
    """Ensures any loose raw images in GooglePlay folder are clean 24-bit RGB."""
    if os.path.exists(DIR_PLAY_PHONE):
        for f in os.listdir(DIR_PLAY_PHONE):
            if f.endswith(".png"):
                fp = os.path.join(DIR_PLAY_PHONE, f)
                with Image.open(fp) as im:
                    if im.mode != "RGB":
                        save_clean_rgb_png(im, fp)
                        print(f"Converted {f} to pure 24-bit RGB.")

def main():
    print("================================================================================")
    print("      SINIF360 - MAĞAZA GÖRSELLERİ ÜRETİM VE DÜZENLEME MOTORU (v2.1)            ")
    print("================================================================================")
    ensure_dirs()
    step1_organize_raw_emulator_files()

    appstore_files = [
        "01_AppStore_Canli_Derslik_Takibi.png",
        "02_AppStore_Dinamik_QR_Kilit_Acma.png",
        "03_AppStore_Cevrimdisi_TOTP_Guvenlik.png",
        "04_AppStore_Akilli_Ders_Suresi_ve_Kilit.png",
        "05_AppStore_Ogretmen_Kadrosu_Yetkilendirme.png",
        "06_AppStore_Teknik_Destek_ve_Oneri.png",
    ]

    googleplay_files = [
        "01_GooglePlay_Canli_Derslik_Takibi.png",
        "02_GooglePlay_Dinamik_QR_Kilit_Acma.png",
        "03_GooglePlay_Cevrimdisi_TOTP_Guvenlik.png",
        "04_GooglePlay_Akilli_Ders_Suresi_ve_Kilit.png",
        "05_GooglePlay_Ogretmen_Kadrosu_Yetkilendirme.png",
        "06_GooglePlay_Teknik_Destek_ve_Oneri.png",
    ]

    # Apple App Store sets
    generate_apple_67(appstore_files)
    generate_apple_69(appstore_files)
    generate_apple_65(appstore_files)
    generate_apple_55(appstore_files)
    generate_apple_ipad(appstore_files)

    # Google Play Store sets
    generate_googleplay_phone(googleplay_files)
    generate_googleplay_feature_graphic()
    generate_googleplay_app_icon()
    generate_googleplay_tablets(appstore_files)
    step_cleanup_googleplay_phone_folder()

    print("\n================================================================================")
    print("                         TÜM GÖRSELLER BAŞARIYLA ÜRETİLDİ!                      ")
    print("================================================================================")

if __name__ == "__main__":
    main()
