; kernel.asm
; Main kernel file for OS Shell

[BITS 64]

section .text
global kernel_main
extern console_init
extern memory_init
extern interrupt_init
extern shell_init

; Kernel entry point
kernel_main:
    ; Save multiboot info
    mov [multiboot_info], rdi
    
    ; Initialize console
    call console_init
    
    ; Print welcome message
    mov rsi, welcome_msg
    call print_string
    
    ; Initialize memory management
    call memory_init
    
    ; Initialize interrupt handling
    call interrupt_init
    
    ; Initialize shell
    call shell_init
    
    ; Main kernel loop
    jmp kernel_loop

; Main kernel loop
kernel_loop:
    ; Process any pending tasks
    call process_tasks
    
    ; Check for keyboard input
    call check_keyboard
    
    ; Yield to other processes
    hlt
    
    ; Repeat
    jmp kernel_loop

; Process pending tasks
process_tasks:
    ; Check if there are any tasks in the queue
    mov rax, [task_count]
    test rax, rax
    jz .no_tasks
    
    ; Process the first task
    mov rdi, [task_queue]
    call [rdi]
    
    ; Remove the task from the queue
    call dequeue_task
    
.no_tasks:
    ret

; Check for keyboard input
check_keyboard:
    ; Check if there is keyboard input available
    in al, 0x64
    test al, 1
    jz .no_input
    
    ; Read keyboard input
    in al, 0x60
    
    ; Pass to shell
    mov rdi, rax
    call handle_keyboard_input
    
.no_input:
    ret

; Print a null-terminated string
; Input: RSI = pointer to string
print_string:
    push rax
    push rcx
    push rdi
    
    ; Get current cursor position
    mov rdi, [cursor_pos]
    
.loop:
    lodsb               ; Load next character
    test al, al         ; Check for null terminator
    jz .done
    
    ; Handle special characters
    cmp al, 10          ; Newline
    je .newline
    cmp al, 13          ; Carriage return
    je .carriage_return
    
    ; Write character to video memory
    mov ah, 0x0F        ; White on black
    mov [rdi], ax
    add rdi, 2
    
    ; Update cursor position
    mov [cursor_pos], rdi
    
    jmp .loop
    
.newline:
    ; Move to next line
    add rdi, 160        ; 80 columns * 2 bytes per character
    and rdi, ~0x9F      ; Align to start of line (clear lower 7 bits)
    mov [cursor_pos], rdi
    jmp .loop
    
.carriage_return:
    ; Move to start of current line
    mov rax, rdi
    and rax, ~0x9F      ; Align to start of line (clear lower 7 bits)
    mov rdi, rax
    mov [cursor_pos], rdi
    jmp .loop
    
.done:
    ; Update hardware cursor
    call update_cursor
    
    pop rdi
    pop rcx
    pop rax
    ret

; Update hardware cursor position
update_cursor:
    push rax
    push rdx
    
    ; Calculate cursor position
    mov rax, [cursor_pos]
    sub rax, 0xB8000    ; Subtract video memory base
    shr rax, 1          ; Divide by 2 (bytes per character)
    
    ; Set low byte
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    
    mov dx, 0x3D5
    mov al, bl
    out dx, al
    
    ; Set high byte
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    
    mov dx, 0x3D5
    mov al, bh
    out dx, al
    
    pop rdx
    pop rax
    ret

; Add a task to the queue
; Input: RDI = task function pointer
enqueue_task:
    push rax
    push rcx
    push rsi
    push rdi
    
    ; Get current task count
    mov rcx, [task_count]
    
    ; Check if queue is full
    cmp rcx, MAX_TASKS
    jae .queue_full
    
    ; Calculate task index
    mov rax, rcx
    shl rax, 3          ; Multiply by 8 (bytes per pointer)
    
    ; Add task to queue
    mov rsi, task_queue
    add rsi, rax
    mov [rsi], rdi
    
    ; Increment task count
    inc qword [task_count]
    
.queue_full:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; Remove a task from the queue
dequeue_task:
    push rax
    push rcx
    push rsi
    push rdi
    
    ; Get current task count
    mov rcx, [task_count]
    
    ; Check if queue is empty
    test rcx, rcx
    jz .queue_empty
    
    ; Shift all tasks down
    mov rsi, task_queue + 8
    mov rdi, task_queue
    mov rcx, [task_count]
    dec rcx
    shl rcx, 3          ; Multiply by 8 (bytes per pointer)
    rep movsb
    
    ; Decrement task count
    dec qword [task_count]
    
.queue_empty:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; Handle keyboard input
; Input: RDI = keyboard scancode
handle_keyboard_input:
    ; Call shell keyboard handler
    extern shell_handle_key
    jmp shell_handle_key

section .data
welcome_msg db 'OS Shell - x86-64 Assembly Operating System', 13, 10
            db 'Version 0.1', 13, 10
            db 'Copyright (c) 2025', 13, 10, 13, 10, 0

; Constants
MAX_TASKS equ 64

section .bss
; Multiboot info pointer
multiboot_info: resq 1

; Cursor position
cursor_pos: resq 1

; Task queue
task_count: resq 1
task_queue: resq MAX_TASKS
