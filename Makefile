IMAGE ?= local/sandbox-opencode-local
TAG ?= latest
PLATFORM ?= linux/arm64

.PHONY: build run shell inspect

build:
	./scripts/build-arm64.sh

run:
	docker run -it --rm \
	  -v $(PWD):/home/agent/workspace \
	  -w /home/agent/workspace \
	  $(IMAGE):$(TAG)

shell:
	docker run -it --rm \
	  -v $(PWD):/home/agent/workspace \
	  -w /home/agent/workspace \
	  $(IMAGE):$(TAG) bash

inspect:
	docker image inspect $(IMAGE):$(TAG)
