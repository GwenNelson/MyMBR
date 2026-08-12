BIN_DIR   := bin
IMAGE_DIR := images

IMAGE_NAME ?= mbr-test.img
IMAGE      ?= $(IMAGE_DIR)/$(IMAGE_NAME)
LAYOUT     ?= test/layouts/default.layout

MBR_BIN := $(BIN_DIR)/my-mbr.bin

PBR_TEST_BINS := \
	$(BIN_DIR)/test-pbr1.bin \
	$(BIN_DIR)/test-pbr2.bin \
	$(BIN_DIR)/test-pbr3.bin \
	$(BIN_DIR)/test-pbr4.bin

PBR_TESTS := test-pbr1 test-pbr2 test-pbr3 test-pbr4

PBR_INSTALLS := install-test-pbr1 install-test-pbr2 install-test-pbr3 install-test-pbr4

.PHONY: \
	all clean \
	mbr pbr-tests \
	test-deps test test-pbrs \
	install-test-pbrs install-my-mbr test-my-mbr \
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
# PBR installs
#

install-test-pbr%: $(IMAGE) $(BIN_DIR)/test-pbr%.bin
	./scripts/install-pbr.sh "$(IMAGE)" "$*" "$(BIN_DIR)/test-pbr$*.bin"

install-test-pbrs: $(PBR_INSTALLS)

#
# Test PBRs
#

$(BIN_DIR)/test-pbr%.bin: test-pbr.asm | $(BIN_DIR)
	nasm -f bin -d PBRID="$*" $< -o $@

pbr-tests: $(PBR_TEST_BINS)


#
# Test image
#

$(IMAGE): $(PBR_TEST_BINS) $(LAYOUT) | $(IMAGE_DIR) 
	./scripts/gen-img.sh "$@" "$(LAYOUT)"
	./scripts/verify-img.sh "$@"

test-deps: $(IMAGE) $(PBR_TEST_BINS)
	./scripts/verify-img.sh "$(IMAGE)"

install-my-mbr: $(IMAGE) $(MBR_BIN)
	./scripts/install-mbr.sh "$(IMAGE)" "$(MBR_BIN)"

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


test-my-mbr: install-test-pbrs install-my-mbr
	qemu-system-i386 \
		-drive file="$(IMAGE)",format=raw \
		-monitor none \
		-debugcon stdio 

#
# Cleanup
#

clean:
	rm -rf "$(BIN_DIR)" "$(IMAGE_DIR)"
