FROM ubuntu:focal
RUN apt update

# Dependencies for building gcc
RUN apt install -y build-essential
RUN apt install -y bison
RUN apt install -y flex
RUN apt install -y libgmp3-dev
RUN apt install -y libmpc-dev
RUN apt install -y libmpfr-dev
RUN apt install -y gawk
RUN apt install -y python
RUN apt install -y python3
RUN DEBIAN_FRONTEND=noninteractive apt install -y texinfo

# Linux kernel build dependencies
RUN apt install -y bc
RUN apt install -y wget
RUN apt install -y rsync
RUN apt install -y libssl-dev
RUN apt install -y libelf-dev

# Other utilities that ease along system image construction
RUN apt install -y libncurses-dev
RUN apt install -y device-tree-compiler
RUN apt install -y git

COPY external /repos
COPY build-cross-rv-tools.sh /bin/build-cross-rv-tools.sh
RUN /bin/bash -c "source /bin/build-cross-rv-tools.sh && build_cross_toolchain 32 1"
RUN /bin/bash -c "source /bin/build-cross-rv-tools.sh && build_cross_toolchain 32 0"
RUN /bin/bash -c "source /bin/build-cross-rv-tools.sh && build_cross_toolchain 64 1"
RUN /bin/bash -c "source /bin/build-cross-rv-tools.sh && build_cross_toolchain 64 0"

WORKDIR /