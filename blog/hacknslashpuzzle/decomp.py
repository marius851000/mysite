import os
import subprocess
import shutil

infolder = "Saves/"
outfolder = "Savesdec/"
def recurse(path):
    for fn in os.listdir(path):
        sub_path = os.path.join(path, fn)
        if os.path.isdir(sub_path):
            recurse(sub_path)
        else:
            s = open(sub_path, "rb")
            out_path = outfolder + sub_path[len(infolder):]
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            if s.read(4) == b'\x1bLua':
                out = subprocess.check_output(["/nix/store/mafflnsd7hpfnw0dl2i8wsch9zqzja1i-openjdk-19.0.1+10/bin/java", "-jar", "unluac_2020_05_11.jar", sub_path])
                out_file = open(out_path, "wb")
                out_file.write(out)
                out_file.close()
            else:
                shutil.copy(sub_path, out_path)
            s.close()

recurse(infolder)