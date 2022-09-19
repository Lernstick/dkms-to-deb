#!/usr/bin/env python3
'''
SPDX-License-Identifier:  GPL-3.0-or-later
Copyright 2021 Thore Sommer
'''


import argparse
import subprocess
import yaml
import shutil
import glob
import logging
from tempfile import TemporaryDirectory
from collections import namedtuple
from string import Template
from datetime import datetime
from email import utils
import os

logging.basicConfig(level=logging.INFO, format='%(levelname)s - %(message)s')

Config = namedtuple("Config", ["k_ver", "k_arch","k_arch_cpu", "kbuild_version", "package_version", "local_repo", "output_dir", "distribution", "packages"])
Package = namedtuple("Package", ["debian_name", "dkms_name", "result_name", "template_dir"])


def parse_config():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_file")
    args = parser.parse_args()
    with open(args.config_file, 'r') as f:
        config = yaml.safe_load(f)
    packages = list()
    for debian_name in config["packages"].keys():
        packages.append(Package(debian_name=debian_name, 
            dkms_name=config["packages"][debian_name]["dkms"], 
            result_name=config["packages"][debian_name]["result"],
            template_dir=config["packages"][debian_name]["template-dir"])
            )
    return Config(k_ver=config["kernel"]["version"],
            k_arch=config["kernel"]["arch"],
            k_arch_cpu=config["kernel"]["arch-cpu"],
            kbuild_version=config["kernel"]["kbuild-version"],
            package_version=config["kernel"]["package-version"],
            output_dir=config["output-dir"], 
            local_repo=config["local-repo"],
            distribution=config["distribution"],
            packages=packages)

def install_kernel(config: Config):
    p = subprocess.run(["apt-get", "update"])
    if p.returncode != 0:
        raise Exception("Package update failed")
    p = subprocess.run(["apt-get", "upgrade", "-y"])
    if p.returncode != 0:
        raise Exception("Package upgrade failed")

    header_arch_name = f'linux-headers-{config.k_ver}-{config.k_arch}'
    header_common_name = f'linux-headers-{config.k_ver}-common'
    kbuild_name = f'linux-kbuild-{config.kbuild_version}'
    # Install exact version
    if config.package_version:
        header_arch_name = f'{header_arch_name}={config.package_version}'
        header_common_name = f'{header_common_name}={config.package_version}'
        kbuild_name = f'{kbuild_name}={config.package_version}'
    p = subprocess.run(["apt-get", "install","--no-install-recommends", "-y", header_arch_name, header_common_name, kbuild_name])
    if p.returncode != 0:
        raise Exception("Kernel installation failed")

def install_package(package: str):
    p = subprocess.run(["apt-get", "install", "--no-install-recommends", "-y", package])
    if p.returncode != 0:
        raise Exception(f"Installation of {package} failed")

def dkms_get_version(package: Package):
    p = subprocess.run(["dkms", "status", package.dkms_name], capture_output=True)
    if p.returncode != 0:
        raise Exception("Running dkms status failed")
    values = p.stdout.decode().rstrip('\n').replace(": ", ", ").split(", ")
    if len(values) != 5:
        raise Exception("Package is not correctly installed")
    return values[1]


def create_dkms_tarball(config: Config, package: Package, dkms_version, tmp_dir):
    kernel_name = f"{config.k_ver}-{config.k_arch}"
    archive = f"{tmp_dir}/{package.dkms_name}-{dkms_version}.dkms.tar.gz"
    p = subprocess.run(["dkms", "mktarball", "-m", package.dkms_name, "-v", dkms_version, "-k", kernel_name, "--archive",  archive])
    if p.returncode != 0:
        raise Exception("Creation of tarball failed")

def subst_variables(config: Config, package: Package, dkms_version: str, tmp_dir):
    package_name = Template(package.result_name).substitute(MODULE_VERSION=dkms_version)
    values = {
        "DEBIAN_PACKAGE": package.debian_name, 
        "MODULE_NAME": package.dkms_name,
        "PACKAGE_NAME": package_name,
        "MODULE_VERSION": dkms_version,
        "TIME_STAMP": utils.format_datetime(datetime.now()),
        "KERNEL_VERSION": f'{config.k_ver}-{config.k_arch}',
        "KERNEL_ARCH_CPU": config.k_arch_cpu,
        "KBUILD_VERSION": config.kbuild_version,
        "DEBIAN_BUILD_ARCH": config.k_arch,
        "DISTRIBUTION": config.distribution
        }
    debian_dir = os.path.join(tmp_dir, "debian")
    for debian_file in glob.glob(f"{debian_dir}/**", recursive=True):
        name, ext = os.path.splitext(debian_file)
        if os.path.isdir(debian_file) or ext != ".in":
            continue
        logging.debug("Substitute variables in: %s", debian_file)
        with open(debian_file, 'r') as f:
            subst = Template(f.read())
        os.remove(debian_file)
        out = subst.substitute(values)
        with open(name, 'w') as f:
            f.write(out)

def build_package(dir):
    logging.info("Building package")
    p = subprocess.run(["dpkg-buildpackage", "-uc", "-us"], cwd=dir)
    if p.returncode != 0:
        raise Exception("Building the package failed")


def create_debian_package(config: Config, package: Package, dkms_version):
    logging.info("Build package for: %s", package.debian_name)
    with TemporaryDirectory(prefix="dkms") as tmp_dir:
        content = os.path.join(tmp_dir, "content")
        logging.debug("Copy template: %s", package.template_dir)
        shutil.copytree(package.template_dir, content)
        logging.debug("Subst vars")
        subst_variables(config, package, dkms_version, content)
        logging.debug("Create Tarball")
        create_dkms_tarball(config, package, dkms_version, content)
        build_package(content)
        logging.debug("Remove build dir")
        shutil.rmtree(content)
        for f in os.listdir(tmp_dir):
            f_src = os.path.join(tmp_dir, f)
            f_dst = os.path.join(config.output_dir, f)
            shutil.copy(f_src, f_dst)

def create_packages(config):
    for package in config.packages:
        install_package(package.debian_name)
        dkms_version = dkms_get_version(package)
        create_debian_package(config, package, dkms_version)

def setup_local_repo(config):
    if not config.local_repo:
        return

def main():
    try:
        config = parse_config()
        setup_local_repo(config)
        install_kernel(config)
        create_packages(config)
    except Exception as e:
        logging.exception(e)
        exit(1)


if __name__ == "__main__":
    main()