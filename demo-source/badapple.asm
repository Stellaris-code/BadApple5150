BITS 16
CPU 8086

;; TODO:
; loading screen : "please wait warmly..."

%include "constants.asm"

global init
global err
global wait_next_frame
global frame_accumulator
global sound_bar_delta

global lyrics_dirty
global lyric_counter
global lyrics_string
global lyrics_string_len
global lyrics_string_left

extern update_palette
extern floppy_disk_init
extern floppy_seek
extern floppy_read_request
extern floppy_read_collect
extern floppy_select
extern decompress_render

extern left_kanji_plane_0
extern left_kanji_plane_2
extern right_kanji_plane_0
extern right_kanji_plane_2

extern font
extern write_line
extern write_partial_char

%macro SETGC  2
        mov     dx,GC_INDEX
        mov     ax,((%2) << 8) | (%1)
        out     dx,ax
%endmacro

%macro SETSQ  2
        mov     dx,SQ_INDEX
        mov     ax,((%2) << 8) | (%1)
        out     dx,ax
%endmacro

; Switch to the other page to allow pseudo double-buffering
%macro PAGE_FLIP 1
	call wait_vsync
	mov bl, %1
	call change_color_page
    %if %1 == 0
	SETSQ SQ_PLANEMASK, PLANE_1
    %else 
    	SETSQ SQ_PLANEMASK, PLANE_0
    %endif
%endmacro

entry:
	jmp init

max_accumulator:
db 0
frame_accumulator:
dw 0
frame_wait_target:
dw PIT_FREQ
frame_delay_total:
dw 0

music_data_ptr:
dw 0
codemap_addr:
dw 0
music_irq_delay:
dw 1

lyrics_dirty:
db 0 ; 1 if lyrics need to be changed
lyrics_string:
db "                                "
lyrics_string_len:
db 32
lyrics_string_left:
db 0
sound_bar_delta:
db 0

timer_irq_handler:
	; set the frame wait flag
	cs inc word [frame_accumulator]

	; let the PIC know we've handled the interrupt
	push ax
	mov al,0x20
	out 0x20,al
	pop ax
	iret

music_irq_handler:
	push ax

	; Update the timekeeping memory variables

	cs inc word [frame_accumulator]
	cs sub word [music_irq_delay], 1000 / PIT_FREQ
	; if a delay was scheduled, exit immediately
.exit_jump:
	ja .early_out

	push dx
	push bx
	push si
	push ds

	; load the segment containing the music data to be played
	; this instruction will later be modified to load the segment containing the second half of the music data
.seg_load_instruction:
	cs mov ax, MUSIC_SEG_1
	mov ds, ax

	cs mov si, [music_data_ptr]
	cs mov bx, [codemap_addr]
	mov dx, OPL_BASE
.inner_loop:
	; load the byte command
	lodsb

	xor ah, ah
	cmp al, 0x7A ; delay command
	je .delay
	cmp al, 0xFF ; extracode marker, to encode more complicated command
	je .extracode

	shl ax, 1
	shl ah, 1 ; ah = register set offset
	shr al, 1 ; al = al & 0x7F
	xlatb ; load the target register from the codemap

	add dl, ah ; add the register offset
	out dx, al

	lodsb
	inc dx ; next port is the data register port
	out dx, al
	; reset register base
	mov dl, OPL_BASE&0xFF
	jmp .inner_loop

.extracode:
	lodsb ; load the extra command 
	cmp al, 0x00
	je .segswitch ; switch to the segment containing the second half of the data
	cmp al, 0x01
	je .music_end ; end of song

	; error, invalid extracode
	mov ah, 0xEF
	jmp err

.segswitch:
	mov ax, MUSIC_SEG_2
	mov ds, ax
	cs mov [.seg_load_instruction+2], ax ; modify the segment load instruction to use 
	mov si, 0x94 ; skip the header part of this segment

	jmp .inner_loop

.music_end:
	; the song is over, replace the IRQ code with a jump to the return code
	cs mov byte [.exit_jump], 0xEB ; replace jnz with jmp

	jmp .inner_loop

.delay:
	xor ah, ah
	lodsb ; load the delay duration

	inc ax ; duration is zero-based, increment to correct
	cs mov [music_irq_delay], ax
	cs mov [music_data_ptr], si

.out:
	pop ds
	pop si
	pop bx
	pop dx

.early_out:
	; let the PIC know we've handled the interrupt
	mov al,0x20
	out 0x20,al

	pop ax
	iret

wait_next_frame:
	mov ax, [frame_wait_target]
	mov bx, frame_accumulator
.lp:
	hlt ; NOTE - bochs has a hard time keeping timer interrupts accurate if we put the cpu in a halt state
	cmp [bx], ax
	jb .lp ; reloop if the interrupt that woke the CPU up was not IRQ0

	mov word [bx], 0 ; reset the wait flag to zero
	ret


