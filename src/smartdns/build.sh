#!/bin/sh
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
TC="${TC:-/root/hrneo-bin/toolchains}"
OPENSSL_VER=3.5.8
SMARTDNS_TAG=Release48.4
VER=48.4-hrweb6
PATCH="$DIR/smartdns-48.4-hrweb.patch"
ARCHS="${ARCHS:-mipsel}"
SSL_TRIM="no-err no-filenames no-tls1 no-tls1_1 no-ct no-ocsp no-nextprotoneg no-http no-rfc3779 no-multiblock no-autoload-config no-camellia no-aria no-sm2 no-sm3 no-sm4 no-idea no-seed no-whirlpool no-md4 no-mdc2 no-rc2 no-rc4 no-rc5 no-bf no-cast no-des no-dsa no-srp no-cms no-ts no-siphash no-scrypt no-gost no-rmd160 no-ssl3 no-dtls no-cmp no-ocb no-sctp no-srtp no-psk no-weak-ssl-ciphers no-argon2 no-ec2m no-sm2-precomp no-ml-dsa no-slh-dsa"

mkdir -p "$DIR/src" "$DIR/build"
[ -d "$DIR/src/openssl-$OPENSSL_VER" ] || curl -fsSL "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VER/openssl-$OPENSSL_VER.tar.gz" | tar xz -C "$DIR/src"
[ -d "$DIR/src/smartdns-48.4" ] || git clone -q --depth 1 --branch "$SMARTDNS_TAG" https://github.com/pymumu/smartdns.git "$DIR/src/smartdns-48.4"

for arch in $ARCHS; do
    SRC="$DIR/build/$arch/smartdns-src"
    rm -rf "$SRC"
    mkdir -p "$DIR/build/$arch"
    cp -r "$DIR/src/smartdns-48.4/src" "$SRC"
    patch -s -p1 -d "$SRC" < "$PATCH"

    if [ "$arch" = x86_64 ]; then
        make -C "$SRC" -j"$(nproc)" WITH_ZLIB=no NO_GIT_VER=1 VER="$VER" >/dev/null
        cp "$SRC/smartdns" "$DIR/build/smartdns-x86_64"
        rm -rf "$SRC"
        ls -la "$DIR/build/smartdns-x86_64"
        continue
    fi

    case "$arch" in
        mipsel) tc=mipsel-linux-muslsf; target=linux-mips32; rel=mipselsf-k3.4 ;;
        mips) tc=mips-linux-muslsf; target=linux-mips32; rel=mipssf-k3.4 ;;
        aarch64) tc=aarch64-linux-musl; target=linux-aarch64; rel=aarch64-k3.10 ;;
    esac
    CC="$TC/$tc-cross/bin/$tc-gcc"
    AR="$TC/$tc-cross/bin/$tc-ar"
    SSL="$DIR/build/$arch/openssl${TRIM:+-trim}"
    OSRC="$DIR/build/$arch/openssl-src${TRIM:+-trim}"
    if [ ! -f "$SSL/lib/libssl.a" ]; then
        rm -rf "$OSRC"
        cp -r "$DIR/src/openssl-$OPENSSL_VER" "$OSRC"
        (cd "$OSRC" && CC="$CC" AR="$AR" RANLIB="$TC/$tc-cross/bin/$tc-ranlib" ./Configure "$target" \
            no-shared no-tests no-docs no-apps no-engine no-legacy no-comp no-dso no-async no-ui-console ${TRIM:+$SSL_TRIM} \
            --prefix="$SSL" --libdir=lib -Os && make -j"$(nproc)" build_libs >/dev/null && make install_dev >/dev/null)
        rm -rf "$OSRC"
    fi
    (cd "$SRC" && make -j"$(nproc)" CC="$CC" AR="$AR" STATIC=yes WITH_ZLIB=no NO_GIT_VER=1 VER="$VER" \
        CFLAGS="-Os -ffunction-sections -fdata-sections -I$SSL/include -Iinclude" \
        EXTRA_LDFLAGS="-L$SSL/lib -Wl,--gc-sections -s" >/dev/null)
    OUT="$DIR/build/smartdns-$arch${TRIM:+-trim}"
    cp "$SRC/smartdns" "$OUT"
    rm -rf "$SRC"
    if [ -n "$TRIM" ]; then
        mkdir -p "$DIR/release/bin/$rel"
        cp "$OUT" "$DIR/release/bin/$rel/smartdns"
    fi
    ls -la "$OUT"
done

if [ -n "$TRIM" ]; then
    mkdir -p "$DIR/release/src/smartdns"
    cp "$DIR/build.sh" "$PATCH" "$DIR/release/src/smartdns/"
    cp "$DIR/src/smartdns-48.4/LICENSE" "$DIR/release/LICENSE"
    cp "$DIR/src/openssl-$OPENSSL_VER/LICENSE.txt" "$DIR/release/LICENSE.openssl"
fi
