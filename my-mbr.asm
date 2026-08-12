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
; Display BIOS disk geometry
; ----------------------------------------------------------------------
;
; INT 13h AH=08h returns:
;
;   CH       cylinder bits 0..7
;   CL 6..7  cylinder bits 8..9
;   CL 0..5  sectors per track
;   DH       maximum head number
;
; CH/DH are maximum values, so cylinder/head counts are +1.
;

    mov ah, 0x08
    mov dl, [boot_drive]
    int 0x13
    jc geometry_error

    ;
    ; Save the returned values before using BIOS video services.
    ;

    mov [geometry_ch], ch
    mov [geometry_cl], cl
    mov [geometry_dh], dh

    ;
    ; "C="
    ;

    mov al, 'C'
    call print_char

    mov al, '='
    call print_char

    ;
    ; Decode cylinder:
    ;
    ; cylinder =
    ;   CH | ((CL & 0xC0) << 2)
    ;
    ; AX = cylinder count.
    ;

    xor ax, ax
    mov al, [geometry_cl]
    and ax, 0x00c0
    shl ax, 1
    shl ax, 1

    xor bx, bx
    mov bl, [geometry_ch]
    or ax, bx

    inc ax
    call print_uint


    ;
    ; " H="
    ;

    mov al, ' '
    call print_char

    mov al, 'H'
    call print_char

    mov al, '='
    call print_char

    ;
    ; Heads = maximum head + 1.
    ;

    xor ax, ax
    mov al, [geometry_dh]
    inc ax
    call print_uint


    ;
    ; " S="
    ;

    mov al, ' '
    call print_char

    mov al, 'S'
    call print_char

    mov al, '='
    call print_char

    ;
    ; Sectors per track = CL bits 0..5.
    ;

    xor ax, ax
    mov al, [geometry_cl]
    and ax, 0x003f
    call print_uint

    ;
    ; Newline.
    ;

    mov al, 13
    call print_char

    mov al, 10
    call print_char


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
; Load PBR using legacy CHS
; ----------------------------------------------------------------------
;

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


;
; print_uint
;
; Print unsigned 16-bit AX in decimal.
;
; Destroys AX, BX, CX, DX.
;

print_uint:
    xor cx, cx
    mov bx, 10

.convert:
    xor dx, dx
    div bx

    push dx
    inc cx

    test ax, ax
    jnz .convert

.print:
    pop ax
    add al, '0'
    call print_char

    loop .print

    ret


;
; ======================================================================
; Errors
; ======================================================================
;

geometry_error:
    mov si, geometry_error_message
    jmp print_error

disk_error:
    mov si, disk_error_message
    jmp print_error

invalid_pbr:
    mov si, invalid_pbr_message


print_error:
    lodsb

    test al, al
    jz hang

    call print_char
    jmp print_error


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

geometry_ch:
    db 0

geometry_cl:
    db 0

geometry_dh:
    db 0


geometry_error_message:
    db "Geometry error", 13, 10, 0

disk_error_message:
    db "Disk error", 13, 10, 0

invalid_pbr_message:
    db "Invalid PBR", 13, 10, 0


;
; ======================================================================
; Installed MBR boot-code region
; ======================================================================
;

%if ($-$$) > 440
    %error "MBR boot code exceeds 440 bytes"
%endif

times 440-($-$$) db 0
