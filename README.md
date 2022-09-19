# Converting Debian dkms packages to binary packages
This tool converts Debian dkms packages to binary packages.
The generated packages are compatible with [code-signing](https://salsa.debian.org/ftp-team/code-signing/) from Debian.

For configuration options look into `config.yaml`.

## Needed tools
* Docker

## Usage
* Build docker container: `docker build -t dkms .`
* Run container: 

```bash
docker run \
    -v $(pwd)/packages:/packages \
    -v $(pwd)/config.yaml:/config.yaml \
    -v $(pwd)/debian-template:/debian-template \
    -v $(pwd)/broadcom-sta-template:/broadcom-sta-template \
    -v $(pwd)/nvidia-template:/nvidia-template \
    --rm -it dkms
```