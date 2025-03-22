; interrupt.asm
; Interrupt handling for the x86-64 OS Shell
; Sets up the Interrupt Descriptor Table (IDT) and handles interrupts

[BITS 64]
[GLOBAL interrupt_init]
[GLOBAL interrupt_enable]
[GLOBAL interrupt_disable]

section .text

; Initialize interrupt handling
; No input parameters
interrupt_init:
    push rbp
    mov rbp, rsp
    
    ; Set up the IDT
    call setup_idt
    
    ; Load the IDT
    lidt [idtr]
    
    ; Initialize the Programmable Interrupt Controller (PIC)
    call init_pic
    
    ; Enable interrupts
    call interrupt_enable
    
    pop rbp
    ret

; Enable interrupts
; No input parameters
interrupt_enable:
    sti
    ret

; Disable interrupts
; No input parameters
interrupt_disable:
    cli
    ret

; Set up the Interrupt Descriptor Table
; No input parameters
setup_idt:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Clear the IDT
    mov rdi, idt
    mov rcx, 256 * 16       ; 256 entries, 16 bytes each
    xor rax, rax
    rep stosb
    
    ; Set up exception handlers (0-31)
    mov rcx, 32
    mov rbx, 0
    
.setup_exception:
    mov rax, exception_handler
    mov rdx, 0x8E00         ; Present, Ring 0, Interrupt Gate
    call set_idt_entry
    inc rbx
    loop .setup_exception
    
    ; Set up hardware interrupt handlers (32-47)
    mov rcx, 16
    mov rbx, 32
    
.setup_irq:
    mov rax, irq_handler
    mov rdx, 0x8E00         ; Present, Ring 0, Interrupt Gate
    call set_idt_entry
    inc rbx
    loop .setup_irq
    
    ; Set up system call handler (int 0x80)
    mov rbx, 0x80
    mov rax, syscall_handler
    mov rdx, 0xEE00         ; Present, Ring 3, Interrupt Gate
    call set_idt_entry
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret

; Set an IDT entry
; Input: RBX = interrupt number, RAX = handler address, RDX = flags
set_idt_entry:
    push rbp
    mov rbp, rsp
    push rdi
    
    ; Calculate the address of the IDT entry
    mov rdi, idt
    imul rdi, rbx, 16       ; Each entry is 16 bytes
    add rdi, idt
    
    ; Set up the entry
    mov word [rdi], ax      ; Low 16 bits of handler address
    shr rax, 16
    mov word [rdi+6], ax    ; Middle 16 bits of handler address
    shr rax, 16
    mov dword [rdi+8], eax  ; High 32 bits of handler address
    
    mov word [rdi+2], 0x08  ; Segment selector (code segment)
    mov word [rdi+4], dx    ; Flags
    mov word [rdi+12], 0    ; Reserved
    
    pop rdi
    pop rbp
    ret

; Initialize the Programmable Interrupt Controller (PIC)
; No input parameters
init_pic:
    push rbp
    mov rbp, rsp
    push rax
    
    ; ICW1: Initialize and require ICW4
    mov al, 0x11
    out 0x20, al        ; Master PIC
    out 0xA0, al        ; Slave PIC
    
    ; ICW2: Remap IRQs to interrupts 32-47
    mov al, 32
    out 0x21, al        ; Master PIC starts at int 32
    mov al, 40
    out 0xA1, al        ; Slave PIC starts at int 40
    
    ; ICW3: Tell PICs about each other
    mov al, 4           ; Bit 2 = IRQ2 connects to slave
    out 0x21, al
    mov al, 2           ; Slave ID = 2
    out 0xA1, al
    
    ; ICW4: Set 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    
    ; Mask all interrupts except keyboard (IRQ1) and timer (IRQ0)
    mov al, 0xFC        ; 1111 1100 - only IRQ0 and IRQ1 enabled
    out 0x21, al
    mov al, 0xFF        ; 1111 1111 - all slave IRQs disabled
    out 0xA1, al
    
    pop rax
    pop rbp
    ret

