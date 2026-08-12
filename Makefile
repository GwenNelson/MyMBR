all:	mbr pbr-tests

mbr-test.img: my-mbr.bin test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin
	./scripts/gen-img.sh
	./scripts/verify-img.sh

pbr-tests: test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin

test-pbr%.bin: test-pbr.asm
	nasm -f bin -d PBRID="$*" $< -o $@

my-mbr.bin: my-mbr.asm
	nasm -f bin $< -o $@

mbr: my-mbr.bin

test-deps: mbr-test.img
	./scripts/verify-img.sh

clean:
	rm -f *.bin
	rm -f mbr-test.img
