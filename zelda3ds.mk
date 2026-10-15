# Zelda3 DS — Zelda3 port for ROCKNIX on the Anbernic RG DS Plus.
#
# Rename to "Makefile" to call `make` directly, or use `make -f zelda3ds.mk <target>`.
# Everything runs inside the docker/Dockerfile container (aarch64 cross toolchain).
#   make image     build the Docker image (once)
#   make fetch     clone the sources pinned in config/versions.env and apply patches/
#   make build     compile build/zelda3.aarch64
#   make assets    generate build/zelda3_assets.dat from rom/zelda3.sfc
#   make package   assemble dist/ports/ and dist/zelda3.zip
#   make deploy DEVICE_IP=x.x.x.x   copy to the device over SSH
#   make shell     interactive shell inside the container
#   make all       fetch + build + package
# With NATIVE=1 everything runs on the host without Docker (requires an aarch64 toolchain + arm64 SDL2).

IMAGE    ?= zelda3-ds-builder:bookworm
DOCKER   ?= docker
NATIVE   ?= 0
JOBS     ?=

ifeq ($(NATIVE),1)
  RUN :=
else
  RUN := $(DOCKER) run --rm -t -v "$(CURDIR)":/work -w /work -e JOBS=$(JOBS) \
         -e DEVICE_IP -e DEVICE_USER -e DEVICE_PASS -e PORTS_DIR $(IMAGE)
endif

.PHONY: all image fetch build assets package deploy shell clean distclean

all: fetch build package

image:
	$(DOCKER) build -t $(IMAGE) docker

fetch:
	$(RUN) bash scripts/fetch-sources.sh

build:
	$(RUN) bash scripts/build.sh

assets:
	$(RUN) bash scripts/extract-assets.sh $(ROM)

package:
	$(RUN) bash scripts/package.sh

deploy:
	$(RUN) bash scripts/deploy.sh

shell:
	$(DOCKER) run --rm -it -v "$(CURDIR)":/work -w /work $(IMAGE) bash

clean:
	rm -rf build dist
	-$(RUN) bash -c 'make -C external/zelda3-ds/app/jni/src clean_obj 2>/dev/null || true'

distclean: clean
	rm -rf external
