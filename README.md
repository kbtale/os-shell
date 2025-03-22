# OS Shell

A simple x86-64 assembly operating system.

## Features
- Multiboot2 bootloader
- 64-bit kernel
- Memory management
- File operations
- Process management
- Command interface

## Build & Run

```bash
# Build
make all       # Linux/macOS
.\build.bat    # Windows

# Run
make run                                           # Linux/macOS
qemu-system-x86_64 -drive format=raw,file=build/os.img -m 128M  # Windows
```

## License
MIT
