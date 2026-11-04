#!/bin/sh
# Tests the selected image against a local TLS/HTTP2/HTTP3/Brotli server.
set -eu

IMAGE=${IMAGE:-justdanz/curl-http3:local}
PLATFORM=${PLATFORM:-$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')}
EXPECTED_VERSION=${EXPECTED_VERSION:-$(sed -n 's/^ARG CURL_VERSION=//p' Dockerfile)}
suffix="$$"
network="curl-http3-test-${suffix}"
server="curl-http3-server-${suffix}"
fixture="curl-http3-fixture:local"
cert_dir=$(mktemp -d)
cleanup() {
    status=$?
    trap - EXIT
    if [ "$status" -ne 0 ]; then docker logs "$server" 2>/dev/null || true; fi
    docker rm -f "$server" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
    rm -rf "$cert_dir"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker build -t "$fixture" tests
docker network create "$network" >/dev/null
docker run -d --name "$server" --network "$network" --network-alias server "$fixture" >/dev/null
docker cp "${server}:/certs/cert.pem" "$cert_dir/cert.pem"
chmod 755 "$cert_dir"
chmod 644 "$cert_dir/cert.pem"

run_curl() {
    docker run --rm --platform "$PLATFORM" --network "$network" \
        -v "$cert_dir:/certs:ro" "$IMAGE" curl \
        --cacert /certs/cert.pem --fail --silent --show-error --max-time 15 "$@"
}

version=$(docker run --rm --platform "$PLATFORM" "$IMAGE" curl --version)
printf '%s\n' "$version"
printf '%s\n' "$version" | grep -F "curl ${EXPECTED_VERSION} "
for feature in HTTP2 HTTP3 brotli SSL libz PSL; do
    printf '%s\n' "$version" | grep -w "$feature" >/dev/null
done

# Wait for the server using a verified TLS connection.
attempt=0
until run_curl --http1.1 https://server:8443/plain.txt >/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 10 ] || exit 1
    sleep 1
done

for protocol in 1.1 2 3; do
    case "$protocol" in
        1.1) option=--http1.1 ;;
        2) option=--http2 ;;
        3) option=--http3-only ;;
    esac
    # Check the negotiated protocol; HTTP/2 must not silently fall back to HTTP/1.
    actual=$(run_curl "$option" -o /dev/null -w '%{http_version}' https://server:8443/plain.txt)
    [ "$actual" = "$protocol" ] || { echo "Expected HTTP/$protocol, got HTTP/$actual" >&2; exit 1; }
    body=$(run_curl "$option" --compressed https://server:8443/brotli)
    [ "$body" = 'curl integration test' ]
    echo "HTTP/$protocol and Brotli decoding passed"
done

# The shipped trust store must be populated for ordinary HTTPS requests.
docker run --rm --platform "$PLATFORM" "$IMAGE" test -s /etc/ssl/certs/ca-certificates.crt
echo "All smoke tests passed ($PLATFORM)"
