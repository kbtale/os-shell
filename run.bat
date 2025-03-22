@echo off
echo Running OS Shell in QEMU...

:: Set paths
set QEMU="C:\Program Files\qemu\qemu-system-x86_64.exe"
set OUTPUT_DIR=build

:: Check if OS image exists
if not exist %OUTPUT_DIR%\os.img (
    echo Error: OS image not found. Run build.bat first.
    exit /b 1
)

echo Starting QEMU...
%QEMU% -kernel %OUTPUT_DIR%\os.img -m 128M

echo QEMU session ended.
