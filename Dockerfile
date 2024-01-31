FROM alpine:3.18 AS base

RUN apk add --no-cache \
  autoconf \
  automake \
  brotli-dev \
  build-base \
  cmake \
  git \
  libtool \
  nghttp2-dev \
  pkgconfig \
  wget \
  zlib-dev \
  linux-headers \
  libpsl-dev

# https://curl.se/docs/http3.html
RUN git clone --depth 1 -b openssl-3.2.1 https://github.com/openssl/openssl \
    && cd openssl \
    && ./config enable-tls1_3 --prefix=/usr/local/openssl \
    && make \
    && make install

# Different architectures use different lib directories
RUN cp -r /usr/local/openssl/lib64 /usr/local/openssl/lib 2>/dev/null || :

RUN cd .. \
    && git clone --depth 1 -b v1.1.0 https://github.com/ngtcp2/nghttp3 \
    && cd nghttp3 \
    && autoreconf -fi \
    && ./configure --prefix=/usr/local/nghttp3 --enable-lib-only \
    && make \
    && make install

RUN cd .. \
    && git clone --depth 1 -b curl-8_6_0 https://github.com/curl/curl \
    && cd curl \
    && autoreconf -fi \
    && export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:/usr/local/nghttp3/lib/pkgconfig:/usr/local/ngtcp2/lib/pkgconfig \
    && LDFLAGS="-Wl,-rpath,/usr/local/openssl/lib" ./configure -with-zlib --with-brotli --with-openssl=/usr/local/openssl --with-openssl-quic --with-nghttp3=/usr/local/nghttp3 \
    && make \
    && make install

FROM alpine:3.18

COPY --from=base /usr/local/bin/curl /usr/local/bin/curl
COPY --from=base /usr/local/lib/libcurl.so.4 /usr/local/lib/libcurl.so.4
COPY --from=base /usr/local/nghttp3/lib/libnghttp3.so /usr/local/nghttp3/lib/libnghttp3.so.9
COPY --from=base /usr/lib/libnghttp2.so /usr/lib/libnghttp2.so.14
COPY --from=base /usr/lib/libpsl.so.5 /usr/lib/libpsl.so.5
COPY --from=base /usr/lib/libidn2.so.0 /usr/lib/libidn2.so.0
COPY --from=base /usr/lib/libunistring.so.5 /usr/lib/libunistring.so.5
COPY --from=base /usr/local/openssl/lib/libssl.so.3 /usr/local/openssl/lib/libssl.so.3
COPY --from=base /usr/local/openssl/lib/libcrypto.so.3 /usr/local/openssl/lib/libcrypto.so.3
COPY --from=base /usr/lib/libbrotlidec.so.1 /usr/lib/libbrotlidec.so.1
COPY --from=base /usr/lib/libbrotlicommon.so.1 /usr/lib/libbrotlicommon.so.1

USER nobody
RUN env | sort; which curl; curl --version