; Exception handler (for interrupts 0-31)
; This is a common handler that will dispatch to specific handlers
exception_handler:
    ; Save all registers
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; Get the exception number from the stack
    mov rdi, [rsp + 15*8]   ; Exception number is stored in the interrupt frame
    
    ; Call the appropriate handler based on exception number
    ; For now, we'll just print a generic message
    mov rsi, exception_msg
    call console_write_string
    
    ; Convert exception number to ASCII and print it
    add rdi, '0'
    call console_write_char
    
    ; Newline
    mov rdi, 10
    call console_write_char
    
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    
    ; Return from interrupt
    iretq

; IRQ handler (for interrupts 32-47)
; This is a common handler that will dispatch to specific handlers
irq_handler:
    ; Save all registers
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; Get the IRQ number from the stack
    mov rdi, [rsp + 15*8]   ; IRQ number is stored in the interrupt frame
    sub rdi, 32             ; Convert interrupt number to IRQ number
    
    ; Handle specific IRQs
    cmp rdi, 0
    je .timer_irq
    cmp rdi, 1
    je .keyboard_irq
    jmp .other_irq
    
.timer_irq:
    ; Handle timer interrupt
    ; For now, just acknowledge it
    jmp .done
    
.keyboard_irq:
    ; Handle keyboard interrupt
    ; Read the scan code
    in al, 0x60
    
    ; Process the scan code (simplified)
    movzx rdi, al
    call keyboard_handler
    
    jmp .done
    
.other_irq:
    ; Handle other IRQs
    ; For now, just acknowledge them
    
.done:
    ; Send EOI (End of Interrupt) to PIC
    mov al, 0x20
    out 0x20, al        ; Always send to master PIC
    
    cmp rdi, 8
    jl .skip_slave_eoi
    out 0xA0, al        ; Send to slave PIC if IRQ >= 8
    
.skip_slave_eoi:
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    
    ; Return from interrupt
    iretq

; System call handler (int 0x80)
syscall_handler:
    ; Save registers
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; RAX contains the system call number
    ; RDI, RSI, RDX, R10, R8, R9 contain the arguments
    
    ; Dispatch to the appropriate system call handler
    cmp rax, MAX_SYSCALL
    jae .invalid_syscall
    
    ; Call the handler
    call [syscall_table + rax * 8]
    jmp .done
    
.invalid_syscall:
    ; Handle invalid system call
    mov rax, -1
    
.done:
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    
    ; Return from interrupt
    iretq

; Keyboard handler
; Input: RDI = scan code
keyboard_handler:
    push rbp
    mov rbp, rsp
    
    ; Process the scan code
    ; For now, just echo the key to the console if it's a printable character
    cmp rdi, 0x80
    jae .done           ; Ignore key releases (scan codes >= 0x80)
    
    ; Convert scan code to ASCII (simplified)
    ; In a real implementation, this would be more complex
    ; and handle shift, caps lock, etc.
    mov rax, rdi
    cmp rax, 0x39       ; Space bar
    ja .done
    
    ; Look up ASCII value in the keyboard map
    mov al, [keyboard_map + rax]
    test al, al
    jz .done            ; Ignore if 0 (non-printable)
    
    ; Echo the character to the console
    movzx rdi, al
    call console_write_char
    
.done:
    pop rbp
    ret

section .data
    ; IDT descriptor
    idtr:
        dw 256 * 16 - 1    ; Limit (size of IDT - 1)
        dq idt             ; Base address of IDT
    
    ; Messages
    exception_msg db 'Exception occurred: ', 0
    
    ; Keyboard map (scan code to ASCII, simplified)
    keyboard_map db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0
                 db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0
                 db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
                 db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
    
    ; System call table
    MAX_SYSCALL equ 10
    syscall_table:
        dq sys_exit         ; 0 - exit
        dq sys_read         ; 1 - read
        dq sys_write        ; 2 - write
        dq sys_open         ; 3 - open
        dq sys_close        ; 4 - close
        dq sys_stat         ; 5 - stat
        dq sys_exec         ; 6 - exec
        dq sys_fork         ; 7 - fork
        dq sys_getpid       ; 8 - getpid
        dq sys_sleep        ; 9 - sleep

section .bss
    ; Interrupt Descriptor Table (256 entries, 16 bytes each)
    idt resb 256 * 16

; External functions
extern console_write_string
extern console_write_char

; System call handlers (stubs for now)
sys_exit:
sys_read:
sys_write:
sys_open:
sys_close:
sys_stat:
sys_exec:
sys_fork:
sys_getpid:
sys_sleep:
    ret
