# Converting Debian dkms packages to binary packages
This tool converts Debian dkms packages to binary packages.
The generated packages are compatible with [code-signing](https://salsa.debian.org/ftp-team/code-signing/) from Debian.

For configuration options look into `config.yaml`.

## Needed tools
* docker
* sudo

## Usage
* Make sure that repo-config for the internal repositories is present
* Build and run container: `./prepare-dkms-packages.sh`
* Find resulting packages in folder `packages`
* To debug you can use: 

```bash
sudo docker run \
    -v $(pwd)/packages:/packages \
    -v $(pwd)/config.yaml:/config.yaml \
    -v $(pwd)/debian-template:/debian-template \
    -v $(pwd)/broadcom-sta-template:/broadcom-sta-template \
    -v $(pwd)/nvidia-template:/nvidia-template \
    -v $(pwd)/repo-config:/repo-config \
    --network="host" \
    --entrypoint /bin/bash \
    -it dkms-13

# then exit and run "docker start/attach a1b2c3d4"
# "./create_dkms_debs.py config.yaml"
```
