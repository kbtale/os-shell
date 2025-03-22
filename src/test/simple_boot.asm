; simple_boot.asm
; A simplified bootloader for testing

[BITS 16]           ; Start in 16-bit real mode
[ORG 0x7C00]        ; BIOS loads bootloader at 0x7C00

; Initialize segment registers
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7C00      ; Set up stack

; Clear screen
mov ah, 0x00        ; Set video mode
mov al, 0x03        ; 80x25 text mode
int 0x10            ; Call BIOS interrupt

; Print welcome message
mov si, welcome_msg
call print_string

; Main command loop
command_loop:
    ; Print prompt
    mov si, prompt
    call print_string
    
    ; Get command
    mov di, command_buffer
    call read_string
    
    ; Process command
    mov si, command_buffer
    
    ; Compare with "help" command
    mov di, help_cmd
    call strcmp
    jc help_command
    
    ; Compare with "clear" command
    mov di, clear_cmd
    call strcmp
    jc clear_command
    
    ; Compare with "about" command
    mov di, about_cmd
    call strcmp
    jc about_command
    
    ; Unknown command
    mov si, unknown_cmd_msg
    call print_string
    jmp command_loop

; Command handlers
help_command:
    mov si, help_msg
    call print_string
    jmp command_loop
    
clear_command:
    mov ah, 0x00    ; Set video mode
    mov al, 0x03    ; 80x25 text mode
    int 0x10        ; Call BIOS interrupt
    jmp command_loop
    
about_command:
    mov si, about_msg
    call print_string
    jmp command_loop

; Function to compare strings (SI and DI)
; Returns carry flag set if equal
strcmp:
    push si
    push di
.loop:
    lodsb           ; Load byte at SI into AL and increment SI
    mov ah, [di]    ; Load byte at DI into AH
    inc di          ; Increment DI
    
    cmp al, ah      ; Compare AL and AH
    jne .not_equal  ; Jump if not equal
    
    test al, al     ; Check if AL is 0 (end of string)
    jz .equal       ; Jump if zero (strings are equal)
    
    jmp .loop       ; Continue loop
    
.not_equal:
    clc             ; Clear carry flag (not equal)
    jmp .done
    
.equal:
    stc             ; Set carry flag (equal)
    
.done:
    pop di
    pop si
    ret

; Function to read a string from keyboard
read_string:
    xor cx, cx      ; Clear CX (character count)
.loop:
    mov ah, 0x00    ; BIOS read key function
    int 0x16        ; Call BIOS interrupt
    
    cmp al, 0x0D    ; Check for Enter key
    je .done
    
    cmp al, 0x08    ; Check for Backspace key
    je .backspace
    
    cmp cx, 20      ; Check if buffer is full (reduced buffer size)
    je .loop        ; Ignore input if buffer is full
    
    stosb           ; Store AL at DI and increment DI
    inc cx          ; Increment character count
    
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10        ; Call BIOS interrupt
    
    jmp .loop
    
.backspace:
    test cx, cx     ; Check if buffer is empty
    jz .loop        ; Ignore backspace if buffer is empty
    
    dec di          ; Decrement DI
    dec cx          ; Decrement character count
    
    mov ah, 0x0E    ; BIOS teletype function
    mov al, 0x08    ; Backspace character
    int 0x10        ; Call BIOS interrupt
    
    mov al, ' '     ; Space character
    int 0x10        ; Call BIOS interrupt
    
    mov al, 0x08    ; Backspace character
    int 0x10        ; Call BIOS interrupt
    
    jmp .loop
    
.done:
    mov al, 0       ; Null-terminate the string
    stosb
    
    mov ah, 0x0E    ; BIOS teletype function
    mov al, 0x0D    ; Carriage return
    int 0x10        ; Call BIOS interrupt
    
    mov al, 0x0A    ; Line feed
    int 0x10        ; Call BIOS interrupt
    
    ret

; Function to print a null-terminated string
print_string:
    lodsb           ; Load byte at SI into AL and increment SI
    test al, al     ; Check if AL is 0 (end of string)
    jz .done
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10        ; Call BIOS interrupt
    jmp print_string
.done:
    ret

; Data
welcome_msg db 'OS Shell', 13, 10, 'Type help', 13, 10, 0
prompt db '> ', 0
help_cmd db 'help', 0
clear_cmd db 'clear', 0
about_cmd db 'about', 0
help_msg db 'Commands:', 13, 10, 'help, clear, about', 13, 10, 0
about_msg db 'OS Shell v0.1', 13, 10, 0
unknown_cmd_msg db 'Unknown command', 13, 10, 0

; Buffer for user input
command_buffer times 32 db 0

; Padding and boot signature
times 510-($-$$) db 0   ; Fill with zeros up to 510 bytes
dw 0xAA55               ; Boot signature at the end of the sector
