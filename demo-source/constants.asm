LEFT_KANJI_START equ 55
LEFT_KANJI_HEIGHT equ 74

RIGHT_KANJI_START equ 32
RIGHT_KANJI_HEIGHT equ 117
RIGHT_KANJI_OFFSET equ 288

INITIAL_ANIM_DELAY equ 5

PLANE_0      equ 0b0001
PLANE_1      equ 0b0010
PLANE_SHADE  equ 0b0100
PLANE_NEGATE equ 0b1000

PIT_FREQ	equ	1000

SQ_INDEX	equ		3c4h
SQ_PLANEMASK	equ		2

GC_INDEX        equ     3ceh    ;GC index register
GC_ROTATE       equ     3       ;GC data rotate/logical function
                                ; register index
GC_MODE         equ     5       ;GC mode register index
GC_BITMASK      equ     8
INPUT_STATUS    equ		03dah

FLOPPY_CYLINDERS equ 80

SECTOR_SIZE equ (9*2*512)
FIRST_DATA_SECTOR equ 4

SCREEN_BASE equ 4

OPL_BASE equ 0x220
FIRST_MUSIC_CYLINDER equ 65

;FIRST_SECTOR_BUFFER equ 0x28000

MUSIC_SEG_1         equ 0x1000
MUSIC_SEG_2         equ 0x3000

CODE_START          equ 0x20000
FIRST_SECTOR_BUFFER equ 0x28000
SECOND_SECTOR_BUFFER equ (FIRST_SECTOR_BUFFER + SECTOR_SIZE)

%define SEG(addr) ((addr & 0xF0000) >> 4)
%define OFF(addr) (addr & 0xFFFF)