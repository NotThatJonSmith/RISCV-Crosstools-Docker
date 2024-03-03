# RISC-V Cross Tools Utility Belt

I have a toy RISC-V simulator I wrench on for fun, for which I'd like to compile code.

Setting up a cross compiler is always a chore, and doing so for a variety of host platforms is even worse. I learned this when moving laptops.

So, I went with a Docker approach.

Set up the docker image locally:
```
git submodule update --init
docker build -t crosstools
```

Run this repo's makefile flow from within the container:
```
docker run --rm --mount type=bind,source="$(pwd)",target=/host_mount_dir crosstools /host_mount_dir/build-me.sh
```

The container bind-mounts the current working dir, and then effective does "make" here, but with the superpower of having a stable cross-compiler setup.

## A little more detail

`git submodule update --init`: there's a heap of submodules under `external`. It's a mixture of components required to build the cross toolchain in the image (container? idk) and components to cross-build for risc-v systems.

`docker build -t crosstools` sets up an Ubuntu (one day something slimmer, I hope) system with all the GCC build prerequisites.

Then, it copies the whole `external` dir into `/repos` in the docker image.

Then, it copies the script `build-cross-rv-tools.sh` in, and runs it several times to set up the cross tools you need.

The `Makefile` here is meant to be run from within the container. I wrap it with a short bash script (I honestly forgot why) and run it like this:

```
docker run --rm --mount type=bind,source="$(pwd)",target=/host_mount_dir crosstools /host_mount_dir/build-me.sh
```

So now we have a `make` project that has access to a risc-v cross toolchain. Neat!

There are probably a million and one ways to make this cleaner and better.