wait_vsync:
	mov dx, INPUT_STATUS
; wait until vertical retrace bit is set
.l1:
	in al, dx
	test al, 08h
	jz .l1
	ret

; Load palette data into the VGA palette RAM
; First byte of the data is the offset into palette RAM
; Next 16 bytes are the grayscale values to be put into palette RAM
; si : base of palette data
load_palette_for_plane:
	lodsb
	xor ah, ah
	mov dx, 3c8h
	out dx, al ; load palette RAM address base
	inc dx ; 3c9h; data port

%rep 16
	lodsb
	out dx, al
	out dx, al
	out dx, al
%endrep
	ret

; 16 colors format:

; a|b|c|d
; a/b : buffer 0, buffer 1 for palette page flipping
; c : intensity bit (low-intensity if set)
; d : negate bit


; Do page flipping, implemented by switching the palette using the color select register to either display plane 0 or plane 1 as the monochrome data
; page in bits 2-3 of bl
change_color_page:
	cli

	mov dx, 0x03da
	in al, dx
	mov dx, 0x03c0
	mov al, 0x14 | 0x20 ; We're not touching the palette RAM proper, so set the PAS bit to tell the CRTC that it can access it
	out dx, al
	xchg al, bl

	out dx, al

	mov al, 0x20
	out dx, al

	sti
	ret


; Entry point of our code
init:
	; disable interrupts while we set the interrupt handler
	cli

	; CS is still set to segment 0x0000
	; set the PIT IRQ handler up by modifying the relevant IDT entry
	mov word [0x0020], timer_irq_handler
	mov word [0x0022], cs

	; set the PIT up
	mov al, 0x36
	out 0x43, al

	; load the frequency for channel 0
	mov ax, 1193180 / PIT_FREQ
	out 0x40, al 
	xchg al, ah 
	out 0x40, al 
	sti

	; load ds with cs
	push cs
	pop ds

	; Initialize the two floppies
	call floppy_disk_init
	mov al, 1
	call floppy_select
	xor bx, bx
	call floppy_seek ; seek cylinder 0
	mov al, 0
	call floppy_select
	xor bx, bx
	call floppy_seek ; seek cylinder 0

	mov ax, 0x000D
	int 10h ; switch to VGA mode 0Dh (320x200)

; Initialise the palette registers and RAM
	mov ax, 0x1013
	mov bh, 1 ; set paging mode, 16 blocks of 16 colors
	int 0x10
	inc bx ; select page, page 0
	int 0x10

	; set palette RAM to pass-through
	mov ax, cs
	mov es, ax
	mov dx, palette_ram
	xor bh, bh
	mov ax, 0x1002
	int 0x10

	mov si, palette_data_plane_0
	call load_palette_for_plane
	mov si, palette_data_plane_1
	call load_palette_for_plane

; Initialize the framebuffer
	; set es to point to the VGA address range
	mov ax, 0xa000
	mov es, ax ; ds = buffer; es = framebuffer

	call wait_vsync
	mov bl, 1 << 2
	call change_color_page

	; Clear plane 2 & 3
	SETSQ SQ_PLANEMASK, PLANE_NEGATE | PLANE_SHADE
	xor di, di
	mov cx, 320*200/8 / 2
	mov ax, 0x0000
	rep stosw

	call wait_vsync
	; Plane 0&1
	SETSQ SQ_PLANEMASK, PLANE_0 | PLANE_1
	xor di, di
	mov cx, 320*200/8 / 2
	mov ax, 0xffff
	rep stosw

	; Clear the lyrics line using a 32 spaces long string
	mov bx, lyrics_string
	xor ch, ch
	mov cl, [lyrics_string_len]
	mov dx, cx
	shr dx, 1 ; /2
	neg dx
	add dx, 16 ; left offset : (32/2) - (size/2)
	mov [lyrics_string_left], dl
	call write_line

	call write_kanji_art

; Load the music data from the second floppy into the appropriate RAM locations

 	mov al, 1
 	call floppy_select

 	; Load the first 64kiB of data into 0x1000-0x1FFF
%assign i 0
%rep 7
 	mov bx, FIRST_MUSIC_CYLINDER + i
	call floppy_seek

	mov si, FIRST_MUSIC_CYLINDER + i
	mov cx, SECTOR_SIZE-1
	mov bx, 0x0100 + ((i*SECTOR_SIZE) >> 8)
	call floppy_read_request
	call floppy_read_collect

%assign i i+1
%endrep
	; Load the second 64kiB into 0x3000-0x3FFF
