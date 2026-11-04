# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.24.3
FROM alpine:${ALPINE_VERSION} AS build

RUN apk add --no-cache \
    autoconf automake brotli-dev build-base ca-certificates git libpsl-dev \
    libtool linux-headers perl pkgconf zlib-dev

ARG BUILD_JOBS=4
ENV PKG_CONFIG_PATH=/opt/curl/lib/pkgconfig \
    LD_LIBRARY_PATH=/opt/curl/lib
WORKDIR /src

# OpenSSL's QUIC TLS API replaces the deprecated quictls backend.
# A fixed libdir works on both 32-bit and 64-bit architectures.
ARG OPENSSL_VERSION=4.1.0
RUN git clone --depth 1 --branch "openssl-${OPENSSL_VERSION}" https://github.com/openssl/openssl.git \
    && cd openssl \
    && ./config --prefix=/opt/curl --openssldir=/etc/ssl --libdir=lib shared no-tests \
    && make -j"${BUILD_JOBS}" \
    && make install_sw

ARG NGHTTP2_VERSION=1.71.0
RUN git clone --depth 1 --branch "v${NGHTTP2_VERSION}" https://github.com/nghttp2/nghttp2.git \
    && cd nghttp2 \
    && autoreconf -fi \
    && ./configure --prefix=/opt/curl --enable-lib-only --disable-static \
    && make -j"${BUILD_JOBS}" \
    && make install

ARG NGHTTP3_VERSION=1.19.0
RUN git clone --depth 1 --branch "v${NGHTTP3_VERSION}" --recurse-submodules --shallow-submodules https://github.com/ngtcp2/nghttp3.git \
    && cd nghttp3 \
    && autoreconf -fi \
    && ./configure --prefix=/opt/curl --enable-lib-only --disable-static \
    && make -j"${BUILD_JOBS}" \
    && make install

ARG NGTCP2_VERSION=1.26.0
RUN git clone --depth 1 --branch "v${NGTCP2_VERSION}" https://github.com/ngtcp2/ngtcp2.git \
    && cd ngtcp2 \
    && autoreconf -fi \
    && ./configure --prefix=/opt/curl --enable-lib-only --disable-static --with-openssl \
    && make -j"${BUILD_JOBS}" \
    && make install

ARG CURL_VERSION=8.23.0
# The release archive contains the finalized version/date; the Git tag reports -DEV.
ARG CURL_SHA256=e3de77cfa6367083c776a26647fc9f633b538c06c3baa73d931a252ac8f72b49
RUN wget -q -O curl.tar.gz "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" \
    && echo "${CURL_SHA256}  curl.tar.gz" | sha256sum -c - \
    && tar -xzf curl.tar.gz \
    && cd "curl-${CURL_VERSION}" \
    && ./configure --prefix=/opt/curl --disable-static \
        --with-zlib --with-brotli --with-libpsl --with-nghttp2=/opt/curl \
        --with-openssl=/opt/curl --with-nghttp3=/opt/curl --with-ngtcp2=/opt/curl \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-path=/etc/ssl/certs \
    && make -j"${BUILD_JOBS}" \
    && make install \
    && find /opt/curl/lib -type f \( -name '*.a' -o -name '*.la' \) -delete

FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache brotli-libs ca-certificates libpsl zlib

# Keep the actual SONAMEs and symlinks instead of hard-coding ABI versions.
COPY --from=build /opt/curl/bin/curl /usr/local/bin/curl
COPY --from=build /opt/curl/lib/ /opt/curl/lib/
ENV LD_LIBRARY_PATH=/opt/curl/lib

USER nobody
RUN curl --version \
    && curl --version | grep -w HTTP2 \
    && curl --version | grep -w HTTP3 \
    && curl --version | grep -w brotli

CMD ["curl", "--version"]
