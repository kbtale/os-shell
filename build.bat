@echo off
echo Building OS Shell...

REM Create build directory if it doesn't exist
if not exist build mkdir build

REM Compile bootloader
echo Compiling bootloader...
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\bootloader.o src\bootloader\bootloader.asm

REM Compile kernel components
echo Compiling kernel components...
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\kernel.o src\kernel\kernel.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\console.o src\kernel\console.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\memory.o src\kernel\memory.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\interrupt.o src\kernel\interrupt.asm

REM Compile shell
echo Compiling shell...
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\shell.o src\shell\shell.asm

REM Compile library modules
echo Compiling library modules...
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\drivers.o src\lib\drivers.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\filesystem.o src\lib\filesystem.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\process.o src\lib\process.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\sysinfo.o src\lib\sysinfo.asm
tools\nasm\nasm-2.16.01\nasm.exe -f win64 -o build\utils.o src\lib\utils.asm

REM Link bootloader
echo Linking bootloader...
tools\mingw\mingw64\bin\ld.exe -m i386pep -T linker.ld -nostdlib -o build\bootloader.exe build\bootloader.o
tools\mingw\mingw64\bin\objcopy.exe -O binary build\bootloader.exe build\bootloader.bin

REM Link kernel and other components
echo Linking kernel and components...
tools\mingw\mingw64\bin\ld.exe -m i386pep -T linker.ld -nostdlib -o build\kernel.exe build\kernel.o build\console.o build\memory.o build\interrupt.o build\shell.o build\drivers.o build\filesystem.o build\process.o build\sysinfo.o build\utils.o
tools\mingw\mingw64\bin\objcopy.exe -O binary build\kernel.exe build\kernel.bin

REM Create disk image
echo Creating disk image...
copy /b build\bootloader.bin+build\kernel.bin build\os.img

echo Build completed!
