# curl with HTTP/3 and Brotli

A small Alpine image with curl, HTTP/1.1, HTTP/2, HTTP/3 (ngtcp2 + OpenSSL),
Brotli, zlib and public suffix list support. Runs as `nobody`.

## Versions

Updated against upstream stable releases on November 3, 2026:

| Component | Version |
| --- | --- |
| [Alpine Linux](https://www.alpinelinux.org/releases/) | 3.24.3 |
| [curl](https://curl.se/download.html) | 8.23.0 |
| [OpenSSL](https://openssl-library.org/source/) | 4.1.0 |
| [ngtcp2](https://github.com/ngtcp2/ngtcp2/releases) | 1.26.0 |
| [nghttp3](https://github.com/ngtcp2/nghttp3/releases) | 1.19.0 |
| [nghttp2](https://github.com/nghttp2/nghttp2/releases) | 1.71.0 |

Brotli (currently 1.2.1), zlib (currently 1.3.2), libpsl and their dependencies
come from the current Alpine 3.24 package repositories. `--pull` refreshes the
base image; a clean rebuild also refreshes APK packages.

OpenSSL's QUIC TLS API replaces the deprecated quictls backend. The image no
longer depends on quictls-specific library filenames. See the
[curl HTTP/3 build instructions](https://curl.se/docs/http3.html).

## Use or update an installed image

```sh
docker pull justdanz/curl-http3:latest
docker run --rm justdanz/curl-http3:latest curl --version
docker run --rm justdanz/curl-http3:latest curl --http3-only -I https://cloudflare-quic.com
```

`--http3-only` requires HTTP/3; `--http3` permits fallback to older HTTP versions.
HTTP/3 requires outbound UDP to the server's port (usually 443).
The existing `docker run IMAGE curl ...` interface is preserved; running the
image without a command prints the version.

To refresh an existing Compose service after a new image is published:

```sh
docker compose pull
docker compose up -d
```

Containers need to be recreated to use a newly pulled image. If another
Dockerfile uses this image in `FROM`, rebuild that downstream image with
`docker build --pull ...` and recreate its containers as well.

## Build and verify locally

```sh
git clone https://github.com/justdan6/docker-curl-http3.git
cd docker-curl-http3
# For an existing checkout, use: git pull --ff-only
make build
make test
```

`make build` pulls the base image and loads a native image as
`justdanz/curl-http3:local`. `make test` tests that exact local image against an
isolated local nginx server. It checks version/features, certificate validation,
negotiated HTTP/1.1, HTTP/2 and HTTP/3, and actual Brotli response decoding on all
three protocols. No public test endpoint is required. The test cleans up its
containers and network. The first test run downloads the server's APK packages.

To force a fresh build, including APK security updates:

```sh
docker buildx build --pull --no-cache --load -t justdanz/curl-http3:local .
make test
```

All source versions are Docker build arguments: `CURL_VERSION`, `OPENSSL_VERSION`,
`NGHTTP2_VERSION`, `NGHTTP3_VERSION`, `NGTCP2_VERSION`, and `ALPINE_VERSION`.
`BUILD_JOBS` defaults to 4; lower it on memory-constrained builders.

## Publish to Docker Hub

The supported platforms are `linux/amd64`, `linux/arm64`, `linux/arm/v7`,
`linux/arm/v6`, `linux/ppc64le`, and `linux/s390x`.
Docker Desktop includes emulation. On a standalone Linux builder, configure
QEMU/binfmt for the non-native platforms before building.

For a manual release, log in with a Docker Hub account/token that can write to
`justdanz/curl-http3`, then build and push the multi-platform image:

```sh
docker login -u justdanz
# Create this builder once; reuse it for later releases.
docker buildx create --name curl-http3-builder --driver docker-container --use
docker buildx inspect --bootstrap
make build
make test
make publish
```

`make publish` builds all supported platforms and publishes both `8.23.0` and
`latest`. To select an existing builder later, run
`docker buildx use curl-http3-builder`. Override `IMAGE` or `PLATFORMS` if needed.
`make build-all` creates `curl-http3.oci.tar` with every platform for inspection
without publishing; it does not load that archive into the local image store.

## GitHub Actions releases

Configure these repository Actions secrets:

- `DOCKERHUB_USERNAME`: `justdanz` (or an account with write access).
- `DOCKERHUB_TOKEN`: a Docker Hub access token with write permission to the image.

Pull requests build and run the local integration tests on every supported
platform, without registry credentials. Pushes to `main` do the same, then
publish a multi-platform `latest` and a `sha-...` tag after all platforms pass.
Version tags add the full version and major/minor tags, also updating `latest`:

```sh
# After merging the update and pulling main:
git switch main
git pull --ff-only
git tag v8.23.0
git push origin v8.23.0
```

You can also rerun the release from Actions using **Run workflow** on `main`.
Each platform is tested before its digest is uploaded; only a successful matrix
is assembled into the public tags. Dependabot checks Actions and Docker base
images weekly. To update source dependencies, change the pinned build arguments
and version table, then run the build/tests and open a pull request.
