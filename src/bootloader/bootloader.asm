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

; Page tables for long mode
align 4096
pml4_table:
    resb 4096
pdpt_table:
    resb 4096
pd_table:
    resb 4096
pt_table:
    resb 4096

section .data
align 8
gdt64:
    dq 0                         ; Null descriptor
.code: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Code segment
.data: equ $ - gdt64
    dq (1 << 44) | (1 << 47)     ; Data segment
.pointer:
    dw $ - gdt64 - 1             ; Size
    dq gdt64                     ; Address

section .text
global _start
extern kernel_main

; Entry point
_start:
    ; Save multiboot info pointer
    mov edi, ebx
    
    ; Set up stack
    mov esp, stack_top
    
    ; Reset EFLAGS
    push 0
    popf
    
    ; Check for CPUID support
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
    xor eax, ecx
    jz no_cpuid
    
    ; Check for long mode support
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb no_long_mode
    
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz no_long_mode
    
    ; Set up page tables
    ; PML4
    mov eax, pdpt_table
    or eax, 0b11    ; Present, writable
    mov [pml4_table], eax
    
    ; PDPT
    mov eax, pd_table
    or eax, 0b11    ; Present, writable
    mov [pdpt_table], eax
    
    ; PD - identity map first 2MB
    mov eax, pt_table
    or eax, 0b11    ; Present, writable
    mov [pd_table], eax
    
    ; PT - map 512 pages (2MB)
    mov ecx, 0
.map_pt_loop:
    mov eax, 0x1000    ; 4KB page
    mul ecx
    or eax, 0b11       ; Present, writable
    mov [pt_table + ecx * 8], eax
    
    inc ecx
    cmp ecx, 512
    jne .map_pt_loop
    
    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    
    ; Set the long mode bit in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    
    ; Load PML4 address to CR3
    mov eax, pml4_table
    mov cr3, eax
    
    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    
    ; Load GDT
    lgdt [gdt64.pointer]
    
    ; Jump to long mode
    jmp gdt64.code:long_mode_start

; Error handlers
no_cpuid:
    mov al, "1"
    jmp error

no_long_mode:
    mov al, "2"
    jmp error

error:
    ; Print "ERR: X" where X is the error code
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8004], 0x4f3a4f52
    mov dword [0xb8008], 0x4f204f20
    mov byte  [0xb800a], al
    hlt

[BITS 64]
long_mode_start:
    ; Set up segment registers
    mov ax, gdt64.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Clear screen
    mov rax, 0x0F200F200F200F20  ; White on black spaces
    mov rdi, 0xb8000
    mov rcx, 500                 ; 4000 bytes / 8 bytes per quad word = 500 quad words
    rep stosq
    
    ; Print welcome message
    mov rdi, 0xb8000
    mov rsi, welcome_msg
    call print_string
    
    ; Call kernel main
    call kernel_main
    
    ; If kernel returns, halt
    cli
    hlt

; Function to print a null-terminated string
; rdi = screen address, rsi = string address
print_string:
    push rax
    push rcx
    push rsi
    push rdi
    
    mov ah, 0x0F    ; White on black
.loop:
    lodsb           ; Load next character
    test al, al     ; Check for null terminator
    jz .done
    
    mov [rdi], ax   ; Store character and attribute
    add rdi, 2      ; Move to next character position
    
    jmp .loop
    
.done:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

section .rodata
welcome_msg db "OS Shell - 64-bit mode initialized", 0
