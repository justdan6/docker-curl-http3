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
  linux-headers

# https://curl.se/docs/http3.html
RUN git clone --depth 1 -b openssl-3.0.9+quic https://github.com/quictls/openssl \
    && cd openssl \
    && ./config enable-tls1_3 --prefix=/usr/local/quictls \
    && make \
    && make install

RUN cd .. \
    && git clone -b v0.13.0 https://github.com/ngtcp2/nghttp3 \
    && cd nghttp3 \
    && autoreconf -fi \
    && ./configure --prefix=/usr/local/nghttp3 --enable-lib-only \
    && make \
    && make install

RUN cd .. \
    && git clone -b v0.17.0 https://github.com/ngtcp2/ngtcp2 \
    && cd ngtcp2 \
    && autoreconf -fi \
    && ./configure PKG_CONFIG_PATH=/usr/local/quictls/lib/pkgconfig:/usr/local/nghttp3/lib/pkgconfig LDFLAGS="-Wl,-rpath,/usr/local/quictls/lib" --prefix=/usr/local/ngtcp2 --enable-lib-only \
    && make \
    && make install

RUN cd .. \
    && git clone https://github.com/curl/curl \
    && cd curl \
    && autoreconf -fi \
    && LDFLAGS="-Wl,-rpath,/usr/local/quictls/lib" ./configure -with-zlib --with-brotli --with-openssl=/usr/local/quictls --with-nghttp3=/usr/local/nghttp3 --with-ngtcp2=/usr/local/ngtcp2 \
    && make \
    && make install

FROM alpine:3.18

COPY --from=base /usr/local/bin/curl /usr/local/bin/curl
COPY --from=base /usr/local/lib/libcurl.so.4 /usr/local/lib/libcurl.so.4
COPY --from=base /usr/local/nghttp3/lib/libnghttp3.so.8 /usr/local/nghttp3/lib/libnghttp3.so.8
COPY --from=base /usr/local/ngtcp2/lib/libngtcp2_crypto_quictls.so.0 /usr/local/ngtcp2/lib/libngtcp2_crypto_quictls.so.0
COPY --from=base /usr/local/ngtcp2/lib/libngtcp2.so.14 /usr/local/ngtcp2/lib/libngtcp2.so.14
COPY --from=base /usr/lib/libnghttp2.so.14 /usr/lib/libnghttp2.so.14
COPY --from=base /usr/local/quictls/lib/libssl.so.81.3 /usr/local/quictls/lib/libssl.so.81.3
COPY --from=base /usr/local/quictls/lib/libcrypto.so.81.3 /usr/local/quictls/lib/libcrypto.so.81.3
COPY --from=base /usr/lib/libbrotlidec.so.1 /usr/lib/libbrotlidec.so.1
COPY --from=base /usr/lib/libbrotlicommon.so.1 /usr/lib/libbrotlicommon.so.1

USER nobody
RUN env | sort; which curl; curl --version