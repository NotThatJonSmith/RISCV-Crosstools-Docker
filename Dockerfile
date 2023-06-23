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

# Install git and clone everything we're going to build ourselves
RUN apt install -y git
RUN mkdir /repos
WORKDIR /repos
RUN git clone --depth 1 https://sourceware.org/git/binutils-gdb.git
RUN git clone --depth 1 git://gcc.gnu.org/git/gcc.git
RUN git clone --depth 1 https://sourceware.org/git/glibc.git
RUN git clone --depth 1 https://sourceware.org/git/newlib-cygwin.git
RUN git clone --depth 1 git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

# Cross build options
ENV TARGET=riscv32-unknown-elf
ENV PREFIX=/cross
ENV PATH="${PREFIX}/bin:$PATH"
ENV NTHREADS=10
ENV SYSROOT=/cross_sysroot

# Place for out-of-tree builds
RUN mkdir /builds

# Build baremetal cross binutils
RUN mkdir /builds/${TARGET}-binutils
WORKDIR /builds/${TARGET}-binutils
RUN /repos/binutils-gdb/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --with-sysroot \
    --disable-nls \
    -disable-werror
RUN make -j${NTHREADS}
RUN make install -j${NTHREADS}

# Build stage-1 bare-metal cross GCC
RUN mkdir /builds/${TARGET}-gcc
WORKDIR /builds/${TARGET}-gcc
RUN /repos/gcc/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --with-arch=rv32gc \
    --with-abi=ilp32d \
    --enable-languages=c,c++ \
    --with-newlib \
    --without-headers \
    --disable-nls
RUN make all-gcc -j${NTHREADS}
RUN make all-target-libgcc -j${NTHREADS}
RUN make install-gcc -j${NTHREADS}
RUN make install-target-libgcc -j${NTHREADS}

# Build newlib
RUN mkdir /builds/${TARGET}-newlib
WORKDIR /builds/${TARGET}-newlib
RUN /repos/newlib-cygwin/configure \
    --srcdir=/repos/newlib-cygwin \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    `gcc -dumpmachine`
RUN make -j${NTHREADS}
RUN make install

# Build final bare-metal cross GCC
WORKDIR /builds/${TARGET}-gcc
RUN make -j${NTHREADS}
RUN make install

# Switch targets from bare-metal to linux-ABI compatibility
ENV TARGET=riscv32-linux-gnu

# Install linux headers into our cross-tools directory structure
WORKDIR /repos/linux
RUN make headers_install ARCH=riscv INSTALL_HDR_PATH=${SYSROOT}/usr

# Write down the kernel version so we can use it later
ENV KERNEL_VERSION $(make kernelversion)

# Build linux cross binutils
RUN mkdir /builds/${TARGET}-binutils
WORKDIR /builds/${TARGET}-binutils
RUN /repos/binutils-gdb/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --with-sysroot=${SYSROOT} \
    --disable-nls \
    -disable-werror
RUN make -j${NTHREADS}
RUN make install -j${NTHREADS}

# Build stage1 linux cross GCC
RUN mkdir /builds/${TARGET}-gcc
WORKDIR /builds/${TARGET}-gcc
RUN /repos/gcc/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --with-glibc-version=2.37 \
    --with-newlib \
    --with-sysroot=${SYSROOT} \
    --with-arch=rv32gc \
    --with-abi=ilp32d \
    --enable-languages=c,c++ \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx
RUN make all-gcc -j${NTHREADS}
RUN make install-gcc -j${NTHREADS}
RUN make all-target-libgcc -j${NTHREADS}
RUN make install-target-libgcc -j${NTHREADS}

# https://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/
# Build glibc into the sysroot, referencing those linux headers
RUN mkdir /builds/${TARGET}-glibc
WORKDIR /builds/${TARGET}-glibc
RUN /repos/glibc/configure \
    --prefix=${SYSROOT}/usr/local \
    --build=$(/repos/glibc/scripts/config.guess) \
    --host=${TARGET} \
    --with-headers=${SYSROOT}/usr/include \
    --enable-kernel=`make -f ../../repos/linux/Makefile kernelversion`
RUN make -j${NTHREADS}
RUN make DESTDIR=${SYSROOT} install


WORKDIR /builds/${TARGET}-gcc
RUN make -j${NTHREADS}
RUN make install

WORKDIR /

RUN rm -rf /repos
RUN rm -rf /builds
