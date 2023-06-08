FROM ubuntu:focal
RUN apt update

# Dependencies for building gcc
RUN apt install -y build-essential
RUN apt install -y bison
RUN apt install -y flex
RUN apt install -y libgmp3-dev
RUN apt install -y libmpc-dev
RUN apt install -y libmpfr-dev
RUN DEBIAN_FRONTEND=noninteractive apt install -y texinfo

# Install git
RUN apt install -y git

# Download everything we're going to build ourselves
RUN mkdir /repos
WORKDIR /repos
RUN git clone --depth 1 https://sourceware.org/git/binutils-gdb.git
RUN git clone --depth 1 git://gcc.gnu.org/git/gcc.git
RUN git clone --depth 1 git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
RUN git clone --depth 1 https://sourceware.org/git/glibc.git
RUN git clone --depth 1 https://sourceware.org/git/newlib-cygwin.git
RUN git clone --depth 1 https://git.busybox.net/busybox
RUN git clone --depth 1 https://github.com/riscv-software-src/riscv-pk.git

# Cross build options
ENV TARGET=riscv32-unknown-elf
ENV PREFIX=/cross
ENV PATH="${PREFIX}/bin:$PATH"
ENV RISCV=/cross
ENV NTHREADS=10

# Out-of-tree builds
RUN mkdir /builds

# Build cross binutils
RUN mkdir /builds/${TARGET}-binutils
WORKDIR /builds/${TARGET}-binutils
RUN /repos/binutils-gdb/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --with-sysroot \
    --disable-nls \
    --disable-werror
RUN make -j${NTHREADS}
RUN make install -j${NTHREADS}

# Build stage-1 cross GCC
RUN mkdir /builds/${TARGET}-gcc-stage1
WORKDIR /builds/${TARGET}-gcc-stage1
RUN /repos/gcc/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --disable-nls \
    --enable-languages=c,c++ \
    --with-newlib \
    --without-headers \
    --with-arch=rv32gc \
    --with-abi=ilp32d
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

# Build stage-2 cross GCC - can this just be put in the same build dir as stage 1?
RUN mkdir /builds/${TARGET}-gcc-stage2
WORKDIR /builds/${TARGET}-gcc-stage2
RUN /repos/gcc/configure \
    --host=`gcc -dumpmachine` \
    --target=${TARGET} \
    --prefix="${PREFIX}" \
    --disable-nls \
    --enable-languages=c,c++ \
    --without-headers \
    --with-newlib \
    --with-arch=rv32gc \
    --with-abi=ilp32d
RUN make -j${NTHREADS}
RUN make install

# Now let's produce a riscv proxy kernel
RUN mkdir /builds/riscv-pk
WORKDIR /builds/riscv-pk
RUN /repos/riscv-pk/configure \
    --host=${TARGET} \
    --prefix="${PREFIX}" \
    --enable-32bit
RUN make -j${NTHREADS}
RUN make install

WORKDIR /