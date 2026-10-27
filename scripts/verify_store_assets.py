import os
from PIL import Image

base = r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Gorselleri"

subdirs = [
    ("01_Apple_AppStore_6.9_iPhone_1320x2868", (1320, 2868), 6),
    ("02_Apple_AppStore_6.7_iPhone_1290x2796", (1290, 2796), 6),
    ("03_Apple_AppStore_6.5_iPhone_1284x2778", (1284, 2778), 6),
    ("04_Apple_AppStore_5.5_iPhone_1242x2208", (1242, 2208), 6),
    ("05_Apple_AppStore_13.0_iPadPro_2048x2732", (2048, 2732), 6),
    ("06_GooglePlay_Telefon_1080x2400", (1080, 2400), 6),
    ("07_GooglePlay_Tanitim_Gorseli_1024x500", (1024, 500), 1),
    ("08_GooglePlay_Uygulama_Simgesi_512x512", (512, 512), 1),
    ("09_GooglePlay_Tablet_Gorselleri", None, 12),
]

all_passed = True

print(f"{'DIRECTORY / FILE':<55} | {'SIZE':<14} | {'MODE':<5} | {'BANDS':<15} | {'STATUS'}")
print("-" * 105)

for folder, exp_size, exp_count in subdirs:
    dp = os.path.join(base, folder)
    if not os.path.exists(dp):
        print(f"MISSING FOLDER: {folder}")
        all_passed = False
        continue
    files = sorted([f for f in os.listdir(dp) if f.endswith(".png")])
    if exp_count is not None and len(files) != exp_count:
        print(f"COUNT MISMATCH in {folder}: expected {exp_count}, got {len(files)}")
        all_passed = False

    for f in files:
        fp = os.path.join(dp, f)
        with Image.open(fp) as im:
            bands = str(im.getbands())
            size_ok = (im.size == exp_size) if exp_size else True
            mode_ok = (im.mode == "RGB")
            status = "PASS" if (size_ok and mode_ok) else "FAIL"
            if status != "PASS":
                all_passed = False
            print(f"{f:<55} | {str(im.size):<14} | {im.mode:<5} | {bands:<15} | {status}")

print("=" * 105)
print("FINAL STORE COMPLIANCE STATUS:", "100% STORE READY (ALL PASSED)" if all_passed else "FAILURES DETECTED")
