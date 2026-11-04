IMAGE ?= justdanz/curl-http3
TAG ?= local
PLATFORMS ?= linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x
CURL_VERSION := $(shell sed -n 's/^ARG CURL_VERSION=//p' Dockerfile)

.PHONY: build test build-all publish

build:
	docker buildx build --pull --load -t $(IMAGE):$(TAG) .

test:
	IMAGE=$(IMAGE):$(TAG) sh tests/smoke.sh

# An OCI archive preserves every platform without publishing anything.
build-all:
	docker buildx build --pull --platform $(PLATFORMS) -t $(IMAGE):$(TAG) --output type=oci,dest=curl-http3.oci.tar .

# Publish both a curl-version tag and latest as a multi-platform manifest.
publish:
	docker buildx build --pull --platform $(PLATFORMS) -t $(IMAGE):$(CURL_VERSION) -t $(IMAGE):latest --push .
