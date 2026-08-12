#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?Usage: test-reference.sh IMAGE REFERENCE_MBR}
REFERENCE_MBR=${2:?Usage: test-reference.sh IMAGE REFERENCE_MBR}

test_banner "REFERENCE MBR TEST"

#
# Establish known-good test state.
#

test_verify_image "$IMAGE"

test_install_pbrs "$IMAGE"
test_verify_image "$IMAGE"

test_install_mbr "$IMAGE" "$REFERENCE_MBR"
test_verify_image "$IMAGE"


for part in 1 2 3 4; do
    test_banner "REFERENCE MBR: PARTITION $part"

    #
    # Explicitly establish the active partition for this test.
    #

    "$SCRIPT_DIR/activate-partition.sh" "$IMAGE" "$part" ||
        test_fail "Could not activate partition $part"

    "$SCRIPT_DIR/verify-active.sh" "$IMAGE" "$part" ||
        test_fail "Partition $part is not active"

    #
    # Nothing should have damaged the filesystems/PBR metadata.
    #

    test_verify_image "$IMAGE"

    #
    # Boot through the reference MBR.
    #
    # run-qemu-test.sh already expects PBR_TEST_OK:<part>.
    #

    "$SCRIPT_DIR/run-qemu-test.sh" "$IMAGE" "$part"  -snapshot ||
        test_fail "Reference MBR failed to boot partition $part"

    #
    # QEMU should not have persisted anything unexpected.
    #

    "$SCRIPT_DIR/verify-active.sh" "$IMAGE" "$part" ||
        test_fail "Active partition changed after boot"

    test_verify_image "$IMAGE"

    echo "Partition $part [OK]"
done


test_banner "REFERENCE MBR TEST PASSED"
