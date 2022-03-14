BITS 16
CPU 8086

global font
global write_line
global write_partial_char

; source : darkrose, https://opengameart.org/content/8x8-ascii-bitmap-font-with-c-source
font:
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x8, 0x8, 0x8, 0x8, 0x0, 0x8, 0x0
db 0x0, 0x28, 0x28, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x0, 0x28, 0x7c, 0x28, 0x7c, 0x28, 0x0
db 0x0, 0x8, 0x1e, 0x28, 0x1c, 0xa, 0x3c, 0x8
db 0x0, 0x60, 0x94, 0x68, 0x16, 0x29, 0x6, 0x0
db 0x0, 0x1c, 0x20, 0x20, 0x19, 0x26, 0x19, 0x0
db 0x0, 0x8, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x8, 0x10, 0x20, 0x20, 0x10, 0x8, 0x0
db 0x0, 0x10, 0x8, 0x4, 0x4, 0x8, 0x10, 0x0
db 0x0, 0x2a, 0x1c, 0x3e, 0x1c, 0x2a, 0x0, 0x0
db 0x0, 0x0, 0x8, 0x8, 0x3e, 0x8, 0x8, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x0, 0x8, 0x10, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x3c, 0x0, 0x0, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x8, 0x0
db 0x0, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x0
db 0x0, 0x18, 0x24, 0x42, 0x42, 0x24, 0x18, 0x0
db 0x0, 0x8, 0x18, 0x8, 0x8, 0x8, 0x1c, 0x0
db 0x0, 0x3c, 0x42, 0x4, 0x18, 0x20, 0x7e, 0x0
db 0x0, 0x3c, 0x42, 0x4, 0x18, 0x42, 0x3c, 0x0
db 0x0, 0x8, 0x18, 0x28, 0x48, 0x7c, 0x8, 0x0
db 0x0, 0x7e, 0x40, 0x7c, 0x2, 0x42, 0x3c, 0x0
db 0x0, 0x3c, 0x40, 0x7c, 0x42, 0x42, 0x3c, 0x0
db 0x0, 0x7e, 0x4, 0x8, 0x10, 0x20, 0x40, 0x0
db 0x0, 0x3c, 0x42, 0x3c, 0x42, 0x42, 0x3c, 0x0
db 0x0, 0x3c, 0x42, 0x42, 0x3e, 0x2, 0x3c, 0x0
db 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x8, 0x0
db 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x8, 0x10
db 0x0, 0x0, 0x6, 0x18, 0x60, 0x18, 0x6, 0x0
db 0x0, 0x0, 0x0, 0x7e, 0x0, 0x7e, 0x0, 0x0
db 0x0, 0x0, 0x60, 0x18, 0x6, 0x18, 0x60, 0x0
db 0x0, 0x38, 0x44, 0x4, 0x18, 0x0, 0x10, 0x0
db 0x1c, 0x0, 0x3c, 0x44, 0x9c, 0x94, 0x5c, 0x20
db 0x0, 0x18, 0x18, 0x24, 0x3c, 0x42, 0x42, 0x0
db 0x0, 0x78, 0x44, 0x78, 0x44, 0x44, 0x78, 0x0
db 0x0, 0x38, 0x44, 0x80, 0x80, 0x44, 0x38, 0x0
db 0x0, 0x78, 0x44, 0x44, 0x44, 0x44, 0x78, 0x0
db 0x0, 0x7c, 0x40, 0x78, 0x40, 0x40, 0x7c, 0x0
db 0x0, 0x7c, 0x40, 0x78, 0x40, 0x40, 0x40, 0x0
db 0x0, 0x38, 0x44, 0x80, 0x9c, 0x44, 0x38, 0x0
db 0x0, 0x42, 0x42, 0x7e, 0x42, 0x42, 0x42, 0x0
db 0x0, 0x3e, 0x8, 0x8, 0x8, 0x8, 0x3e, 0x0
db 0x0, 0x1c, 0x4, 0x4, 0x4, 0x44, 0x38, 0x0
db 0x0, 0x44, 0x48, 0x50, 0x70, 0x48, 0x44, 0x0
db 0x0, 0x40, 0x40, 0x40, 0x40, 0x40, 0x7e, 0x0
db 0x0, 0x41, 0x63, 0x55, 0x49, 0x41, 0x41, 0x0
db 0x0, 0x42, 0x62, 0x52, 0x4a, 0x46, 0x42, 0x0
db 0x0, 0x1c, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0
db 0x0, 0x78, 0x44, 0x78, 0x40, 0x40, 0x40, 0x0
db 0x0, 0x1c, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x2
db 0x0, 0x78, 0x44, 0x78, 0x50, 0x48, 0x44, 0x0
db 0x0, 0x1c, 0x22, 0x10, 0xc, 0x22, 0x1c, 0x0
db 0x0, 0x7f, 0x8, 0x8, 0x8, 0x8, 0x8, 0x0
db 0x0, 0x42, 0x42, 0x42, 0x42, 0x42, 0x3c, 0x0
db 0x0, 0x81, 0x42, 0x42, 0x24, 0x24, 0x18, 0x0
db 0x0, 0x41, 0x41, 0x49, 0x55, 0x63, 0x41, 0x0
db 0x0, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x0
db 0x0, 0x41, 0x22, 0x14, 0x8, 0x8, 0x8, 0x0
db 0x0, 0x7e, 0x4, 0x8, 0x10, 0x20, 0x7e, 0x0
db 0x0, 0x38, 0x20, 0x20, 0x20, 0x20, 0x38, 0x0
db 0x0, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x0
db 0x0, 0x38, 0x8, 0x8, 0x8, 0x8, 0x38, 0x0
db 0x0, 0x10, 0x28, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x7e, 0x0
db 0x0, 0x10, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0
db 0x0, 0x0, 0x3c, 0x2, 0x3e, 0x46, 0x3a, 0x0
db 0x0, 0x40, 0x40, 0x7c, 0x42, 0x62, 0x5c, 0x0
db 0x0, 0x0, 0x0, 0x1c, 0x20, 0x20, 0x1c, 0x0
db 0x0, 0x2, 0x2, 0x3e, 0x42, 0x46, 0x3a, 0x0
db 0x0, 0x0, 0x3c, 0x42, 0x7e, 0x40, 0x3c, 0x0
db 0x0, 0x0, 0x18, 0x10, 0x38, 0x10, 0x10, 0x0
db 0x0, 0x0, 0x34, 0x4c, 0x44, 0x34, 0x4, 0x38
db 0x0, 0x20, 0x20, 0x38, 0x24, 0x24, 0x24, 0x0
db 0x0, 0x8, 0x0, 0x8, 0x8, 0x8, 0x8, 0x0
db 0x8, 0x0, 0x18, 0x8, 0x8, 0x8, 0x8, 0x70
db 0x0, 0x20, 0x20, 0x24, 0x28, 0x30, 0x2c, 0x0
db 0x0, 0x10, 0x10, 0x10, 0x10, 0x10, 0x18, 0x0
db 0x0, 0x0, 0x0, 0x66, 0x5a, 0x42, 0x42, 0x0
db 0x0, 0x0, 0x0, 0x2e, 0x32, 0x22, 0x22, 0x0
db 0x0, 0x0, 0x0, 0x3c, 0x42, 0x42, 0x3c, 0x0
db 0x40, 0x0, 0x0, 0x5c, 0x62, 0x42, 0x7c, 0x40
db 0x0, 0x0, 0x3a, 0x46, 0x42, 0x3e, 0x2, 0x2
db 0x0, 0x0, 0x0, 0x2c, 0x32, 0x20, 0x20, 0x0
db 0x0, 0x0, 0x1c, 0x20, 0x18, 0x4, 0x38, 0x0
db 0x0, 0x0, 0x10, 0x3c, 0x10, 0x10, 0x18, 0x0
db 0x0, 0x0, 0x0, 0x22, 0x22, 0x26, 0x1a, 0x0
db 0x0, 0x0, 0x0, 0x42, 0x42, 0x24, 0x18, 0x0
db 0x0, 0x0, 0x0, 0x81, 0x81, 0x5a, 0x66, 0x0
db 0x0, 0x0, 0x0, 0x42, 0x24, 0x18, 0x66, 0x0
db 0x0, 0x0, 0x42, 0x22, 0x14, 0x8, 0x10, 0x60
db 0x0, 0x0, 0x0, 0x3c, 0x8, 0x10, 0x3c, 0x0
db 0x0, 0x1c, 0x10, 0x30, 0x30, 0x10, 0x1c, 0x0
db 0x0, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8
db 0x0, 0x38, 0x8, 0xc, 0xc, 0x8, 0x38, 0x0
db 0x0, 0x0, 0x0, 0x0, 0x32, 0x4c, 0x0, 0x0
db 0x0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x0

