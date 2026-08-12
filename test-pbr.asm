BITS 16
ORG 0x7C00

; Standard PBR entry point.
; Bytes 0x03-0x59 are reserved for filesystem metadata/BPB and
; will be preserved by the installer.
	jmp short start
	nop

	times 0x5A-($-$$) db 0

start:
	xor ax,ax
	mov ds,ax

	mov si,message

print:
	lodsb
	test al,al
	jz hang

	mov ah,0x0E
	mov bx,0x0007
	int 0x10
	jmp print

hang:
	cli
	hlt
	jmp hang

message:
	db "Booted PBR",'0' + PBRID, "!", 13, 10, 0

	times 510-($-$$) db 0
	dw 0xAA55
