FROM alpine:3.24.3
RUN apk add --no-cache nginx openssl brotli \
    && mkdir -p /srv /certs \
    && printf 'curl integration test\n' > /srv/plain.txt \
    && brotli --output=/srv/brotli /srv/plain.txt \
    && openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj /CN=server -addext subjectAltName=DNS:server \
        -keyout /certs/key.pem -out /certs/cert.pem
COPY nginx.conf /etc/nginx/nginx.conf
CMD ["nginx", "-g", "daemon off;"]
