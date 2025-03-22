; kernel.asm
; x86-64 kernel for OS Shell
; This is the main kernel file that initializes the system and launches the shell

[BITS 64]
[GLOBAL _start]

section .text

; External functions
extern shell_init
extern console_init
extern memory_init
extern interrupt_init

; Kernel entry point
_start:
    ; Save multiboot information
    mov [multiboot_info], rbx
    
    ; Initialize console
    call console_init
    
    ; Display welcome message
    mov rsi, welcome_msg
    call print_string
    
    ; Initialize memory management
    call memory_init
    
    ; Initialize interrupt handling
    call interrupt_init
    
    ; Initialize the shell
    call shell_init
    
    ; If shell returns, halt the system
    cli
    hlt

; Function to print a null-terminated string
; Input: RSI = pointer to string
print_string:
    push rax
    push rbx
    push rcx
    push rdx
    
    mov rbx, 0xB8000      ; Video memory address
    mov ah, 0x0F          ; White text on black background
    
.loop:
    lodsb                 ; Load byte from [rsi] into al and increment rsi
    test al, al
    jz .done              ; If character is 0, we're done
    
    mov [rbx], ax         ; Store character and attribute
    add rbx, 2            ; Move to next character position
    jmp .loop
    
.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Function to clear the screen
; No input parameters
clear_screen:
    push rax
    push rcx
    push rdi
    
    mov rdi, 0xB8000      ; Video memory address
    mov rcx, 2000         ; 80x25 characters
    mov rax, 0x0720       ; Space character with attribute
    rep stosw             ; Repeat store word
    
    pop rdi
    pop rcx
    pop rax
    ret

; Kernel panic function - displays error message and halts
; Input: RSI = pointer to error message
kernel_panic:
    call clear_screen
    
    ; Set error color (white on red)
    mov rbx, 0xB8000
    mov ah, 0x4F
    
    ; Print "KERNEL PANIC: " prefix
    mov rsi, panic_prefix
    
.prefix_loop:
    lodsb
    test al, al
    jz .print_message
    
    mov [rbx], ax
    add rbx, 2
    jmp .prefix_loop
    
.print_message:
    ; Print the actual error message
    mov rsi, [rsp+8]      ; Get the error message pointer from stack
    mov ah, 0x4F          ; Keep the error color
    
.msg_loop:
    lodsb
    test al, al
    jz .halt
    
    mov [rbx], ax
    add rbx, 2
    jmp .msg_loop
    
.halt:
    ; Halt the system
    cli
    hlt

section .data
    welcome_msg db 'x86-64 OS Shell - Kernel Initialized', 0
    panic_prefix db 'KERNEL PANIC: ', 0
    multiboot_info dq 0   ; Pointer to multiboot information structure

section .bss
    ; Reserve space for kernel stack
    align 16
    kernel_stack_bottom:
    resb 16384            ; 16 KB stack
    kernel_stack_top:
