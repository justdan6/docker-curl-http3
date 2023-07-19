# What is this?
Curl with HTTP/3 (using [quictls](https://github.com/quictls/openssl)) and [Brotli](https://github.com/google/brotli) support

```
docker run --rm justdanz/curl-http3:latest curl --version 


curl 8.2.0-DEV (aarch64-unknown-linux-musl) libcurl/8.2.0-DEV OpenSSL/3.0.9 zlib/1.2.13 brotli/1.0.9 nghttp2/1.53.0 ngtcp2/0.17.0 nghttp3/0.13.0
Release-Date: [unreleased]
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS brotli HSTS HTTP2 HTTP3 HTTPS-proxy IPv6 Largefile libz NTLM NTLM_WB SSL threadsafe TLS-SRP UnixSockets
```

# How to use this image
```
docker pull justdanz/curl-http3:latest

docker run --rm justdanz/curl-http3:latest curl -sIL https://blog.cloudflare.com --http3 -H 'user-agent: mozilla'
```
