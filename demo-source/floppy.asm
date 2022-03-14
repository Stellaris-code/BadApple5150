BITS 16
CPU 8086

;enum floppy_registers {
;   FLOPPY_DOR  = 2,  // digital output register
;   FLOPPY_MSR  = 4,  // master status register, read only
;   FLOPPY_FIFO = 5,  // data FIFO, in DMA operation for commands
;   FLOPPY_CCR  = 7   // configuration control register, write only
;};

;// The commands of interest. There are more, but we only use these here.
;enum floppy_commands {
;   CMD_SPECIFY = 3,            // SPECIFY
;   CMD_WRITE_DATA = 5,         // WRITE DATA
;   CMD_READ_DATA = 6,          // READ DATA
;   CMD_RECALIBRATE = 7,        // RECALIBRATE
;   CMD_SENSE_INTERRUPT = 8,    // SENSE INTERRUPT
;   CMD_SEEK = 15,              // SEEK
;};

FLOPPY_BASE	equ	0x03F0
FLOPPY_DOR	equ	2
FLOPPY_MSR	equ	4
FLOPPY_FIFO	equ	5
FLOPPY_CCR	equ 7

CMD_SPECIFY	equ	3
CMD_WRITE_DATA	equ	5
CMD_READ_DAT	equ	6
CMD_RECALIBRATE	equ	7
CMD_SENSE_INT	equ	8
CMD_SEEK	equ	15

DMA_READ	equ	0x46
DMA_WRITE	equ	0x4a

global floppy_disk_init
global floppy_seek
global floppy_read_request
global floppy_read_collect
global floppy_select


extern frame_accumulator
extern wait_next_frame
extern err

selected_drive:
db 0

floppy_irq_status:
db 0

floppy_irq_handler:
	cs mov byte [floppy_irq_status], 1
	; let the PIC know we've handled the interrupt
	push ax
	mov al,0x20
	out 0x20,al
	pop ax
	iret

; command in al
; trashes dx, cx, ah
floppy_write_cmd:
	mov dx, FLOPPY_BASE + FLOPPY_MSR
	mov ah, al 
	mov cx, 65535
.lp:
	in al, dx
	and al, 0xc0
	cmp al, 0x80
	in al, 0x80 ; delay
	je .out
	loop .lp
.err:	
	mov ah, 0xF0
	call err
.out:
	mov dx, FLOPPY_BASE + FLOPPY_FIFO
	mov al, ah 
	out dx, al 
	ret

; result in al
; trashes dx, cx
floppy_read_fifo:
	mov dx, FLOPPY_BASE + FLOPPY_MSR
	mov cx, 65535
.lp:
	in al, dx
	and al, 0xc0
	cmp al, 0xc0
	in al, 0x80 ; delay
	je .out
	loop .lp
.err:	
	mov ah, 0xF1
	call err
.out:
	mov dx, FLOPPY_BASE + FLOPPY_FIFO
	in al, dx 
	ret

; returns st0 in ah, cy1 in al
floppy_check_interrupt:
	mov al, CMD_SENSE_INT
	call floppy_write_cmd
	call floppy_read_fifo
	mov ah, al
	jmp floppy_read_fifo ; tail call

; thrases bx
%macro floppy_wait_interrupt 0
%%wait_interrupt_lp:
	;hlt
	cs cmp byte [floppy_irq_status], 1
	jb %%wait_interrupt_lp
%endmacro

; thrases bx
floppy_motor_on:
	mov dx, FLOPPY_BASE + FLOPPY_DOR
	mov al, 0x3C ; motor 1 on, motor 1 on, disk 0 enabled
	out dx, al

	; wait 500ms (~8 frames)
	mov bx, frame_accumulator
	mov byte [bx], 0
.lp:
	hlt
	cmp byte [bx], 140
	jb .lp

	mov byte [bx], 0 ; reset the wait flag to zero
	ret


floppy_disk_reset:
	mov byte [floppy_irq_status], 0

	mov dx, FLOPPY_BASE + FLOPPY_DOR
	xor al, al 
	out dx, al ; all clear

	mov al, 0x08 ; enable IRQs and DMA
	out dx, al 

%rep 4
	in al, 0x80 ; delay
%endrep

	mov al, 0x0C ; IRQ, DMA, reset off
	out dx, al


	floppy_wait_interrupt
	; 4 SENSE INTERRUPT commands to clear the interrupt status of the four drives
	call floppy_check_interrupt
	call floppy_check_interrupt
	call floppy_check_interrupt
	call floppy_check_interrupt

	mov dx, FLOPPY_BASE + FLOPPY_CCR
	mov al, 0x02 ; 250 kbits/s 
	out dx, al

	mov al, CMD_SPECIFY
	call floppy_write_cmd
	mov al, 0xDF
	call floppy_write_cmd ; steprate and stuff
	mov al, 0x02
	call floppy_write_cmd ; load time = 16ms, no-DMA = 0

	call floppy_motor_on
	mov al, 1
	call floppy_select
	call floppy_calibrate
	mov al, 0
	call floppy_select
	call floppy_calibrate
	ret

