#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?Usage: test-my-mbr.sh IMAGE MBR}
MBR=${2:?Usage: test-my-mbr.sh IMAGE MBR}

test_banner "MY MBR TEST"

test_verify_image "$IMAGE"

test_install_pbrs "$IMAGE"
test_verify_image "$IMAGE"

test_install_mbr "$IMAGE" "$MBR"
test_verify_image "$IMAGE"


for part in 1 2 3 4; do
    test_banner "MY MBR: SELECT PARTITION $part"

    #
    # Eventually:
    #
    #   run MBR
    #   send "$part" through COM1
    #   expect PBR_TEST_OK:$part
    #

    "$SCRIPT_DIR/run-my-mbr-test.sh" \
        "$IMAGE" \
        "$part" ||
        test_fail "my-mbr failed to boot partition $part"

    #
    # Unlike the reference test, MY MBR is supposed to have made this
    # partition active.
    #

    "$SCRIPT_DIR/verify-active.sh" "$IMAGE" "$part" ||
        test_fail "my-mbr did not make partition $part active"

    test_verify_image "$IMAGE"
done


test_banner "MY MBR TEST PASSED"
