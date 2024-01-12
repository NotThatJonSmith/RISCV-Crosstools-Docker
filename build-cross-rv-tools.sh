#!/bin/bash

function build_cross_toolchain()
{
    XLEN=$1
    BAREMETAL=$2

    # Cross build options
    export PREFIX=/cross
    export SYSROOT=/cross_sysroot
    export PATH=$PREFIX/bin:$PATH
    export NTHREADS=10

    # Place for out-of-tree builds
    mkdir -p /builds

    if [ $BAREMETAL == 1 ]
    then
        TARGET=riscv${XLEN}-unknown-elf
    else
        TARGET=riscv${XLEN}-linux-gnu
    fi
    TARGET_ARCH=rv${XLEN}gc
    if [ $XLEN == 32 ]
    then
        TARGET_ABI=ilp32d
    else
        TARGET_ABI=lp64d
    fi

    # Build cross binutils
    mkdir /builds/$TARGET-binutils
    cd /builds/$TARGET-binutils
    if [ $BAREMETAL == 1 ]
    then
        /repos/binutils-gdb/configure \
            --host=`gcc -dumpmachine` \
            --target=$TARGET \
            --prefix=$PREFIX \
            --with-sysroot \
            --disable-nls \
            -disable-werror
    else
        /repos/binutils-gdb/configure \
            --host=`gcc -dumpmachine` \
            --target=$TARGET \
            --prefix=$PREFIX \
            --with-sysroot=$SYSROOT \
            --disable-nls \
            -disable-werror
    fi
    make -j$NTHREADS
    make install -j$NTHREADS

    # Build stage-1 cross GCC
    mkdir /builds/$TARGET-gcc
    cd /builds/$TARGET-gcc
    if [ $BAREMETAL == 1 ]
    then
        /repos/gcc/configure \
            --host=`gcc -dumpmachine` \
            --target=$TARGET \
            --prefix=$PREFIX \
            --with-arch=$TARGET_ARCH \
            --with-abi=$TARGET_ABI \
            --enable-languages=c,c++ \
            --with-newlib \
            --without-headers \
            --disable-nls
    else
        /repos/gcc/configure \
            --host=`gcc -dumpmachine` \
            --target=$TARGET \
            --prefix=$PREFIX \
            --with-glibc-version=2.37 \
            --with-newlib \
            --with-sysroot=$SYSROOT \
            --with-arch=$TARGET_ARCH \
            --with-abi=$TARGET_ABI \
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
    fi
    make all-gcc -j$NTHREADS
    make all-target-libgcc -j$NTHREADS
    make install-gcc -j$NTHREADS
    make install-target-libgcc -j$NTHREADS

    # Build the C standard library
    if [ $BAREMETAL == 1 ]
    then
        # Build newlib
        mkdir /builds/$TARGET-newlib
        cd /builds/$TARGET-newlib
        /repos/newlib-cygwin/configure \
            --srcdir=/repos/newlib-cygwin \
            --target=$TARGET \
            --prefix=$PREFIX \
            `gcc -dumpmachine`
        make -j$NTHREADS
        make install
    else
        # Install linux headers into our cross-tools directory structure
        cd /repos/linux
        make headers_install ARCH=riscv INSTALL_HDR_PATH=$SYSROOT/usr
        # Write down the kernel version so we can use it later
        KERNEL_VERSION=$(make kernelversion)
        # Build glibc into the sysroot, referencing those linux headers
        mkdir /builds/$TARGET-glibc
        cd /builds/$TARGET-glibc
        /repos/glibc/configure \
            --prefix=$SYSROOT/usr/local \
            --build=$(/repos/glibc/scripts/config.guess) \
            --host=$TARGET \
            --with-headers=$SYSROOT/usr/include \
            --enable-kernel=$KERNEL_VERSION
        make -j$NTHREADS
        make DESTDIR=$SYSROOT install
    fi

    # Build final cross-GCC
    cd /builds/$TARGET-gcc
    make -j$NTHREADS
    make install

}