BITS 16
CPU 8086

%include "constants.asm"

%if SEG(CODE_START) != SEG(FIRST_SECTOR_BUFFER)
%error "Code assumes that data and code share the same segment"
%endif

global decompress_render

extern sound_bar_delta

extern floppy_seek
extern floppy_read_request
extern floppy_read_collect
extern floppy_select

extern lyrics_dirty
extern lyric_counter
extern lyrics_string
extern lyrics_string_len
extern lyrics_string_left
extern write_line

cylinder_to_load:
db FIRST_DATA_SECTOR + 2
load_address:
dw FIRST_SECTOR_BUFFER >> 8

ALIGN 2
xor_lut:
dw 0x0200, 0x40, 0x0400, 0x20, 0x0800, 0x1000, 0x0008, 0x0010, 0x2000, 0x04, 0x01, 0x02, 0x4000, 0x8000, 0x80, 0x0100

ALIGN 256
shifted_lut:
%assign i 0
%rep 16
db ((0xFFFF >> i )>>8)&0xFF, (0xFFFF >> i )&0xFF
%assign i i+1
%endrep

ALIGN 256
shifted_lut_combined:
%assign j 0
%rep 16
%assign i 0
%rep 16
db ((0xFFFF >> i )>>8)&0xFF, (0xFFFF >> i )&0xFF
db ((0xFFFF >> j )>>8)&0xFF, (0xFFFF >> j )&0xFF
%assign i i+1
%endrep
%assign j j+1
%endrep


ALIGN 256
shifted_lut_mirrored:
%assign i 0
%rep 16
db (~(0xFFFF >> i )>>8)&0xFF, ~(0xFFFF >> i )&0xFF
%assign i i+1
%endrep

%macro EXEC_NEXT 0
	mov dx, ax ; dx contains the last value written

	lodsb

	; jump table cases

	xor bx, bx
	mov bl, al
	shl bx, 1
	jmp [bx+jump_table]
%endmacro

ALIGN 2
unroll_table:
%rep 192
	stosw
	add di, bp
%endrep
end_unroll_table:
EXEC_NEXT

; argument must be a power of two
%macro UNROLL_WRITE 0
	mov bx, cx 
	shl cx, 1
	add bx, cx ; * 3
	neg bx
	add bx, end_unroll_table
	jmp bx
%endmacro

decompress_render:
	mov di, SCREEN_BASE
	mov bp, 320/8 - 2
	xor ax, ax

	EXEC_NEXT


; 0xD0
rle:
	xor ah, ah
	lodsb
	mov cx, ax
	lodsw
UNROLL_WRITE


fill_line_white:
	lodsb
	cbw
	mov cx, ax
	mov ax, 0xFFFF
.outer_lp:
	mov bx, ds
	mov dx, es
	mov ds, dx 

%assign i 0
%rep 192
	mov [di+(320/8)*i], ax
	%assign i i+1
%endrep

	mov ds, bx

	add di, 2

	dec cx
	jnz .outer_lp

	EXEC_NEXT

fill_line_black:
	lodsb
	cbw
	mov cx, ax
	mov al, ah
.outer_lp:
	mov bx, ds
	mov dx, es
	mov ds, dx 

%assign i 0
%rep 192
	mov [di+(320/8)*i], ax
	%assign i i+1
%endrep

	mov ds, bx

	add di, 2

	dec cx
	jnz .outer_lp

	EXEC_NEXT

fill_line_word:
	lodsw
	mov bx, ax
	lodsb
	cbw
	mov cx, ax
	mov ax, bx
.outer_lp:
	mov bx, ds
	mov dx, es
	mov ds, dx 

%assign i 0
%rep 192
	mov [di+(320/8)*i], ax
	%assign i i+1
%endrep

	mov ds, bx

	add di, 2

	dec cx
	jnz .outer_lp

	EXEC_NEXT

line_end:
	sub di, (320/8)*192 - 2
	mov ax, dx
	EXEC_NEXT

frame_end:
	lodsb
	mov [sound_bar_delta], al 
	ret

