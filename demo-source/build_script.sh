dd if=/dev/zero of=bin/fat.img bs=1k count=720
mformat -i bin/fat.img -f 720 ::

nasm -f bin boot_badapple.asm -o bin/boot.bin

nasm -f elf32 badapple.asm -o bin/code.o
nasm -f elf32 floppy.asm -o bin/floppy.o
nasm -f elf32 decompress.asm -o bin/decompress.o
nasm -f elf32 border_art.asm -o bin/border_art.o
nasm -f elf32 font.asm -o bin/font.o

gcc -ffreestanding -nostdlib -m32 bin/code.o bin/floppy.o bin/decompress.o bin/border_art.o bin/font.o -o bin/code.bin -T link.ld

wc -c bin/code.bin | numfmt --to=iec

dd if=/dev/zero of=bin/fat.img bs=1k count=720
dd conv=notrunc if=bin/boot.bin of=bin/fat.img bs=1 skip=62 seek=62 count=450  # copy the bootsector
dd conv=notrunc if=bin/code.bin of=bin/fat.img bs=9216 seek=1 count=3 # copy the code data
dd conv=notrunc if=bin/out.bin of=bin/fat.img bs=9216 count=76 seek=4 # leaves around 36kB for code

dd if=/dev/zero of=bin/fat2.img bs=1k count=720
dd bs=9216 skip=76 count=80 if=bin/out.bin of=bin/fat2.img conv=notrunc
dd bs=9216 seek=65 count=15 if=bin/recording.dro of=bin/fat2.img conv=notrunc