BIN_DIR   := bin
IMAGE_DIR := images

IMAGE_NAME ?= mbr-test.img
IMAGE      ?= $(IMAGE_DIR)/$(IMAGE_NAME)

MBR_BIN := $(BIN_DIR)/my-mbr.bin

PBR_TEST_BINS := \
	$(BIN_DIR)/test-pbr1.bin \
	$(BIN_DIR)/test-pbr2.bin \
	$(BIN_DIR)/test-pbr3.bin \
	$(BIN_DIR)/test-pbr4.bin

PBR_TESTS := test-pbr1 test-pbr2 test-pbr3 test-pbr4


.PHONY: \
	all clean \
	mbr pbr-tests \
	test-deps test test-pbrs \
	check-scripts \
	$(PBR_TESTS)


all: mbr pbr-tests


#
# Directories
#

$(BIN_DIR) $(IMAGE_DIR):
	mkdir -p $@


#
# MBR
#

$(MBR_BIN): my-mbr.asm | $(BIN_DIR)
	nasm -f bin $< -o $@

mbr: $(MBR_BIN)


#
# Test PBRs
#

$(BIN_DIR)/test-pbr%.bin: test-pbr.asm | $(BIN_DIR)
	nasm -f bin -d PBRID="$*" $< -o $@

pbr-tests: $(PBR_TEST_BINS)


#
# Test image
#

$(IMAGE): $(PBR_TEST_BINS) | $(IMAGE_DIR)
	./scripts/gen-img.sh "$@"
	./scripts/verify-img.sh "$@"

test-deps: $(IMAGE)
	./scripts/verify-img.sh "$(IMAGE)"


#
# Tests
#

test: test-pbrs

test-pbrs: $(PBR_TESTS)

$(PBR_TESTS): test-pbr%: test-deps $(BIN_DIR)/test-pbr%.bin
	@echo "=== Testing PBR $* ==="
	./scripts/install-pbr.sh "$(IMAGE)" $* "$(BIN_DIR)/test-pbr$*.bin"
	./scripts/activate-partition.sh "$(IMAGE)" $*
	./scripts/verify-active.sh "$(IMAGE)" $*
	./scripts/verify-img.sh "$(IMAGE)"
	./scripts/run-qemu-test.sh "$(IMAGE)" $*
	./scripts/verify-img.sh "$(IMAGE)"
	./scripts/verify-active.sh "$(IMAGE)" $*
	@echo "=== PBR $* PASSED ==="

check-scripts:
	bash -n scripts/*.sh scripts/filesystems/*.sh


#
# Cleanup
#

clean:
	rm -rf "$(BIN_DIR)" "$(IMAGE_DIR)"