%rep 7
 	mov bx, FIRST_MUSIC_CYLINDER + i
	call floppy_seek

	mov si, FIRST_MUSIC_CYLINDER + i
	mov cx, SECTOR_SIZE-1
	mov bx, 0x0300 + (((i-7)*SECTOR_SIZE) >> 8)
	call floppy_read_request
	call floppy_read_collect

%assign i i+1
%endrep

	; Switch back to the first floppy to start reading animation data
	mov al, 0
	call floppy_select

	; seeking to cylinder 0 first is apparently necessary
	mov bx, 0
	call floppy_seek

	mov bx, FIRST_DATA_SECTOR ; cylinder 4, head 0
	call floppy_seek

	; Load the first cylinder of animation data
	mov si, FIRST_DATA_SECTOR
	mov cx, SECTOR_SIZE-1
	mov bx, (FIRST_SECTOR_BUFFER >> 8)
	call floppy_read_request
	call floppy_read_collect
	

	mov bx, FIRST_DATA_SECTOR+1
	call floppy_seek

	; Start a read request for the next cylinder
	mov si, FIRST_DATA_SECTOR+1
	mov cx, SECTOR_SIZE-1
	mov bx, (SECOND_SECTOR_BUFFER >> 8)
	call floppy_read_request


; Initialize the music handling code
	; 0x0100:si points to the base of the music data, skip until the actual start of the commands
	xor si, si 
	add si, 12 ; skip version number and signature
	add si, 13 ; skip until codemap len
	add si, 1 ; to codemap
	mov bx, si ; bx = codemap base
	cs mov [codemap_addr], bx	
	add si, 0x7A ; skip to start of data
	cs mov [music_data_ptr], si

	; set the IRQ0 handler to play the music data
	cli
	ss mov word [0x0020], music_irq_handler ; ss is always segment 0
	sti

; Initialize the counters and registers in order to play the animation
	SETSQ SQ_PLANEMASK, PLANE_1
	mov word [frame_wait_target], PIT_FREQ/15 
	mov word [frame_delay_total], 0

	mov si, OFF(FIRST_SECTOR_BUFFER)

	mov word [frame_accumulator], 0

; small frame delay to properly start the music at the same time as the animation
%rep INITIAL_ANIM_DELAY
	call wait_next_frame
%endrep

anim_loop:
	; Display page 1, write to page 0
	PAGE_FLIP 1

	call wait_next_frame
	mov byte [frame_accumulator], 0

	call decompress_render
	jc .out

	call update_debug_info
	call update_sound_bar
	call update_lyrics_progress

	; Display page 0, write to page 1
	PAGE_FLIP 0

	call wait_next_frame
	mov byte [frame_accumulator], 0

	call decompress_render

	pushf
	call update_debug_info
	call update_sound_bar
	call update_lyrics_progress
	popf

	jnc anim_loop ; carry bit is set if the animation is over

.out:
	; Handle the last cylinder read request in flight
	call floppy_read_collect

	; display the total of frame delays
	mov al, 0x02 
	out 0x7A, al
	mov al, [frame_delay_total]
	out 0x7B, al
	mov al, 0x04
	out 0x7A, al
	mov al, [frame_delay_total+1]
	out 0x7B, al

.endless_loop:
	cli
	hlt
	jmp .endless_loop ; endless loop jump, just in case the cpu leaves the halted state by some unexplainable wizardry

update_debug_info:
	mov ah, [frame_accumulator]
	cmp ah, [max_accumulator]
	jbe .nomaxupdate
	mov [max_accumulator], ah
	mov al, 0x04 ; left hex display shows the maximum frame cost yet
	out 0x7A, al
	mov al, ah
	out 0x7B, al
.nomaxupdate:
	mov al, 0x02 
	out 0x7A, al
	mov al, ah
	out 0x7B, al
	xor ah, ah 
	add [frame_delay_total], ax
	ret

; lyric progress counter : 
; BBBBBaaa
; B : character counter
; b : sub-character counter
lyric_counter:
db (4 << 3) | (2)

update_lyrics_progress:
	push si
	push di

	; switch the ds register for this function
	push ds 
	push cs 
	pop ds

	; Do we have to redraw the lyrics line?
	cmp byte [lyrics_dirty], 0
	jz .notdirty

	; Redraw the entire lyrics if needed (switched to another line)
	SETSQ SQ_PLANEMASK, PLANE_0 | PLANE_1

	mov bx, lyrics_string
	xor ch, ch
	mov cl, [lyrics_string_len]
	xor dh, dh
	mov dl, [lyrics_string_left]
	call write_line
	mov byte [lyrics_dirty], 0

