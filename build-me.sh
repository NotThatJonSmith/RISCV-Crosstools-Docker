#!/bin/bash

# docker run --rm --mount type=bind,source="$(pwd)",target=/host_mount_dir crosstools /host_mount_dir/build-me.sh

cd /host_mount_dir
make all
