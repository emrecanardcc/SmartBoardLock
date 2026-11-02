import zipfile
import os

zip_path = '/home/ubuntu/downloads/web_admin_vm.zip'
target_dir = '/home/ubuntu/downloads/admin'

with zipfile.ZipFile(zip_path, 'r') as z:
    for member in z.infolist():
        clean_filename = member.filename.replace('\\', '/')
        if clean_filename.startswith('/'):
            clean_filename = clean_filename[1:]
        dest_path = os.path.join(target_dir, clean_filename)
        
        if member.is_dir() or clean_filename.endswith('/'):
            os.makedirs(dest_path, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            with open(dest_path, 'wb') as outfile:
                outfile.write(z.read(member))

print("EXTRACT_CLEAN_OK")
