PBR_TEST_BINS := test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin
PBR_TESTS     := test-pbr1 test-pbr2 test-pbr3 test-pbr4

.PHONY: all clean mbr pbr-tests test-deps test test-pbrs $(PBR_TESTS)

all: mbr pbr-tests

mbr-test.img: my-mbr.bin $(PBR_TEST_BINS)
	./scripts/gen-img.sh
	./scripts/verify-img.sh

pbr-tests: $(PBR_TEST_BINS)

$(PBR_TEST_BINS): test-pbr%.bin: test-pbr.asm
	nasm -f bin -d PBRID="$*" $< -o $@

my-mbr.bin: my-mbr.asm
	nasm -f bin $< -o $@

mbr: my-mbr.bin

test-deps: mbr-test.img
	./scripts/verify-img.sh

test: test-pbrs

test-pbrs: $(PBR_TESTS)

$(PBR_TESTS): test-pbr%: test-deps test-pbr%.bin
	./scripts/activate-partition.sh mbr-test.img $*
	./scripts/verify-active.sh mbr-test.img $*
	./scripts/run-qemu-test.sh mbr-test.img $*

clean:
	rm -f *.bin
	rm -f mbr-test.img
