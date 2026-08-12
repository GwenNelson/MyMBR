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
; BIOS has loaded the complete MBR sector at 0000:7C00 and entered
; us there.
;
; This file is assembled with ORG 0600h, because that is where we
; actually want to execute. Therefore this initial stub must not use
; ordinary labels for data or control transfers until relocation is
; complete.
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
    ; Copy the complete 512-byte MBR from 0000:7C00 to 0000:0600.
    ;
    ; This includes the six bytes following our installed boot code,
    ; the partition table, and the 55 AA signature.
    ;

    mov si, LOAD_BASE
    mov di, RELOC_BASE
    mov cx, 256
    rep movsw

    ;
    ; Far jump into the relocated copy.
    ;
    ; We cannot simply say "jmp relocated" here because the instruction
    ; itself is currently executing at 7Cxx while NASM has assembled
    ; that relative jump assuming 06xx.
    ;
    ; The far jump contains an absolute offset, so this is safe.
    ;

    jmp 0x0000:relocated


;
; ======================================================================
; Relocated execution
; ======================================================================
;
; From here onwards we're really executing at the addresses NASM used,
; so ordinary labels work normally.
;

relocated:
    sti

    ;
    ; BIOS supplied the boot drive in DL.
    ;
    ; REP MOVSW did not alter it, so save it now.
    ;

    mov [boot_drive], dl


;
; ----------------------------------------------------------------------
; Choose partition
; ----------------------------------------------------------------------
;

.wait_key:
    ;
    ; INT 16h AH=00h:
    ;
    ;   waits for key
    ;   AL = ASCII character
    ;   AH = scan code
    ;

    xor ah, ah
    int 0x16

    cmp al, '1'
    jb .wait_key

    cmp al, '4'
    ja .wait_key

    sub al, '1'                   ; convert ASCII '1'..'4' to 0..3
    mov [selected_partition], al


;
; ----------------------------------------------------------------------
; Update active partition
; ----------------------------------------------------------------------
;

    ;
    ; Clear all four active flags.
    ;

    mov byte [PARTITION_TABLE + 0*16], 0
    mov byte [PARTITION_TABLE + 1*16], 0
    mov byte [PARTITION_TABLE + 2*16], 0
    mov byte [PARTITION_TABLE + 3*16], 0

    ;
    ; BX = selected partition entry.
    ;

    xor ah, ah
    mov bx, ax
    shl bx, 4                     ; index * 16
    add bx, PARTITION_TABLE

    ;
    ; Mark it active.
    ;

    mov byte [bx], 0x80


;
; ----------------------------------------------------------------------
; Write modified MBR back to disk
; ----------------------------------------------------------------------
;
; Write the complete relocated sector at 0000:0600 back to CHS 0/0/1.
;
; This preserves everything except the active flags we deliberately
; changed.
;

    xor ax, ax
    mov es, ax

    mov bx, RELOC_BASE

    mov ah, 0x03                  ; BIOS write sectors
    mov al, 1                     ; one sector

    xor ch, ch                    ; cylinder 0
    mov cl, 1                     ; sector 1
    xor dh, dh                    ; head 0

    mov dl, [boot_drive]

    int 0x13
    jc disk_error


;
; ----------------------------------------------------------------------
; Locate selected partition again
; ----------------------------------------------------------------------
;
; Do not assume BIOS preserved BX or any other useful register.
;

    mov al, [selected_partition]
    xor ah, ah

    mov bx, ax
    shl bx, 4
    add bx, PARTITION_TABLE


;
; ----------------------------------------------------------------------
; Load PBR
; ----------------------------------------------------------------------
;
; An MBR partition entry stores its starting CHS as:
;
;   +1  head
;   +2  sector in bits 0..5, cylinder bits 8..9 in bits 6..7
;   +3  cylinder bits 0..7
;
; This is already exactly the CH/CL/DH representation expected by
; INT 13h AH=02h, so no conversion is necessary.
;

    mov dh, [bx + 1]
    mov cl, [bx + 2]
    mov ch, [bx + 3]

    ;
    ; Read one sector to 0000:7C00.
    ;

    xor ax, ax
    mov es, ax

    mov bx, LOAD_BASE

    mov ah, 0x02                  ; BIOS read sectors
    mov al, 1

    mov dl, [boot_drive]

    int 0x13
    jc disk_error


;
; ----------------------------------------------------------------------
; Validate PBR
; ----------------------------------------------------------------------
;

    cmp word [LOAD_BASE + 510], 0xaa55
    jne invalid_pbr


;
; ----------------------------------------------------------------------
; Boot it
; ----------------------------------------------------------------------
;
; Restore DL because the PBR conventionally expects the BIOS boot
; drive there.
;

    mov dl, [boot_drive]

    jmp 0x0000:LOAD_BASE


;
; ======================================================================
; Error handling
; ======================================================================
;

disk_error:
    mov si, disk_error_message
    jmp print_error


invalid_pbr:
    mov si, invalid_pbr_message


print_error:
    lodsb

    test al, al
    jz hang

    mov ah, 0x0e                  ; BIOS teletype output
    mov bx, 0x0007
    int 0x10

    jmp print_error


hang:
    cli
    hlt
    jmp hang


;
; ======================================================================
; State / strings
; ======================================================================
;

boot_drive:
    db 0

selected_partition:
    db 0

disk_error_message:
    db "Disk error", 13, 10, 0

invalid_pbr_message:
    db "Invalid PBR", 13, 10, 0


;
; ======================================================================
; Installed MBR boot-code region
; ======================================================================
;
; The assembled file contains exactly bytes 0..439 of the MBR.
;
; install-mbr.sh preserves:
;
;   440..443   disk signature
;   444..445   reserved
;   446..509   partition table
;   510..511   55 AA signature
;
; At boot time BIOS loads all 512 bytes at 0000:7C00, and the relocation
; above copies all 512 bytes to 0000:0600.
;

%if ($-$$) > 440
    %error "MBR boot code exceeds 440 bytes"
%endif

times 440-($-$$) db 0

