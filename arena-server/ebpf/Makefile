SHELL := /bin/bash
BINARY := pit-ebpf-sensor
DIST_DIR := dist
ARENA_HOST ?= arena
ARENA_BPF_IMAGE ?= arena-attackbox-attackbox:latest

.PHONY: all bpf build build-linux build-host test clean deploy

all: test build-linux build-host

## Compile bpf/probes.bpf.c -> bpf/probes_bpfel.o via Docker clang (local or remote ssh arena)
bpf:
	./build.sh --compile-bpf

## Build static Linux x86_64 sensor binary (embeds bpf/probes_bpfel.o)
build-linux:
	@mkdir -p $(DIST_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o $(DIST_DIR)/$(BINARY)-linux-amd64 ./cmd/pit-ebpf-sensor

## Build native host binary (macOS/Linux; supports --replay-demo on non-Linux)
build-host:
	@mkdir -p $(DIST_DIR)
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o $(DIST_DIR)/$(BINARY) ./cmd/pit-ebpf-sensor

build: build-linux build-host

## Run unit tests across host OS and Linux cross-target vet
test:
	go test -v -count=1 ./...
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go vet ./...
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go test -c ./internal/sensor -o /dev/null

deploy: build-linux
	ssh $(ARENA_HOST) 'sudo mkdir -p /srv/arena/ebpf && sudo chown -R $$(id -u):$$(id -g) /srv/arena/ebpf'
	scp $(DIST_DIR)/$(BINARY)-linux-amd64 $(ARENA_HOST):/srv/arena/ebpf/$(BINARY)
	ssh $(ARENA_HOST) 'chmod +x /srv/arena/ebpf/$(BINARY)'

clean:
	rm -rf $(DIST_DIR)
