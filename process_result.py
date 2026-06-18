
import json
import os
import shutil
import sys

def copy_file_or_directory(src, dst):
    if os.path.isdir(src):
        for dirpath, dirnames, filenames in os.walk(src, followlinks=True):
            rel_dir = os.path.relpath(dirpath, src)
            dst_dir = os.path.join(dst, rel_dir)
            os.makedirs(dst_dir, exist_ok=True)

            for filename in filenames:
                src_file = os.path.join(dirpath, filename)
                dst_file = os.path.join(dst_dir, filename)

                copy_file_or_directory(src_file, dst_file)
    else:
        shutil.copy2(src, dst)

def copy_entry(entry):
    print(entry)
    src = entry["input"]
    dst = entry["output"]

    copy_file_or_directory(src, dst)

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <manifest.json>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        entries = json.load(f)

    for entry in entries:
        copy_entry(entry)


if __name__ == "__main__":
    main()
