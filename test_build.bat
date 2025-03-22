@echo off
echo Building Test OS Image...

REM Create build directory if it doesn't exist
if not exist build mkdir build

REM Compile simple bootloader
echo Compiling simple bootloader...
tools\nasm\nasm-2.16.01\nasm.exe -f bin -o build\simple_boot.bin src\test\simple_boot.asm

REM Create disk image
echo Creating test disk image...
if exist build\simple_boot.bin (
    copy /b build\simple_boot.bin build\test_os.img
    echo Test disk image created successfully.
) else (
    echo Error: simple_boot.bin not found.
)

echo Build completed!
