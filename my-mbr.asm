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
; Display menu and choose partition
; ----------------------------------------------------------------------
;

    mov si, menu_name_1
    mov al, '1'
    call print_menu_line

    mov si, menu_name_2
    mov al, '2'
    call print_menu_line

    mov si, menu_name_3
    mov al, '3'
    call print_menu_line

    mov si, menu_name_4
    mov al, '4'
    call print_menu_line

.wait_key:
%ifdef TEST_SERIAL_INPUT
    call read_choice
%else
    ; Count BIOS tick changes using only the low tick byte.

.wait_key:
    xor ah, ah
    int 0x1a
    mov bl, dl          ; starting tick
    mov bh, 18          ; first dot after ~1 second

.poll_key:
    mov ah, 1
    int 0x16
    jnz .key_ready

    xor ah, ah
    int 0x1a

    sub dl, bl          ; DL = elapsed ticks

    cmp dl, bh
    jb .no_dot

    mov al, '.'
    call print_char
    add bh, 18          ; next dot ~1 second later

.no_dot:
    cmp dl, [menu_timeout]
    jb .poll_key


    ; Timeout: use whichever partition is already marked active.
    mov bx, PARTITION_TABLE
    xor al, al
    mov cx, 4

.find_active:
    cmp byte [bx], 0x80
    je .active_found
    add bx, 16
    inc al
    loop .find_active

    ; No active entry: start another timeout rather than choosing one.
    jmp .wait_key

.active_found:
    mov [selected_partition], al
    jmp .locate_selected

.key_ready:
    xor ah, ah
    int 0x16
%endif

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

.locate_selected:
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

    mov al, 13
    call print_char
    mov al, 10
    call print_char

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

%ifdef TEST_SERIAL_INPUT

read_choice:
.wait_serial:
    mov dx, 0x03fd
    in al, dx
    test al, 0x01
    jz .wait_serial

    mov dx, 0x03f8
    in al, dx
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


; AL = menu number, DS:SI = NUL-terminated menu name
print_menu_line:
    call print_char
    mov al, ' '
    call print_char
    call print_string
    mov al, 13
    call print_char
    mov al, 10
    jmp print_char


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
; Fixed configuration area
; ======================================================================
;
; These offsets are part of the on-disk configuration ABI.
; A configuration tool may overwrite the names and timeout without
; relocating or understanding the boot code.
;
; Each name occupies exactly 12 bytes including its terminating NUL,
; so the maximum displayed name is 11 characters.
;
; File offsets:
;   0180h  partition 1 name
;   018Ch  partition 2 name
;   0198h  partition 3 name
;   01A4h  partition 4 name
;   01B0h  timeout in BIOS ticks (byte; 55 ~= 3 seconds)
;

MENU_NAME_LEN equ 8

%if ($-$$) > 0x195
    %error "Code overlaps config area"
%endif

times 0x195 - ($ - $$) db 0

menu_name_1:
    db "Part1", 0
    times MENU_NAME_LEN-($-menu_name_1) db 0

menu_name_2:
    db "Part2", 0
    times MENU_NAME_LEN-($-menu_name_2) db 0

menu_name_3:
    db "Part3", 0
    times MENU_NAME_LEN-($-menu_name_3) db 0

menu_name_4:
    db "Part4", 0
    times MENU_NAME_LEN-($-menu_name_4) db 0

menu_timeout:
    db 160

;
; ======================================================================
; Installed MBR boot-code region
; ======================================================================
;

%if ($-$$) > 440
    %error "MBR boot code exceeds 440 bytes"
%endif

times 440-($-$$) db 0
