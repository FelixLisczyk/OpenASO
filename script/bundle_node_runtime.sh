#!/bin/sh
set -eu

NODE_VERSION="${NODE_RUNTIME_VERSION:-v24.15.0}"
NODE_PLATFORMS="darwin-arm64 darwin-x64"

CACHE_DIR="${PROJECT_DIR}/Build/NodeRuntimeCache/${NODE_VERSION}"
RESOURCE_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/NodeRuntime"
NODE_ENTITLEMENTS="${PROJECT_DIR}/script/node_runtime.entitlements"

expected_sha256() {
    platform="$1"

    case "${NODE_VERSION}:${platform}" in
        v24.15.0:darwin-arm64)
            echo "372331b969779ab5d15b949884fc6eaf88d5afe87bde8ba881d6400b9100ffc4"
            ;;
        v24.15.0:darwin-x64)
            echo "ffd5ee293467927f3ee731a553eb88fd1f48cf74eebc2d74a6babe4af228673b"
            ;;
        *)
            echo "No pinned SHA256 for Node ${NODE_VERSION} ${platform}" >&2
            exit 1
            ;;
    esac
}

verify_archive() {
    archive="$1"
    platform="$2"
    expected="$(expected_sha256 "${platform}")"
    actual="$(shasum -a 256 "${archive}" | awk '{print $1}')"

    if [ "${actual}" != "${expected}" ]; then
        echo "Checksum mismatch for ${archive}" >&2
        echo "expected ${expected}" >&2
        echo "actual   ${actual}" >&2
        exit 1
    fi
}

mkdir -p "${CACHE_DIR}"
rm -rf "${RESOURCE_DIR}"
mkdir -p "${RESOURCE_DIR}"

copy_runtime() {
    platform="$1"
    archive="${CACHE_DIR}/node-${NODE_VERSION}-${platform}.tar.gz"
    extracted="${CACHE_DIR}/node-${NODE_VERSION}-${platform}"
    url="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${platform}.tar.gz"

    if [ -x "${extracted}/bin/node" ] && [ -f "${archive}" ]; then
        verify_archive "${archive}" "${platform}"
    elif [ -x "${extracted}/bin/node" ]; then
        rm -rf "${extracted}"
    fi

    if [ ! -x "${extracted}/bin/node" ]; then
        if [ ! -f "${archive}" ]; then
            echo "Downloading Node ${NODE_VERSION} for ${platform}"
            curl -fL "${url}" -o "${archive}"
        fi

        verify_archive "${archive}" "${platform}"
        rm -rf "${extracted}"
        tar -xzf "${archive}" -C "${CACHE_DIR}"
    fi

    destination="${RESOURCE_DIR}/${platform}"
    mkdir -p "${destination}"
    rsync -a --delete \
        --exclude include \
        --exclude share \
        --exclude CHANGELOG.md \
        --exclude README.md \
        --exclude LICENSE \
        "${extracted}/" "${destination}/"

    chmod +x "${destination}/bin/node"

    if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
        codesign --force \
            --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            --options runtime \
            --entitlements "${NODE_ENTITLEMENTS}" \
            --timestamp=none \
            "${destination}/bin/node"
    fi
}

for platform in ${NODE_PLATFORMS}; do
    copy_runtime "${platform}"
done

echo "Bundled Node ${NODE_VERSION} into ${RESOURCE_DIR}"
