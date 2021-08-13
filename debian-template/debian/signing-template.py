#!/usr/bin/python3

import json
import glob
import argparse
import shutil
import os

parser = argparse.ArgumentParser()
parser.add_argument("package_prefix")
args = parser.parse_args()
package_prefix = args.package_prefix

# TODO Cleanup these variables
template = './debian/signing-template'
pkg_name = f"{package_prefix}-signed-template"
pkg_dir = f"debian/{pkg_name}/usr/share/code-signing/{pkg_name}"
pkg_deb = f"{pkg_dir}/source-template/debian"

# Copy template to correct directory
os.makedirs(pkg_dir)
shutil.copytree(template, pkg_deb)

# Find all kernel modules that need to be signed
to_sign = []
file_path = f"debian/{package_prefix}-unsigned"
for module in glob.glob(f"{file_path}/**/*.ko", recursive=True):
    to_sign.append({"sig_type": "linux-module",
                   "file": module[len(file_path) + 1:]})

# JSON object for code sign server
files = {"packages": {
    f"{package_prefix}-unsigned": {
        "trusted_certs": [],
        "files": to_sign
    }
}}

with open(os.path.join(pkg_dir, "files.json"), 'w') as f:
    json.dump(files, f)

exit(0)
