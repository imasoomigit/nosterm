#!/usr/bin/env bash
#
# push-to-registry.sh -- push a file to a Docker/OCI registry as an artifact
# image, using only curl, tar and sha256.
#
# Why not `docker push`?  The CI runners for this project are plain shell VMs
# with no container daemon (and the macOS one could never have one for this
# anyway).  The registry API needs three things and three things only: two
# blob uploads and one manifest PUT.
#
# The resulting image is a single uncompressed layer holding the file, so
#   docker pull registry.example.com/ns/repo:tag
# gives you the artifact straight into the container filesystem.
#
# Usage:
#   REGISTRY_USER=... REGISTRY_PASSWORD=... \
#     push-to-registry.sh <file> <image> <tag> [os] [arch]
#
#   <image> is the full repository path below the registry host, e.g.
#   funapplications/nostalgicterminal/linux
#
# Environment:
#   REGISTRY_HOST     registry host            (default: registry.desphilic.net)
#   REGISTRY_USER     registry username        (required; CI uses gitlab-ci-token)
#   REGISTRY_PASSWORD registry password/token  (required; CI uses $CI_JOB_TOKEN)
#   IMAGE_TITLE       label: image title       (default: basename of <file>)
#   IMAGE_SOURCE      label: source repository (optional)
#   IMAGE_REVISION    label: git revision      (optional)
#   EXTRA_TAGS        space-separated tags to add on top of <tag>, e.g.
#                     "latest".  Free: the blobs are already uploaded, so this
#                     is one extra manifest PUT.

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: $0 <file> <image> <tag> [os] [arch]" >&2
    exit 2
fi

FILE="$1"
IMAGE="$2"
TAG="$3"
OS_NAME="${4:-linux}"
ARCH="${5:-amd64}"

REGISTRY="${REGISTRY_HOST:-registry.desphilic.net}"
REGISTRY_USER="${REGISTRY_USER:?set REGISTRY_USER}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:?set REGISTRY_PASSWORD}"

# <image> is documented as the repository path *below* the registry host, but
# CI naturally hands over $CI_REGISTRY_IMAGE, which already starts with the
# host.  Taking it at face value would build ".../host/host/group/repo", and
# the registry then rejects the blob upload without returning a Location
# header ("registry did not return an upload location").  Normalise here so
# both call styles work.
case "$IMAGE" in
"$REGISTRY"/*)
    IMAGE="${IMAGE#"$REGISTRY"/}"
    ;;
*/*)
    _first="${IMAGE%%/*}"
    # a first component containing a "." or ":" is a host, not a group
    case "$_first" in
    *.* | *:*) IMAGE="${IMAGE#*/}" ;;
    esac
    ;;
esac
echo "repository: $IMAGE"

[ -f "$FILE" ] || { echo "FATAL: no such file: $FILE" >&2; exit 1; }

# --- small portability helpers -------------------------------------------
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

size_of() {
    if stat -c%s "$1" >/dev/null 2>&1; then stat -c%s "$1"; else stat -f%z "$1"; fi
}

