#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"


IMAGE=${1:?Usage: test-my-mbr.sh IMAGE MBR}
MBR=${2:?Usage: test-my-mbr.sh IMAGE MBR}


test_banner "MY MBR TEST"


#
# Establish known-good initial state.
#

test_verify_image "$IMAGE"

test_install_pbrs "$IMAGE"
test_verify_image "$IMAGE"

test_install_mbr "$IMAGE" "$MBR"
test_verify_image "$IMAGE"


#
# Exercise every selector choice.
#
# Each iteration deliberately starts with the active partition left by
# the previous iteration. This proves that my-mbr not only activates the
# selected partition, but also clears the previous active flag.
#

for part in 1 2 3 4; do
    test_banner "MY MBR: SELECT PARTITION $part"

    #
    # Boot my-mbr and send the partition number through COM1.
    #
    # The PBR reports success through the QEMU debug port.
    #

    "$SCRIPT_DIR/run-my-mbr-test.sh" \
        "$IMAGE" \
        "$part" ||
        test_fail "my-mbr failed to boot partition $part"

    #
    # my-mbr is specifically supposed to persist the selected
    # partition as the sole active partition.
    #

    "$SCRIPT_DIR/verify-active.sh" "$IMAGE" "$part" ||
        test_fail "my-mbr did not make partition $part active"

    #
    # Check that changing and booting the active partition hasn't
    # damaged any filesystem metadata.
    #

    test_verify_image "$IMAGE"

    echo "Partition $part [OK]"
done


test_banner "MY MBR TEST PASSED"
