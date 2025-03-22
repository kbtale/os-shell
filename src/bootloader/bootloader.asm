; bootloader.asm
; x86-64 bootloader for OS Shell
; This bootloader follows the multiboot2 specification for compatibility with GRUB2

[BITS 32]           ; Multiboot starts in 32-bit protected mode

section .multiboot
align 8
; Multiboot2 header
mb_header_start:
    dd 0xE85250D6                ; Multiboot2 magic number
    dd 0                         ; Architecture: protected mode i386
    dd mb_header_end - mb_header_start ; Header length
    dd -(0xE85250D6 + 0 + (mb_header_end - mb_header_start)) ; Checksum
    
    ; Tags
    ; End tag
    dw 0    ; Type
    dw 0    ; Flags
    dd 8    ; Size
mb_header_end:

section .bss
align 16
stack_bottom:
    resb 16384 ; 16 KiB stack
stack_top:

section .text
global _start

; Entry point
_start:
    ; Set up stack
    mov esp, stack_top
    
    ; Reset EFLAGS
    push 0
    popf
    
    ; Save multiboot info pointer (in ebx)
    push ebx
    
    ; Check for multiboot2 compliance
    cmp eax, 0x36D76289
    jne .no_multiboot
    
    ; Check for CPUID support
    call check_cpuid
    test eax, eax
    jz .no_cpuid
    
    ; Check for long mode support
    call check_long_mode
    test eax, eax
    jz .no_long_mode
    
    ; Set up paging for long mode
    call setup_paging
    
    ; Load GDT for long mode
    lgdt [gdt64.pointer]
    
    ; Update selectors
    mov ax, gdt64.data
    mov ss, ax
    mov ds, ax
    mov es, ax
    
    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    
    ; Set the long mode bit in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    
    ; Enable paging (this activates long mode)
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    
    ; Jump to 64-bit code
    jmp gdt64.code:long_mode_start
    
.no_multiboot:
    ; Print error message
    mov esi, no_multiboot_msg
    call print_string
    jmp halt
    
.no_cpuid:
    ; Print error message
    mov esi, no_cpuid_msg
    call print_string
    jmp halt
    
.no_long_mode:
    ; Print error message
    mov esi, no_long_mode_msg
    call print_string
    jmp halt

; Function to check CPUID support
check_cpuid:
    ; Try to flip the ID bit in EFLAGS
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    
    ; Compare with original value
    xor eax, ecx
    jz .no_cpuid
    
    ; CPUID is supported
    mov eax, 1
    ret
    
.no_cpuid:
    ; CPUID not supported
    xor eax, eax
    ret

; Function to check long mode support
check_long_mode:
    ; Check if CPUID supports extended functions
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode
    
    ; Check for long mode
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode
    
    ; Long mode is supported
    mov eax, 1
    ret
    
.no_long_mode:
    ; Long mode not supported
    xor eax, eax
    ret

; Function to set up paging for long mode
setup_paging:
    ; Clear page tables
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd
    mov edi, cr3
    
    ; Set up page tables
    mov dword [edi], 0x2003      ; PML4T[0] -> PDPT
    add edi, 0x1000
    mov dword [edi], 0x3003      ; PDPT[0] -> PDT
    add edi, 0x1000
    mov dword [edi], 0x4003      ; PDT[0] -> PT
    add edi, 0x1000
    
    ; Identity map the first 2 MB
    mov ebx, 0x00000003
    mov ecx, 512
    
.set_entry:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8
    loop .set_entry
    
    ret

; Function to print a null-terminated string
; Input: ESI = pointer to string
print_string:
    push eax
    push ebx
    
    mov ah, 0x0E        ; BIOS teletype function
    mov bh, 0           ; Page number
    
.loop:
    lodsb               ; Load next character
    test al, al         ; Check for null terminator
    jz .done
    int 0x10            ; Call BIOS
    jmp .loop
    
.done:
    pop ebx
    pop eax
    ret

; Halt the system
halt:
    cli                 ; Disable interrupts
    hlt                 ; Halt the CPU
    jmp halt            ; Just in case

; 64-bit code
[BITS 64]
long_mode_start:
    ; Clear all segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Restore multiboot info pointer
    pop rdi
    
    ; Print welcome message
    mov rsi, welcome_msg
    call print_string_64
    
    ; Jump to kernel
    extern kernel_main
    call kernel_main
    
    ; If kernel returns, halt the system
    jmp halt64

; Function to print a null-terminated string in 64-bit mode
; Input: RSI = pointer to string
print_string_64:
    push rax
    push rdx
    
.loop:
    lodsb               ; Load next character
    test al, al         ; Check for null terminator
    jz .done
    
    ; Write to VGA text buffer
    mov ah, 0x0F        ; White on black
    mov [0xB8000 + rdx], ax
    add rdx, 2
    jmp .loop
    
.done:
    pop rdx
    pop rax
    ret

; Halt the system in 64-bit mode
halt64:
    cli                 ; Disable interrupts
    hlt                 ; Halt the CPU
    jmp halt64          ; Just in case

; GDT for long mode
section .rodata
gdt64:
    dq 0                                                ; Null descriptor
.code: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)   ; Code segment
.data: equ $ - gdt64
    dq (1 << 44) | (1 << 47) | (1 << 41)               ; Data segment
.pointer:
    dw $ - gdt64 - 1    ; Size
    dq gdt64            ; Address

; Messages
no_multiboot_msg db 'Error: Not booted with multiboot-compliant bootloader', 0
no_cpuid_msg db 'Error: CPUID not supported', 0
no_long_mode_msg db 'Error: Long mode not supported', 0
welcome_msg db 'Welcome to x86-64 OS Shell!', 0
