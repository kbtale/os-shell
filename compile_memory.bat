@echo off
echo Compiling memory.asm...
tools\nasm\nasm-2.16.01\nasm.exe -f elf64 -o build\memory.o src\kernel\memory.asm
echo Done!
