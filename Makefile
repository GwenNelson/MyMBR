all:	mbr pbr-tests

mbr-test.img: my-mbr.bin test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin
	./gen-img.sh
	./verify-img.sh

pbr-tests: test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin

test-pbr%.bin: test-pbr.asm
	nasm -f bin -d PBRID="$*" $< -o $@

my-mbr.bin: my-mbr.asm
	nasm -f bin $< -o $@

mbr: my-mbr.bin

test: mbr-test.img
	./verify-img.sh
	qemu-system-i386 -hda mbr-test.img -boot c

clean:
	rm -f *.bin
	rm -f mbr-test.img
