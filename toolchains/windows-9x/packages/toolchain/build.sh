#! /bin/sh

# These versions are the ones used on the old buildbot
BINUTILS_VERSION=2.32-1
GCC_VERSION=9.2.0-3
MINGWRT_VERSION=5.4.2
W32API_VERSION=5.4.2

# This package is inspired by dc-chain scripts for KallistiOS. Credits go to them.

PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HELPERS_DIR=$PACKAGE_DIR/../..
. $HELPERS_DIR/functions.sh

target=${HOST}
prefix=${MINGW32}

do_make_bdir

# Add our (to be built) tools to path
export PATH="${PATH}:${prefix}/bin"

# Binutils
do_http_fetch binutils "https://osdn.net/dl/mingw/binutils-${BINUTILS_VERSION}-mingw32-src.tar.xz" 'tar xJf'

for p in arch/mingw32/*.patch; do
	echo "Applying $p"
	patch -t -p1 < "$p"
done

./configure --target=${target} --prefix="${prefix}" --disable-werror
do_make
do_make install

cd ..

# GCC...
do_http_fetch gcc "https://osdn.net/dl/mingw/gcc-${GCC_VERSION}-mingw32-src.tar.xz" 'tar xJf'

for p in arch/mingw32/*.patch; do
	echo "Applying $p"
	patch -t -p1 < "$p"
done

# Do off tree build
GCC_DIR=$(pwd)

cd ..

# ... stage 1
mkdir gcc-build-stage1
cd gcc-build-stage1

"${GCC_DIR}"/configure \
	--target=${target} \
	--prefix="${prefix}" \
	--without-headers \
	--with-arch=i586 \
	--with-tune=generic \
	--with-dwarf2 \
	--enable-languages=c \
	--enable-static \
	--enable-shared \
	--enable-nls \
	--enable-threads \
	--enable-libstdcxx-debug \
	--enable-version-specific-runtime-lib \
	--disable-win32-registry \
	--disable-sjlj-exceptions \
	--disable-vtv \
	--disable-build-format-warnings
do_make all-gcc
do_make install-gcc

cd ..

# mingwrt and w32api
do_http_fetch w32api "https://osdn.net/dl/mingw/w32api-${W32API_VERSION}-mingw32-src.tar.xz" 'tar xJf'
cd ..

do_http_fetch mingwrt "https://osdn.net/dl/mingw/mingwrt-${MINGWRT_VERSION}-mingw32-src.tar.xz" 'tar xJf'
do_patch mingwrt

touch include/features.h

./configure \
	--host=${target} \
	--prefix="${prefix}/${target}"
do_make -j1
do_make install

cd ../w32api-${W32API_VERSION}
./configure \
	--host=${target} \
	--prefix="${prefix}/${target}"
do_make -j1
do_make install

cd ..

# GCC...
# ... stage 2
mkdir gcc-build-stage2
cd gcc-build-stage2

"${GCC_DIR}"/configure \
	--target=${target} \
	--prefix="${prefix}" \
	--with-arch=i586 \
	--with-tune=generic \
	--with-dwarf2 \
	--enable-languages=c,c++ \
	--enable-static \
	--enable-shared \
	--enable-nls \
	--enable-threads \
	--enable-libstdcxx-debug \
	--enable-version-specific-runtime-lib \
	--disable-win32-registry \
	--disable-sjlj-exceptions \
	--disable-vtv \
	--disable-build-format-warnings
do_make
do_make install

cd ..

cat > "${prefix}/bin/${target}-pkg-config" <<EOF
#! /bin/sh
PKG_CONFIG_LIBDIR="${prefix}/${target}/lib/pkgconfig" pkg-config "\$@"
EOF
chmod +x "${prefix}/bin/${target}-pkg-config"

do_clean_bdir

# Cleanup wget HSTS
rm -f $HOME/.wget-hsts
