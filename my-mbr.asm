bits 16
org 0x0600

RELOC_BASE      equ 0x0600
LOAD_BASE       equ 0x7c00
PARTITION_TABLE equ RELOC_BASE + 446


;
; ======================================================================
; Initial entry
; ======================================================================
;
; BIOS actually enters this code at 0000:7C00.
; We assemble for 0000:0600 because that's where we relocate ourselves
; before doing any real work.
;

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, LOAD_BASE

    cld

    ;
    ; Copy the complete 512-byte MBR to 0000:0600.
    ;

    mov si, LOAD_BASE
    mov di, RELOC_BASE
    mov cx, 256
    rep movsw

    ;
    ; Absolute far jump into relocated copy.
    ;

    jmp 0x0000:relocated


;
; ======================================================================
; Relocated execution
; ======================================================================
;

relocated:
    sti

    ;
    ; DL still contains the BIOS boot drive.
    ;

    mov [boot_drive], dl


;
; ----------------------------------------------------------------------
; Choose partition
; ----------------------------------------------------------------------
;

.wait_key:
    call read_choice

    cmp al, '1'
    jb .wait_key

    cmp al, '4'
    ja .wait_key

    sub al, '1'
    mov [selected_partition], al


;
; ----------------------------------------------------------------------
; Update active partition
; ----------------------------------------------------------------------
;

    mov byte [PARTITION_TABLE + 0*16], 0
    mov byte [PARTITION_TABLE + 1*16], 0
    mov byte [PARTITION_TABLE + 2*16], 0
    mov byte [PARTITION_TABLE + 3*16], 0

    xor ah, ah
    mov bx, ax
    shl bx, 4
    add bx, PARTITION_TABLE

    mov byte [bx], 0x80


;
; ----------------------------------------------------------------------
; Write modified MBR back to disk
; ----------------------------------------------------------------------
;

    xor ax, ax
    mov es, ax

    mov bx, RELOC_BASE

    mov ah, 0x03
    mov al, 1

    xor ch, ch
    mov cl, 1
    xor dh, dh

    mov dl, [boot_drive]

    int 0x13
    jc disk_error


;
; ----------------------------------------------------------------------
; Locate selected partition
; ----------------------------------------------------------------------
;

    mov al, [selected_partition]
    xor ah, ah

    mov bx, ax
    shl bx, 4
    add bx, PARTITION_TABLE


;
; ----------------------------------------------------------------------
; Load PBR using EDD/LBA when available, with legacy CHS fallback
; ----------------------------------------------------------------------
;

    ;
    ; Prefer INT 13h extensions.  The partition table's LBA start field
    ; is authoritative on modern partition tables; CHS is only fallback.
    ; Preserve BX because AH=41h requires BX=55AAh.
    ;

    push bx

    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, [boot_drive]
    int 0x13
    jc .no_edd

    cmp bx, 0xaa55
    jne .no_edd

    test cx, 1
    jz .no_edd

    ;
    ; EDD is available. Restore the partition pointer and read its
    ; authoritative starting LBA.
    ;

    pop bx

    mov eax, [bx + 8]
    mov [dap + 8], eax

    push bx
    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    pop bx
    jnc .pbr_loaded

    ;
    ; Extended read failed. BX still points at the selected partition,
    ; so fall back to its legacy CHS fields.
    ;

    jmp .try_chs

.no_edd:
    pop bx

.try_chs:
    mov dh, [bx + 1]
    mov cl, [bx + 2]
    mov ch, [bx + 3]

    xor ax, ax
    mov es, ax

    mov bx, LOAD_BASE

    mov ah, 0x02
    mov al, 1

    mov dl, [boot_drive]

    int 0x13
    jc disk_error

.pbr_loaded:


;
; ----------------------------------------------------------------------
; Validate and boot PBR
; ----------------------------------------------------------------------
;

    cmp word [LOAD_BASE + 510], 0xaa55
    jne invalid_pbr

    mov dl, [boot_drive]

    jmp 0x0000:LOAD_BASE


;
; ======================================================================
; Input
; ======================================================================
;

;
; read_choice
;
; Returns:
;   AL = input character
;
; Normal build:
;   Read from BIOS keyboard using INT 16h.
;
; TEST_SERIAL_INPUT build:
;   Read directly from COM1.
;
; The test build assumes QEMU has provided an emulated 16550 UART
; at the standard COM1 base address, 03F8h.
;

read_choice:

%ifdef TEST_SERIAL_INPUT

.wait_serial:
    ;
    ; COM1 Line Status Register = base + 5 = 03FDh.
    ;
    ; Bit 0 (Data Ready) indicates that the receive buffer contains
    ; a character.
    ;

    mov dx, 0x03fd
    in al, dx

    test al, 0x01
    jz .wait_serial

    ;
    ; COM1 Receive Buffer Register.
    ;

    mov dx, 0x03f8
    in al, dx

    ret

%else

    ;
    ; Production / interactive build.
    ;
    ; AH=00h waits for a BIOS keyboard character.
    ;

    xor ah, ah
    int 0x16

    ret

%endif


;
; ======================================================================
; Output
; ======================================================================
;

;
; print_char
;
; AL = character
;

print_char:
    push ax
    push bx

    mov ah, 0x0e
    mov bx, 0x0007
    int 0x10

    pop bx
    pop ax
    ret


 ; print_string: DS:SI -> NUL-terminated string
print_string:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp print_string
.done:
    ret


;
; ======================================================================
; Errors
; ======================================================================
;

disk_error:
    mov al, 'D'
    jmp fatal_error

invalid_pbr:
    mov al, 'P'

fatal_error:
    push al
    mov al, '!'
    call print_char
    pop al
    call print_char


hang:
    cli
    hlt
    jmp hang


;
; ======================================================================
; State
; ======================================================================
;

boot_drive:
    db 0

selected_partition:
    db 0


dap:
    db 0x10
    db 0
    dw 1
    dw LOAD_BASE
    dw 0
    dd 0
    dd 0


;
; ======================================================================
; Installed MBR boot-code region
; ======================================================================
;

%if ($-$$) > 440
    %error "MBR boot code exceeds 440 bytes"
%endif

times 440-($-$$) db 0