early_ret:
	ret

; left offset in dx, line data in bx, count in cx
; thrases everything else
write_line:
	; early out
	; the jump is backwards, as a forwards jump would result in a relative offset too large to fit in a single byte
	jcxz early_ret

	; save cx
	mov si, cx
	; bp : right margin bytes
	mov bp, 256/8
	sub bp, dx ; left margin
	sub bp, cx ; text content

	; clear left margin
	xor ax, ax
%assign i 0
%rep 8
	mov di, (192+i)*(320/8) + 4
	mov cx, dx
	rep stosb
%assign i i+1
%endrep

	mov di, 192*(320/8) + 4
	add di, dx
	mov cx, si
.lp:
	mov si, font
	xor ax, ax
	mov al, [bx]
	inc bx
	shl ax, 1
	shl ax, 1
	shl ax, 1 ; *8
	add si, ax ; font offset
%rep 8
	movsb
	add di, 320/8 - 1
%endrep
	sub di, 8*(320/8) - 1 ; next column
	loop .lp

	; clear right margin
	xor ax, ax
%assign i 0
%rep 8
	mov cx, bp
	rep stosb
	add di, 320/8
	sub di, bp
%assign i i+1
%endrep

.out:
	ret

; position in dx, char in ax
; bits to display (left-to-right) in cl
write_partial_char:
	mov di, 192*(320/8) + 4
	add di, dx

	mov si, font
	xor ah, ah
	shl ax, 1
	shl ax, 1
	shl ax, 1 ; *8
	add si, ax 

	xor bh, bh
	mov bl, cl
	mov dl, [bitmasks+bx]
	%rep 8
	lodsb
	and al, dl ; mask off the part we don't want to display
	stosb
	add di, 320/8 - 1
	%endrep

	ret

bitmasks:
db 0b1111111
db 0b111111
db 0b11111
db 0b1111
db 0b111
db 0b11
db 0b1
db 0