BITS 16
ORG 0x7C00

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
	db "Booted PBR", PBRID, "!", 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55