floppy_disk_init:
	cli
	; set the floppy handler up
	push ds
	xor ax, ax
	mov ds, ax
	mov word [0x0038], floppy_irq_handler
	mov word [0x003A], cs
	pop ds
	sti


	call floppy_disk_reset
	ret


floppy_calibrate:    
	; cx = retries
	mov cx, 10

.lp:
	mov byte [floppy_irq_status], 0

	mov bp, cx
	mov al, CMD_RECALIBRATE
	call floppy_write_cmd
	mov al, 0 ; drive 0
	call floppy_write_cmd

	floppy_wait_interrupt

	call floppy_check_interrupt

	test ah, 0xC0
	jnz .error

	mov cx, bp
	test al, al

	loopnz .lp
	mov ah, al
	jnz .error
	ret
.error:
	or ah, 0x08
	call err

; cylinder in bl, (head<<2) in bh
floppy_seek:
	mov cx, 10

.lp:
	cs mov byte [floppy_irq_status], 0

	mov bp, cx
	mov al, CMD_SEEK
	call floppy_write_cmd
	mov al, bh
	call floppy_write_cmd
	mov al, bl
	call floppy_write_cmd

	floppy_wait_interrupt
	call floppy_check_interrupt

	test ah, 0xC0
	jnz .error

	mov cx, bp
	cmp al, bl

	loopne .lp
	mov ah, 0x1f
	jne .error
	ret
.error:
	or ah, 0x10
	call err

; bx = address shifted right by 8 bits
; dl = mode
; cx = count
floppy_dma_init:
	;mov al, 0xff
	;out 0x0d, al ; reset

	mov al, 0x06 
	out 0x0a, al ; mask chan 2
	mov al, 0xFF
	out 0x0c, al ; reset flip-flop
	xor al, al
	out 0x04, al ; low byte, 0 as we're using 256-byte aligned addresses
	mov al, bl
	out 0x04, al ; high byte
	mov al, bh
	out 0x81, al ; "high" high byte
	mov al, 0xFF
	out 0x0c, al ; reset flip-flop

	mov al, cl 
	out 0x05, al ; count low byte
	mov al, ch 
	out 0x05, al ; count high byte

	mov al, dl ; mode
	out 0x0b, al
	mov al, 0x02
	out 0x0a, al ; unmask chan 2

	;mov al, 0x10
	;out 0x08, al

	ret

; si : cylinder
; cx : byte count
; bx : target address << 8
floppy_read_request:
	mov dl, DMA_READ
	call floppy_dma_init

	mov bx, si

	cs mov byte [floppy_irq_status], 0

	mov al, 0xE6 ; skip deleted, Read, multitrack
	call floppy_write_cmd
	cs mov al, [selected_drive] ; 0:0:0:0:0:HD:US1:US0 = head and drive
	call floppy_write_cmd
	mov al, bl ; cylinder
	call floppy_write_cmd
	mov al, 0 ; first head
	call floppy_write_cmd
	mov al, 1 ; sector 1
	call floppy_write_cmd
	mov al, 2 ; bytes/sector : 128*(2^2)
	call floppy_write_cmd
	mov al, 9 ; one track
	call floppy_write_cmd
	mov al, 0x2A
	call floppy_write_cmd ; GAP3 length for 5"1/4 diskettes
	mov al, 0xFF ; data length (0xff if B/S != 0)
	call floppy_write_cmd
	ret

floppy_read_collect:
	floppy_wait_interrupt

	call floppy_read_fifo
	mov bl, al ; bl = st0
	call floppy_read_fifo
	mov bh, al ; bh = st1
	call floppy_read_fifo
	mov ah, al ; ah = st2

	; bunch of data we can ignore
	call floppy_read_fifo ; rcy
	call floppy_read_fifo ; rhe
	call floppy_read_fifo ; rse
	call floppy_read_fifo ; bps

	test bl, 0xC0

	jnz .error ; status tells us there has been an error
	ret

.error:
	mov al, ah
	mov ah, bh
	;or ah, 0x80
	call err


; disk number in al
floppy_select:
	cs mov [selected_drive], al

	mov dx, FLOPPY_BASE + FLOPPY_DOR
	or al, 0x3C ; motor 0 on, motor 1 on, IRQ on, enabled
	out dx, al
	%rep 4
	in al, 0x80 ; delay
	%endrep
	ret