data_end:
	stc ; set carry flag to indicate end of animation
	ret

lyrics_progress:
	lodsb
	mov [lyric_counter], al
	EXEC_NEXT

lyrics_next:
	mov byte [lyric_counter], 0

	xor ah, ah
	lodsb
	mov [lyrics_string_len], al
	mov cx, ax
	shr ax, 1 ; /2
	neg ax
	add ax, 16 ; left offset : (32/2) - (size/2)
	mov [lyrics_string_left], al

	mov byte [lyrics_dirty], 1
	mov bx, lyrics_string
.lp:
	lodsb
	mov [bx], al
	inc bx
	loop .lp
	EXEC_NEXT

next_drive_load:
cylinder_load:
	push ax

	push si
	push bp
	push di

	call floppy_read_collect

	mov bl, [cylinder_to_load]
	cmp bl, FLOPPY_CYLINDERS
	jae invalid_op ; there are only 80 cylinders on a 720k 3.5" floppy

	xor bh, bh
	call floppy_seek

	mov bl, [cylinder_to_load]
	xor bh, bh
	mov si, bx
	mov bx, [load_address]

	mov cx, SECTOR_SIZE-1 ; ISA DMA requires size-1
	call floppy_read_request

	xor word [load_address], SECTOR_SIZE >> 8 ; toggle between the first and second data buffer
	inc byte [cylinder_to_load]

	cmp byte [cylinder_to_load], FLOPPY_CYLINDERS
	jb .no_switch

 	mov al, 1
 	call floppy_select
 	mov byte [cylinder_to_load], 0

.no_switch:
	pop di
	pop bp
	pop si

	mov ax, [load_address]
	xor ah, ah
	xchg ah, al
	mov si, ax

	pop ax

	mov ax, dx
	EXEC_NEXT

invalid_op:
	jmp $
	dd 0xdeadbeef

;;;;; GENERATED OPERATIONS

%assign i 1
%rep 16
shifted_sequence_%[i]:
	mov bx, shifted_lut
%rep i / 2
	lodsb
	mov dl, al
	and al, 0x0F
	shl al, 1
	shr dl, 1
	shr dl, 1
	shr dl, 1
	and dl, 0b11110

	mov bl, al
	mov ax, [bx]
	stosw
	add di, bp

	mov bl, dl
	mov ax, [bx]
	stosw
	add di, bp
%endrep
%if i % 2 == 1
	lodsb
	and al, 0x0F
	shl al, 1
	mov bl, al
	mov ax, [bx]
	stosw
	add di, bp
%endif
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
shifted_sequence_mirrored_%[i]:
	mov bx, shifted_lut_mirrored
%rep i / 2
	lodsb
	mov dl, al
	and al, 0x0F
	shl al, 1
	shr dl, 1
	shr dl, 1
	shr dl, 1
	and dl, 0b11110

	mov bl, al
	mov ax, [bx]
	stosw
	add di, bp

	mov bl, dl
	mov ax, [bx]
	stosw
	add di, bp
%endrep
%if i % 2 == 1
	lodsb
	and al, 0x0F
	shl al, 1
	mov bl, al
	mov ax, [bx]
	stosw
	add di, bp
%endif
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
shifted_single_mirrored_%[i]:
	es mov word [di], ~((((0xFFFF >> (i-1) )>>8)) | (((0xFFFF >> (i-1) )&0xFF) << 8))
	add di, 320/8

	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
shifted_single_%[i]:
	es mov word [di], (((0xFFFF >> (i-1) )>>8)) | (((0xFFFF >> (i-1) )&0xFF) << 8)
	add di, 320/8
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_shifted_mirrored_%[i]:
	xor ah, ah
	lodsb
	mov cx, ax
	mov ax, ~((((0xFFFF >> (i-1) )>>8)) | (((0xFFFF >> (i-1) )&0xFF) << 8)) ; why lord, why
	UNROLL_WRITE
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_shifted_%[i]:
	xor ah, ah
	lodsb
	mov cx, ax
	mov ax, (((0xFFFF >> (i-1) )>>8)) | (((0xFFFF >> (i-1) )&0xFF) << 8) ; why lord, why
	UNROLL_WRITE
	%assign i i+1