.notdirty:

	; Draw the lyrics progress using the shading plane
	; Writing to the shading plane will grey out parts of the lyrics that haven't been sung yet

	; shading plane
	SETSQ SQ_PLANEMASK, PLANE_SHADE

	xor ah, ah
	mov al, [lyric_counter] ; load current counter value
	mov ah, al
	and al, 0b00000111 ; subchar counter
	shr ah, 1
	shr ah, 1
	shr ah, 1 ; char counter

	push ax ; al = subchar counter, ah = whole char counter

	xor dh, dh
	mov dl, ah ; char counter
	xor ch, ch
	mov cl, [lyrics_string_len]
	sub cl, dl ; cl = lyrics chars left

	mov bx, lyrics_string
	add bl, dl
	add dl, [lyrics_string_left] ; left offset
	call write_line

	; then partially write the last character according to the subcharacter counter

	pop ax ; al = subchar counter, ah = whole char counter

	xor dh, dh
	mov dl, [lyrics_string_left] ; left offset
	add dl, ah

	xor ch, ch
	mov cl, al ; subchar counter
	xor bh, bh 
	mov bl, ah
	xor ah, ah
	mov al, [lyrics_string+bx]
	call write_partial_char

	pop ds
	pop di
	pop si

	ret

last_audio_level:
db 0

update_sound_bar:
	; sound bar
	SETSQ SQ_PLANEMASK, PLANE_NEGATE
	push di
	xor bh, bh
	mov bl, [last_audio_level]
	add bl, [sound_bar_delta]
	mov [last_audio_level], bl


	xor di, di 
	mov cx, 200
	sub cl, bl
	jcxz .out1 ; early out if cx 0
	mov ax, 0x0
.lp0:
	stosw
	stosw
	add di, 256/8 ; jump to the bar on the right side
	stosw
	stosw
	loop .lp0	
.out1:

	mov cl, bl
	jcxz .out2 ; early out if cx 0
	mov ax, 0xffff
.lp1:
	stosw
	stosw
	add di, 256/8 ; jump to the bar on the right side
	stosw
	stosw
	loop .lp1
.out2:

	pop di

	ret

write_kanji_art:
	; write kanji art data
	mov di, 320/8*LEFT_KANJI_START
	mov si, left_kanji_plane_0 	
	mov cx, LEFT_KANJI_HEIGHT
.lp1:
	movsw
	movsw
	add di, 320/8 - 4
	loop .lp1

	mov di, 320/8*RIGHT_KANJI_START + RIGHT_KANJI_OFFSET/8
	mov si, right_kanji_plane_0 	
	mov cx, RIGHT_KANJI_HEIGHT
.lp2:
	movsw
	movsw
	add di, 320/8 - 4
	loop .lp2

	; Plane 2
	SETSQ SQ_PLANEMASK, PLANE_SHADE
	mov di, 320/8*LEFT_KANJI_START
	mov si, left_kanji_plane_2
	mov cx, LEFT_KANJI_HEIGHT
.lp3:
	movsw
	movsw
	add di, 320/8 - 4
	loop .lp3


	mov di, 320/8*RIGHT_KANJI_START + RIGHT_KANJI_OFFSET/8
	mov si, right_kanji_plane_2
	mov cx, RIGHT_KANJI_HEIGHT
.lp4:
	movsw
	movsw
	add di, 320/8 - 4
	loop .lp4

	ret

; error in ah
err:
	; output the error code to the ISABugger displays

	mov dh, al
	mov dl, ah
	mov al, 0x02 
	out 0x7A, al
	mov al, dl
	out 0x7B, al

	mov al, 0x04
	out 0x7A, al
	mov al, dh
	out 0x7B, al

	xchg bx, bx ; bochs breakpoint
	jmp $

align 2
palette_ram:
db 0
db 1
db 2
db 3
db 4
db 5
db 6
db 7
db 8
db 9
db 10
db 11
db 12
db 13
db 14
db 15

align 2
palette_data_plane_0:
db 0 ; palette RAM offset
%assign i 0 
%rep 16
 %if i & 0b0001
   %if i & 0b0100
   %assign val 0x2f
  %else 
   %assign val 0x3f
  %endif
 %else
  %if i & 0b0100
   %assign val 0x10
  %else 
   %assign val 0x0
  %endif
 %endif
 %if i & 0b1000
  %assign val ~val
 %endif
 db val
 %assign i i+1
%endrep

align 2
palette_data_plane_1:
db 16 ; palette RAM offset
%assign i 0 
%rep 16
 %if i & 0b0010
   %if i & 0b0100
   %assign val 0x2f
  %else 
   %assign val 0x3f
  %endif
 %else
  %if i & 0b0100
   %assign val 0x10
  %else 
   %assign val 0x0
  %endif
 %endif
 %if i & 0b1000
  %assign val ~val
 %endif
 db val
 %assign i i+1
%endrep
