@echo off
echo Building OS Shell...

:: Set paths to tools
set NASM=nasm
set LD=ld
set OBJCOPY=objcopy
set QEMU=qemu-system-x86_64

:: Set build directories
set BUILD_DIR=build
set SRC_DIR=src
set OUTPUT_DIR=output

:: Create build directories if they don't exist
if not exist %BUILD_DIR% mkdir %BUILD_DIR%
if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

:: Compile bootloader
echo Compiling bootloader...
%NASM% -f elf64 %SRC_DIR%\bootloader\bootloader.asm -o %BUILD_DIR%\bootloader.o

:: Compile kernel
echo Compiling kernel...
%NASM% -f elf64 %SRC_DIR%\kernel\kernel.asm -o %BUILD_DIR%\kernel.o

:: Compile memory management
echo Compiling memory management...
%NASM% -f elf64 %SRC_DIR%\kernel\memory.asm -o %BUILD_DIR%\memory.o

:: Compile console
echo Compiling console...
%NASM% -f elf64 %SRC_DIR%\console\console.asm -o %BUILD_DIR%\console.o

:: Compile interrupt handling
echo Compiling interrupt handling...
%NASM% -f elf64 %SRC_DIR%\kernel\interrupt.asm -o %BUILD_DIR%\interrupt.o

:: Compile shell
echo Compiling shell...
%NASM% -f elf64 %SRC_DIR%\shell\shell.asm -o %BUILD_DIR%\shell.o

:: Compile process management
echo Compiling process management...
%NASM% -f elf64 %SRC_DIR%\lib\process.asm -o %BUILD_DIR%\process.o

:: Link everything together
echo Linking...
%LD% -T linker.ld -o %BUILD_DIR%\kernel.elf %BUILD_DIR%\bootloader.o %BUILD_DIR%\kernel.o %BUILD_DIR%\memory.o %BUILD_DIR%\console.o %BUILD_DIR%\interrupt.o %BUILD_DIR%\shell.o %BUILD_DIR%\process.o

:: Create bootable disk image
echo Creating bootable disk image...
%OBJCOPY% -O binary %BUILD_DIR%\kernel.elf %OUTPUT_DIR%\os-shell.bin

:: Create ISO image (if you have mkisofs or genisoimage)
:: echo Creating ISO image...
:: mkisofs -R -b os-shell.bin -no-emul-boot -boot-load-size 4 -o %OUTPUT_DIR%\os-shell.iso %OUTPUT_DIR%

echo Build completed!
echo.
echo To run the OS in QEMU, use: %QEMU% -kernel %OUTPUT_DIR%\os-shell.bin

:: Uncomment to automatically run after build
:: %QEMU% -kernel %OUTPUT_DIR%\os-shell.bin
