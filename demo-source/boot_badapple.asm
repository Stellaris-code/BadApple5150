BITS 16
ORG 0x7c00
CPU 8086

%include "constants.asm"

; Memory map:
;0x500 - 0x518  : e820_buf (24 bytes)
;0x518 - 0x7c00 : mmap 
;0x7e00 - 0x8000 : stack
;0x8000 - 0x10000 : FAT
;0x10000 - 0x20000 : root_dir/cluster_buffer
;0x20000 onwards : Kernel

; BSS will be 0x500 -> 0x20000 (~90k)

free_segments equ 0x8-0x2 ; 0x8 : end segment; 0x2 : cluster_buffer segment : 6 segments of 64k = 

; important notes
;; BP = root_dir_size ! save bp if needed, then restore

fat					equ 0x8000
modes_tab    		equ 0x8000
e820_buf			equ 0x500
mmap				equ 0x518
root_dir_buf		equ 0x0
cluster_buffer		equ 0x0

;; BPB
initrd_save_address:
times 3 db 0 ; jump instruction
times 8 db 0 ; OEM
bytes_per_sector:
times 2 db 0 ; bytes per sector
sectors_per_cluster:
times 1 db 0 ; sectors per cluster
resv_sectors:
times 2 db 0 ; reserved sectors
fat_count:
times 1 db 0 ; number of FAT
root_entries:
times 2 db 0 ; directory entries
total_sectors:
times 2 db 0 ; total sectors
times 1 db 0 ; media type
sectors_per_fat:
times 2 db 0 ; sectors per FAT
sectors_per_track:
times 2 db 0 ; sectors per track
heads:
times 2 db 0 ; heads
times 4 db 0 ; hidden sectors
large_sector_count:
times 4 db 0 ; large sector count
;; EBR FAT16
root_dir_sectors: ; drive number and win NT flags are useless, steal their bytes to store the first data sector
times 1 db 0 ; drive number
times 1 db 0 ; win NT flags
times 1 db 0 ; signature
; again, who cares about a serial number ?
drive_number: ; reuse this address
times 4 db 0 ; serial number
filename: ; reuse label as the filename buffer
times 11 db 0 ; label
times 8 db 0 ; system identifier

; 0x3e :

boot:
	cld
	xor di, di ; 2
	mov ds, di ; 2
	mov ss, di ; mov ss inhibits interrupts for the next instruction
	mov sp, 0x8000
	sti

	xor dh, dh
	mov [drive_number], dx ; save the boot drive number 

	; set the video mode and clear the screen
	mov ax, 0x0003 ; 80x25 video mode
	int 0x10

	mov ax, 0x2000
	mov es, ax

	mov bp, 10 ; attempts

.retry:
	mov si, '13' ; error code
	dec bp
	jbe error ; display error if the floppy reads fail
	; reset the floppy
	xor ax, ax
	xor dx, dx
	int 0x13

%assign i 0
%rep 3
	; BIOS multitrack appears to be bugged on the original IBM 5150, read one head at a time
	mov ah, 0x02
	mov al, 8
	mov bx, 9*512*(2*i)
	mov ch, i+1 ; start with the second cylinder
	mov cl, 1 ; sector 1
	mov dl, [drive_number]
	mov dh, 0
	int 0x13
	jc .retry

	; The IBM PC 5150 BIOS doesn't support reading more than 8 sectors cleanly, we have to read the 9th by ourselves
	; read the 9th sector
	mov ah, 0x02
	mov al, 1
	mov bx, 9*512*(2*i) + 8*512
	mov ch, i+1 ; start with the second cylinder
	mov cl, 9 ; sector 1
	mov dl, [drive_number]
	mov dh, 0
	int 0x13
	jc .retry

	mov ah, 0x02
	mov al, 8
	mov bx, 9*512*(2*i+1)
	mov ch, i+1 ; start with the second cylinder
	mov cl, 1 ; sector 1
	mov dl, [drive_number]
	mov dh, 1
	int 0x13
	jc .retry

	; read the 9th sector
	mov ah, 0x02
	mov al, 1
	mov bx, 9*512*(2*i+1) + 8*512
	mov ch, i+1 ; start with the second cylinder
	mov cl, 9 ; sector 1
	mov dl, [drive_number]
	mov dh, 1
	int 0x13
	jc .retry
%assign i i+1
%endrep


	xor ax, ax
; Jump to the code data
	mov dx, 0x2000
	push dx
	push ax 
	retf ; a far return here has a shorter encoding than a long jump

error:
	xchg bx, bx
	push si ; push error code on the stack
	mov si, sp

	mov ah, 0xe
	;mov ax, 0xe23 ; al='#', ah=0xe
	;xor bx, bx ; bx=0000
	;int 0x10
	lodsb
	int 0x10 ; print chars one by one
	lodsb
	int 0x10 ; print chars one by one

	cli
	hlt


%assign free_bytes 510 - ($-$$)

%warning free_bytes bytes free
times free_bytes db 0 ; pad
dw 0xaa55 ; bootloader signature