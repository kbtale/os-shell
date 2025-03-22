# Makefile for x86-64 OS Shell

# Tools
NASM = tools/nasm/nasm-2.16.01/nasm.exe
LD = tools/mingw/mingw64/bin/ld.exe
OBJCOPY = tools/mingw/mingw64/bin/objcopy.exe
QEMU = qemu-system-x86_64

# Directories
SRC_DIR = src
BUILD_DIR = build
BOOTLOADER_DIR = $(SRC_DIR)/bootloader
KERNEL_DIR = $(SRC_DIR)/kernel
SHELL_DIR = $(SRC_DIR)/shell
LIB_DIR = $(SRC_DIR)/lib

# Flags
NASM_FLAGS = -f elf64
LD_FLAGS = -m elf_x86_64 -T linker.ld -nostdlib
QEMU_FLAGS = -drive format=raw,file=$(BUILD_DIR)/os.img -m 128M

# Files
BOOTLOADER_SRC = $(wildcard $(BOOTLOADER_DIR)/*.asm)
KERNEL_SRC = $(wildcard $(KERNEL_DIR)/*.asm)
SHELL_SRC = $(wildcard $(SHELL_DIR)/*.asm)
LIB_SRC = $(wildcard $(LIB_DIR)/*.asm)

BOOTLOADER_OBJ = $(patsubst $(BOOTLOADER_DIR)/%.asm, $(BUILD_DIR)/%.o, $(BOOTLOADER_SRC))
KERNEL_OBJ = $(patsubst $(KERNEL_DIR)/%.asm, $(BUILD_DIR)/%.o, $(KERNEL_SRC))
SHELL_OBJ = $(patsubst $(SHELL_DIR)/%.asm, $(BUILD_DIR)/%.o, $(SHELL_SRC))
LIB_OBJ = $(patsubst $(LIB_DIR)/%.asm, $(BUILD_DIR)/%.o, $(LIB_SRC))

# Targets
.PHONY: all clean run

all: $(BUILD_DIR)/os.img

$(BUILD_DIR)/os.img: $(BUILD_DIR)/bootloader.bin $(BUILD_DIR)/kernel.bin
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	copy /b $(BUILD_DIR)\bootloader.bin+$(BUILD_DIR)\kernel.bin $(BUILD_DIR)\os.img
	# Pad the image to be a multiple of 512 bytes (sector size)
	# Using PowerShell for this on Windows
	powershell -Command "$f=gi '$(BUILD_DIR)\os.img'; $$size=$$f.Length; $$padding=2880*512-$$size; if($$padding -gt 0){$$buffer=New-Object byte[] $$padding; $$fs=[System.IO.File]::OpenWrite('$(BUILD_DIR)\os.img'); $$fs.Seek($$size, 'Begin') | Out-Null; $$fs.Write($$buffer, 0, $$padding); $$fs.Close()}"

$(BUILD_DIR)/bootloader.bin: $(BOOTLOADER_OBJ)
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(LD) $(LD_FLAGS) -o $(BUILD_DIR)/bootloader.elf $(BOOTLOADER_OBJ)
	$(OBJCOPY) -O binary $(BUILD_DIR)/bootloader.elf $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/kernel.bin: $(KERNEL_OBJ) $(SHELL_OBJ) $(LIB_OBJ)
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(LD) $(LD_FLAGS) -o $(BUILD_DIR)/kernel.elf $(KERNEL_OBJ) $(SHELL_OBJ) $(LIB_OBJ)
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/%.o: $(BOOTLOADER_DIR)/%.asm
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) -o $@ $<

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.asm
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) -o $@ $<

$(BUILD_DIR)/%.o: $(SHELL_DIR)/%.asm
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) -o $@ $<

$(BUILD_DIR)/%.o: $(LIB_DIR)/%.asm
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) -o $@ $<

clean:
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)

run: $(BUILD_DIR)/os.img
	$(QEMU) $(QEMU_FLAGS)
