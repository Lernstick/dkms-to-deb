#!/bin/bash

sudo docker build --network=host -t dkms-13 .

sudo docker run \
    -v $(pwd)/packages:/packages \
    -v $(pwd)/config.yaml:/config.yaml \
    -v $(pwd)/debian-template:/debian-template \
    -v $(pwd)/broadcom-sta-template:/broadcom-sta-template \
    -v $(pwd)/nvidia-template:/nvidia-template \
    -v $(pwd)/repo-config:/repo-config \
    --network="host" \
    --rm \
    -it dkms-13
