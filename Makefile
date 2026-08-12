.DEFAULT_GOAL := all


#
# Directories
#

BIN_DIR    := bin
IMAGE_DIR  := images
STAMP_DIR  := .stamps
LAYOUT_DIR := test/layouts


#
# Layouts
#

LAYOUT ?= $(LAYOUT_DIR)/default.layout

LAYOUTS := $(wildcard $(LAYOUT_DIR)/*.layout)

LAYOUT_IMAGES := $(patsubst \
	$(LAYOUT_DIR)/%, \
	$(IMAGE_DIR)/%.img, \
	$(LAYOUTS))


#
# Image selection
#
# Precedence:
#
#   IMAGE=...
#       use exactly that path
#
#   IMAGE_NAME=...
#       use images/IMAGE_NAME
#
#   otherwise
#       derive the image name from LAYOUT
#

ifndef IMAGE
ifndef IMAGE_NAME
IMAGE_NAME := $(notdir $(LAYOUT)).img
endif

IMAGE := $(IMAGE_DIR)/$(IMAGE_NAME)
endif


#
# Binaries
#

REFERENCE_MBR := test/syslinux-mbr.bin

MBR_BIN      := $(BIN_DIR)/my-mbr.bin
MBR_TEST_BIN := $(BIN_DIR)/my-mbr-test.bin

PBR_TEST_BINS := \
	$(BIN_DIR)/test-pbr1.bin \
	$(BIN_DIR)/test-pbr2.bin \
	$(BIN_DIR)/test-pbr3.bin \
	$(BIN_DIR)/test-pbr4.bin


#
# Persistent interactive-run installation stamps
#

IMAGE_STAMP_PREFIX := $(STAMP_DIR)/$(notdir $(IMAGE))

MBR_INSTALL_STAMP := \
	$(IMAGE_STAMP_PREFIX).my-mbr

REFERENCE_MBR_INSTALL_STAMP := \
	$(IMAGE_STAMP_PREFIX).reference-mbr

PBR_INSTALL_STAMPS := \
	$(IMAGE_STAMP_PREFIX).test-pbr1 \
	$(IMAGE_STAMP_PREFIX).test-pbr2 \
	$(IMAGE_STAMP_PREFIX).test-pbr3 \
	$(IMAGE_STAMP_PREFIX).test-pbr4


#
# Phony targets
#

.PHONY: \
	all \
	all-layouts \
	clean \
	mbr \
	pbr-tests \
	check-scripts \
	install-test-pbrs \
	install-my-mbr \
	install-reference-mbr \
	run-my-mbr \
	run-reference \
	test \
	test-reference \
	test-my-mbr \
	test-all-layouts \
	test-reference-all-layouts \
	test-my-mbr-all-layouts


#
# Normal build
#

all: mbr pbr-tests


#
# Directories
#

$(BIN_DIR) $(IMAGE_DIR) $(STAMP_DIR):
	mkdir -p "$@"


#
# MBR
#

$(MBR_BIN): my-mbr.asm | $(BIN_DIR)
	nasm -f bin "$<" -o "$@"


#
# Automated-test build of our MBR
#
# TEST_SERIAL_INPUT will make the selector read its choice from
# the serial port rather than INT 16h.
#

$(MBR_TEST_BIN): my-mbr.asm | $(BIN_DIR)
	nasm -f bin -DTEST_SERIAL_INPUT "$<" -o "$@"


mbr: $(MBR_BIN) $(MBR_TEST_BIN)


#
# Test PBRs
#

$(BIN_DIR)/test-pbr%.bin: test-pbr.asm | $(BIN_DIR)
	nasm -f bin -d PBRID="$*" "$<" -o "$@"


pbr-tests: $(PBR_TEST_BINS)


#
# Selected image
#

$(IMAGE): $(LAYOUT) $(PBR_TEST_BINS) | $(IMAGE_DIR)
	./scripts/gen-img.sh "$@" "$(LAYOUT)"
	./scripts/verify-img.sh "$@"
	rm -f "$(IMAGE_STAMP_PREFIX)".*


#
# Every layout image
#

$(IMAGE_DIR)/%.layout.img: $(LAYOUT_DIR)/%.layout $(PBR_TEST_BINS) | $(IMAGE_DIR)
	./scripts/gen-img.sh "$@" "$<"
	./scripts/verify-img.sh "$@"
	rm -f "$(STAMP_DIR)/$(notdir $@)".*


all-layouts: $(LAYOUT_IMAGES)


#
# Persistent PBR installation
#
# These targets are for interactive runs.
#

$(IMAGE_STAMP_PREFIX).test-pbr%: $(BIN_DIR)/test-pbr%.bin | $(IMAGE) $(STAMP_DIR)
	./scripts/install-pbr.sh \
		"$(IMAGE)" \
		"$*" \
		"$(BIN_DIR)/test-pbr$*.bin"

	touch "$@"


install-test-pbrs: $(PBR_INSTALL_STAMPS)


#
# Persistent installation of our normal MBR
#

$(MBR_INSTALL_STAMP): $(MBR_BIN) | $(IMAGE) $(STAMP_DIR)
	./scripts/install-mbr.sh "$(IMAGE)" "$(MBR_BIN)"
	touch "$@"


install-my-mbr: $(MBR_INSTALL_STAMP)


#
# Persistent installation of reference MBR
#

$(REFERENCE_MBR_INSTALL_STAMP): $(REFERENCE_MBR) | $(IMAGE) $(STAMP_DIR)
	./scripts/install-mbr.sh "$(IMAGE)" "$(REFERENCE_MBR)"
	touch "$@"


install-reference-mbr: $(REFERENCE_MBR_INSTALL_STAMP)


#
# Interactive runs
#
# These use the persistent image and normal keyboard-input MBR.
#

run-my-mbr: install-test-pbrs install-my-mbr
	qemu-system-i386 \
		-drive file="$(IMAGE)",format=raw \
		-monitor none \
		-debugcon stdio


run-reference: install-test-pbrs install-reference-mbr
	qemu-system-i386 \
		-drive file="$(IMAGE)",format=raw \
		-monitor none \
		-debugcon stdio


#
# Automated tests
#
# The scripts own the test lifecycle:
#
#   reset/setup
#   verify
#   boot with QEMU -snapshot
#   verify again
#
# test-reference:
#
#   test each PBR using the known-good reference MBR.
#
# test-my-mbr:
#
#   test each selector choice using the serial-input build of our MBR.
#

test-reference: $(IMAGE) $(PBR_TEST_BINS) $(REFERENCE_MBR)
	./scripts/test-reference.sh \
		"$(IMAGE)" \
		"$(REFERENCE_MBR)"


test-my-mbr: $(IMAGE) $(PBR_TEST_BINS) $(MBR_TEST_BIN)
	./scripts/test-my-mbr.sh \
		"$(IMAGE)" \
		"$(MBR_TEST_BIN)"


#
# Complete automated suite for selected layout
#

test: test-reference test-my-mbr


#
# Complete automated suite for every layout
#

test-all-layouts:
	@set -e; \
	for layout in $(LAYOUTS); do \
		echo; \
		echo "========================================"; \
		echo " Testing $$layout"; \
		echo "========================================"; \
		$(MAKE) --no-print-directory \
			test \
			LAYOUT="$$layout"; \
	done
	@echo
	@echo "========================================"
	@echo " ALL LAYOUT TESTS PASSED"
	@echo "========================================"


#
# Reference-MBR tests for every layout
#

test-reference-all-layouts:
	@set -e; \
	for layout in $(LAYOUTS); do \
		echo; \
		echo "========================================"; \
		echo " Reference test: $$layout"; \
		echo "========================================"; \
		$(MAKE) --no-print-directory \
			test-reference \
			LAYOUT="$$layout"; \
	done


#
# Our-MBR tests for every layout
#

test-my-mbr-all-layouts:
	@set -e; \
	for layout in $(LAYOUTS); do \
		echo; \
		echo "========================================"; \
		echo " my-mbr test: $$layout"; \
		echo "========================================"; \
		$(MAKE) --no-print-directory \
			test-my-mbr \
			LAYOUT="$$layout"; \
	done


#
# Script syntax checks
#

check-scripts:
	bash -n scripts/*.sh scripts/filesystems/*.sh


#
# Cleanup
#

clean:
	rm -rf "$(BIN_DIR)" "$(IMAGE_DIR)" "$(STAMP_DIR)"
