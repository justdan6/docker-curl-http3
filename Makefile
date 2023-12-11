test:
	docker run -t justdanz/curl-http3 curl --version | grep "curl 8.5.0"
	docker run --rm justdanz/curl-http3 curl -sIL https://httpbin.org/brotli | grep -i 'content-encoding: br'
	docker run --rm justdanz/curl-http3 curl -sIL https://blog.cloudflare.com --http3 -H 'user-agent: mozilla' | grep 'HTTP/3'

build:
	docker build -t justdanz/curl-http3 .

build-all:
	# docker buildx create --use
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x -t justdanz/curl-http3 .

publish:
	docker push justdanz/curl-http3