all:	pbr-tests mbr

%.bin: %.asm
	nasm -f bin $< -o $@

mbr-test.img:
	./gen-img.sh


pbr-tests: test-pbr1.bin test-pbr2.bin test-pbr3.bin test-pbr4.bin

mbr: my-mbr.bin

