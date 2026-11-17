# Multi-stage universal build for Aexus Colosseum (The Pit) — Web UI + pitd Core
FROM node:22-alpine AS web-builder
WORKDIR /src/web-ui
COPY web-ui/package*.json ./
RUN npm ci
COPY web-ui/ ./
RUN npm run build

FROM golang:1.26-alpine AS pitd-builder
WORKDIR /src/pitd
COPY arena-server/pitd/go.mod arena-server/pitd/go.sum ./
RUN go mod download
COPY arena-server/pitd/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/pitd ./cmd/pitd

FROM alpine:3.21
RUN apk add --no-cache ca-certificates docker-cli git python3 curl bash
WORKDIR /srv/arena
COPY --from=pitd-builder /out/pitd /usr/local/bin/pitd
COPY --from=web-builder /src/web-ui/dist /srv/arena/web-ui/dist

EXPOSE 18880
ENV PIT_ADDR=":18880" \
    PIT_WEB_DIR="/srv/arena/web-ui/dist" \
    PIT_WORK_DIR="/tmp/pit-runtime"

ENTRYPOINT ["/usr/local/bin/pitd"]
