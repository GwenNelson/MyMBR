BITS 16
ORG 0x7C00

%ifndef PBRID
    %error "PBRID must be defined"
%endif

%if PBRID < 1 || PBRID > 4
    %error "PBRID must be between 1 and 4"
%endif


; Standard PBR entry point.
; Bytes 0x03-0x59 are reserved for filesystem metadata/BPB and
; will be preserved by the installer.
	jmp short start
	nop

	times 0x5A-($-$$) db 0

start:
	; setup stack and data segment
	cli

	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00

	sti

	mov si,message      ; we want to do the debug print first, for testing sake
	call debug_print

	mov si,message      ; but still show to the user too
	call scr_print

	jmp hang


scr_print:
	lodsb
	test al,al
	jz .done

	mov ah,0x0E
	mov bx,0x0007
	int 0x10
	jmp scr_print
.done:
	ret


debug_print:
	mov dx, 0xE9

.loop:
	lodsb
	test al, al
	jz .done
	out dx, al
	jmp .loop

.done:
	ret

hang:
	cli
	hlt
	jmp hang

message:
	db "PBR_TEST_OK:",'0' + PBRID, 13, 10, 0

	times 510-($-$$) db 0
	dw 0xAA55