json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# --- discover the auth realm from the registry's own challenge ------------
CHALLENGE="$(curl -sSI "https://$REGISTRY/v2/" | tr -d '\r')"
REALM="$(printf '%s' "$CHALLENGE" | sed -n 's/.*realm="\([^"]*\)".*/\1/p')"
SERVICE="$(printf '%s' "$CHALLENGE" | sed -n 's/.*service="\([^"]*\)".*/\1/p')"
if [ -z "$REALM" ]; then
    REALM="https://$REGISTRY/v2/token"
fi
SERVICE="${SERVICE:-container_registry}"

echo "registry : https://$REGISTRY"
echo "realm    : $REALM"
echo "service  : $SERVICE"
echo "image    : $REGISTRY/$IMAGE:$TAG"

TOKEN="$(curl -sG \
    --user "$REGISTRY_USER:$REGISTRY_PASSWORD" \
    --data-urlencode "service=$SERVICE" \
    --data-urlencode "scope=repository:$IMAGE:pull,push" \
    "$REALM" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$TOKEN" ] || { echo "FATAL: could not obtain a registry token" >&2; exit 1; }
echo "token    : acquired (${#TOKEN} chars)"

auth=(-H "Authorization: Bearer $TOKEN")

# --- build the layer: one uncompressed tar holding the file ----------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BASENAME="$(basename "$FILE")"
cp "$FILE" "$WORK/$BASENAME"
# Uncompressed on purpose: for a tar layer, the diff_id IS the layer digest,
# so we never have to hash the bytes twice or track gzip offsets.
tar -C "$WORK" -cf "$WORK/layer.tar" "$BASENAME"
rm -f "$WORK/$BASENAME"

LAYER_DIGEST="sha256:$(sha256_of "$WORK/layer.tar")"
LAYER_SIZE="$(size_of "$WORK/layer.tar")"
echo "layer    : $LAYER_DIGEST ($(( LAYER_SIZE / 1024 / 1024 )) MiB uncompressed)"

CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TITLE="$(json_escape "${IMAGE_TITLE:-$BASENAME}")"
SOURCE="$(json_escape "${IMAGE_SOURCE:-}")"
REVISION="$(json_escape "${IMAGE_REVISION:-}")"

# --- image config ----------------------------------------------------------
printf '{"created":"%s","architecture":"%s","os":"%s","rootfs":{"type":"layers","diff_ids":["%s"]},"config":{"Labels":{"org.opencontainers.image.title":"%s","org.opencontainers.image.source":"%s","org.opencontainers.image.revision":"%s","org.opencontainers.image.created":"%s"}}}' \
    "$CREATED" "$ARCH" "$OS_NAME" "$LAYER_DIGEST" \
    "$TITLE" "$SOURCE" "$REVISION" "$CREATED" > "$WORK/config.json"

CONFIG_DIGEST="sha256:$(sha256_of "$WORK/config.json")"
CONFIG_SIZE="$(size_of "$WORK/config.json")"

# --- upload one blob (start an upload, then PUT the bytes with a digest) ----
upload_blob() {
    local file="$1" digest="$2" headers location

    headers="$WORK/headers"
    curl -sS -D "$headers" -o /dev/null -X POST "${auth[@]}" \
        "https://$REGISTRY/v2/$IMAGE/blobs/uploads/"

    location="$(tr -d '\r' < "$headers" | sed -n 's/^[Ll]ocation: *//p' | head -n1)"
    [ -n "$location" ] || { echo "FATAL: registry did not return an upload location" >&2; exit 1; }
    case "$location" in
        http://*|https://*) ;;
        *) location="https://$REGISTRY$location" ;;
    esac

    # The location usually already carries a query string.
    case "$location" in
        *\?*) location="$location&digest=$digest" ;;
        *)    location="$location?digest=$digest" ;;
    esac

    curl -sS -f -o /dev/null -X PUT "${auth[@]}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$file" \
        "$location" || { echo "FATAL: blob upload failed for $digest" >&2; exit 1; }
    echo "  uploaded blob $digest"
}

echo "blobs    :"
upload_blob "$WORK/layer.tar" "$LAYER_DIGEST"
upload_blob "$WORK/config.json" "$CONFIG_DIGEST"

# --- the manifest ties them together ---------------------------------------
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"%s","size":%s},"layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar","digest":"%s","size":%s}]}' \
    "$CONFIG_DIGEST" "$CONFIG_SIZE" "$LAYER_DIGEST" "$LAYER_SIZE" > "$WORK/manifest.json"

curl -sS -f -o /dev/null -X PUT "${auth[@]}" \
    -H "Content-Type: application/vnd.oci.image.manifest.v1+json" \
    --data-binary "@$WORK/manifest.json" \
    "https://$REGISTRY/v2/$IMAGE/manifests/$TAG" \
    || { echo "FATAL: manifest PUT failed" >&2; exit 1; }
echo "  tagged $TAG"

# Extra tags point at the same blobs, so they cost one PUT each and no bytes.
if [ -n "${EXTRA_TAGS:-}" ]; then
    for extra in $EXTRA_TAGS; do
        if [ "$extra" = "$TAG" ]; then
            continue
        fi
        curl -sS -f -o /dev/null -X PUT "${auth[@]}" \
            -H "Content-Type: application/vnd.oci.image.manifest.v1+json" \
            --data-binary "@$WORK/manifest.json" \
            "https://$REGISTRY/v2/$IMAGE/manifests/$extra" \
            || { echo "FATAL: manifest PUT failed for tag '$extra'" >&2; exit 1; }
        echo "  tagged $extra"
    done
fi

# --- verify it is really there ---------------------------------------------
HTTP="$(curl -sS -o /dev/null -w '%{http_code}' "${auth[@]}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://$REGISTRY/v2/$IMAGE/manifests/$TAG")"
[ "$HTTP" = "200" ] || { echo "FATAL: manifest not readable after push (HTTP $HTTP)" >&2; exit 1; }

echo "PUSHED   : https://$REGISTRY/v2/$IMAGE/manifests/$TAG (HTTP 200)"