%endrep

%macro xor_lut_macro 1-*
	%rotate %1
	xor dx, %1
%endmacro

%assign i 1
%rep 16
xor_repeat_%[i]:
	xor ah, ah
	xor_lut_macro i, 0x0200, 0x40, 0x0400, 0x20, 0x0800, 0x1000, 0x0008, 0x0010, 0x2000, 0x04, 0x01, 0x02, 0x4000, 0x8000, 0x80, 0x0100
	lodsb
	mov cx, ax
	mov ax, dx
	UNROLL_WRITE
	%assign i i+1
%endrep

%assign i 1
%rep 16
xor_single_%[i]:
	xor_lut_macro i, 0x0200, 0x40, 0x0400, 0x20, 0x0800, 0x1000, 0x0008, 0x0010, 0x2000, 0x04, 0x01, 0x02, 0x4000, 0x8000, 0x80, 0x0100
	mov ax, dx

	stosw
	add di, bp

	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
rawblock_%[i]:
%rep i-1
	movsw
	add di, bp
%endrep
; do the final load/store with lodsw/stosw in order to load ax with the last value written
	lodsw
	stosw
	add di, bp
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_ffff_%[i]:
	mov ax, 0xFFFF
%rep i
	stosw
	add di, bp
%endrep
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_0_%[i]:
	xor ax, ax
%rep i
	stosw
	add di, bp
%endrep
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_zx_%[i]:
	xor ah, ah
	lodsb
%rep i
	stosw
	add di, bp
%endrep
	EXEC_NEXT
	%assign i i+1
%endrep

%assign i 1
%rep 16
repeat_word_%[i]:
	lodsw
%rep i
	stosw
	add di, bp
%endrep
	EXEC_NEXT
	%assign i i+1
%endrep

ALIGN 2
jump_table:
; 0x00
%assign i 1
%rep 16
dw shifted_single_%[i]
%assign i i+1
%endrep
; 0x10
%assign i 1
%rep 16
dw shifted_single_mirrored_%[i]
%assign i i+1
%endrep
; 0x20
%assign i 1
%rep 16
dw repeat_shifted_mirrored_%[i]
%assign i i+1
%endrep
; 0x30
%assign i 1
%rep 16
dw repeat_shifted_%[i]
%assign i i+1
%endrep
; 0x40
%rep 16
dw invalid_op
%endrep
; 0x50
%assign i 1
%rep 16
dw xor_single_%[i]
%assign i i+1
%endrep
; 0x60
%assign i 1
%rep 16
dw shifted_sequence_%[i]
%assign i i+1
%endrep
; 0x70
%assign i 1
%rep 16
dw rawblock_%[i]
%assign i i+1
%endrep
; 0x80
%assign i 1
%rep 16
dw repeat_0_%[i]
%assign i i+1
%endrep
; 0x90
%assign i 1
%rep 16
dw repeat_ffff_%[i]
%assign i i+1
%endrep
; 0xA0
%assign i 1
%rep 16
dw repeat_zx_%[i]
%assign i i+1
%endrep
; 0xB0
%assign i 1
%rep 16
dw repeat_word_%[i]
%assign i i+1
%endrep
; 0xC0
%assign i 1
%rep 16
dw xor_repeat_%[i]
%assign i i+1
%endrep
; 0xD0
dw rle 
dw fill_line_black
dw fill_line_white
dw fill_line_word
dw frame_end
dw line_end
dw data_end
dw cylinder_load
dw next_drive_load
dw lyrics_progress
dw lyrics_next
%rep 5
dw invalid_op
%endrep
; 0xE0
%assign i 1
%rep 16
dw shifted_sequence_mirrored_%[i]
%assign i i+1
%endrep
; 0xF0
%rep 16
dw invalid_op
%endrep