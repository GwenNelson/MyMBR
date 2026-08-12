#!/usr/bin/env bash

set -euo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$TEST_DIR/.." && pwd)

test_fail()
{
    echo "FAILED: $*" >&2
    exit 1
}

test_banner()
{
    echo
    echo "========================================"
    echo " $*"
    echo "========================================"
}

test_verify_image()
{
    local image=$1

    "$TEST_DIR/verify-img.sh" "$image" ||
        test_fail "Image verification failed: $image"
}

test_install_pbrs()
{
    local image=$1
    local part

    for part in 1 2 3 4; do
        "$TEST_DIR/install-pbr.sh" \
            "$image" \
            "$part" \
            "$PROJECT_DIR/bin/test-pbr${part}.bin" ||
            test_fail "Failed to install test PBR $part"
    done
}

test_install_mbr()
{
    local image=$1
    local mbr=$2

    "$TEST_DIR/install-mbr.sh" "$image" "$mbr" ||
        test_fail "Failed to install MBR: $mbr"
}
