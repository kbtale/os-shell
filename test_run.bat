@echo off
echo Running Test OS in QEMU...

if not exist build\test_os.img (
    echo Error: Test OS image not found. Run test_build.bat first.
    exit /b 1
)

echo Starting QEMU...
"C:\Program Files\qemu\qemu-system-x86_64.exe" -drive format=raw,file=build\test_os.img -m 128M

echo QEMU session ended.
