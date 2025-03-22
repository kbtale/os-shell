; console.asm
; Console handling routines for the x86-64 OS Shell
; Provides functions for screen output, cursor management, and input handling

[BITS 64]
[GLOBAL console_init]
[GLOBAL console_clear]
[GLOBAL console_write_char]
[GLOBAL console_write_string]
[GLOBAL console_write_line]
[GLOBAL console_read_char]
[GLOBAL console_read_line]
[GLOBAL console_set_cursor]
[GLOBAL console_get_cursor]

section .text

; Constants
VIDEO_MEMORY    equ 0xB8000
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
DEFAULT_ATTRIB  equ 0x0F       ; White text on black background

; Initialize the console
; No input parameters
console_init:
    push rbp
    mov rbp, rsp
    
    ; Clear the screen
    call console_clear
    
    ; Set cursor to top-left
    mov rdi, 0
    mov rsi, 0
    call console_set_cursor
    
    ; Initialize console variables
    mov qword [console_row], 0
    mov qword [console_col], 0
    mov byte [console_color], DEFAULT_ATTRIB
    
    pop rbp
    ret

; Clear the console screen
; No input parameters
console_clear:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdi
    
    ; Fill screen with spaces using default attribute
    mov rdi, VIDEO_MEMORY
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov ax, 0x0720       ; Space character with default attribute
    rep stosw
    
    ; Reset cursor position
    mov qword [console_row], 0
    mov qword [console_col], 0
    
    pop rdi
    pop rcx
    pop rax
    pop rbp
    ret

; Write a character to the console at current position
; Input: RDI = character to write
console_write_char:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rdx
    
    ; Check for special characters
    cmp dil, 10          ; Newline
    je .newline
    cmp dil, 13          ; Carriage return
    je .carriage_return
    cmp dil, 8           ; Backspace
    je .backspace
    cmp dil, 9           ; Tab
    je .tab
    
    ; Regular character - calculate position in video memory
    mov rax, [console_row]
    mov rdx, SCREEN_WIDTH
    mul rdx
    add rax, [console_col]
    shl rax, 1           ; Multiply by 2 (each character is 2 bytes)
    add rax, VIDEO_MEMORY
    
    ; Write character with attribute
    mov bl, [console_color]
    mov byte [rax], dil  ; Character
    mov byte [rax+1], bl ; Attribute
    
    ; Increment column
    inc qword [console_col]
    
    ; Check if we need to wrap to next line
    cmp qword [console_col], SCREEN_WIDTH
    jl .done
    
    ; Wrap to next line
    mov qword [console_col], 0
    inc qword [console_row]
    
    ; Check if we need to scroll
    call .check_scroll
    jmp .done
    
.newline:
    ; Move to the beginning of the next line
    mov qword [console_col], 0
    inc qword [console_row]
    call .check_scroll
    jmp .done
    
.carriage_return:
    ; Move to the beginning of the current line
    mov qword [console_col], 0
    jmp .done
    
.backspace:
    ; Move back one character if not at the beginning of the line
    cmp qword [console_col], 0
    je .done
    dec qword [console_col]
    
    ; Clear the character
    mov rax, [console_row]
    mov rdx, SCREEN_WIDTH
    mul rdx
    add rax, [console_col]
    shl rax, 1
    add rax, VIDEO_MEMORY
    
    mov byte [rax], ' '   ; Space character
    mov bl, [console_color]
    mov byte [rax+1], bl  ; Attribute
    jmp .done
    
.tab:
    ; Move to the next tab stop (every 8 columns)
    mov rax, [console_col]
    add rax, 8
    and rax, ~7          ; Round down to multiple of 8
    mov [console_col], rax
    
    ; Check if we need to wrap
    cmp qword [console_col], SCREEN_WIDTH
    jl .done
    
    ; Wrap to next line
    mov qword [console_col], 0
    inc qword [console_row]
    call .check_scroll
    jmp .done
    
.check_scroll:
    ; Check if we need to scroll the screen
    cmp qword [console_row], SCREEN_HEIGHT
    jl .no_scroll
    
    ; Scroll the screen up one line
    push rdi
    push rsi
    push rcx
    
    ; Copy each line up one position
    mov rdi, VIDEO_MEMORY
    mov rsi, VIDEO_MEMORY + (SCREEN_WIDTH * 2)
    mov rcx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH
    rep movsw
    
    ; Clear the last line
    mov rcx, SCREEN_WIDTH
    mov ax, 0x0720       ; Space with default attribute
    rep stosw
    
    ; Adjust cursor position
    dec qword [console_row]
    
    pop rcx
    pop rsi
    pop rdi
    
.no_scroll:
    ret
    
.done:
    ; Update hardware cursor
    mov rdi, [console_col]
    mov rsi, [console_row]
    call console_set_cursor
    
    pop rdx
    pop rbx
    pop rax
    pop rbp
    ret

; Write a null-terminated string to the console
; Input: RDI = pointer to string
console_write_string:
    push rbp
    mov rbp, rsp
    push rsi
    push rax
    
    mov rsi, rdi        ; Move string pointer to RSI for lodsb
    
.loop:
    lodsb               ; Load byte from [rsi] into al and increment rsi
    test al, al
    jz .done            ; If character is 0, we're done
    
    mov rdi, rax        ; Move character to RDI for console_write_char
    call console_write_char
    jmp .loop
    
.done:
    pop rax
    pop rsi
    pop rbp
    ret

; Write a string followed by a newline
; Input: RDI = pointer to string
console_write_line:
    push rbp
    mov rbp, rsp
    
    ; Write the string
    call console_write_string
    
    ; Write newline
    mov rdi, 10
    call console_write_char
    
    pop rbp
    ret

; Read a character from keyboard
; Output: RAX = character read
console_read_char:
    push rbp
    mov rbp, rsp
    
    ; Wait for a key press
.wait_key:
    in al, 0x64         ; Read keyboard status port
    test al, 1          ; Check if data is available
    jz .wait_key        ; If not, keep waiting
    
    ; Read the key
    in al, 0x60         ; Read keyboard data port
    
    ; Convert scan code to ASCII (simplified)
    ; In a real implementation, this would be more complex
    ; and handle shift, caps lock, etc.
    movzx rax, al
    
    pop rbp
    ret

; Read a line of text from keyboard
; Input: RDI = buffer to store line, RSI = buffer size
; Output: RAX = number of characters read
console_read_line:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    mov rbx, rdi        ; Buffer pointer
    mov rcx, 0          ; Character count
    mov rdx, rsi        ; Buffer size
    
.read_loop:
    ; Read a character
    call console_read_char
    
    ; Check for special characters
    cmp al, 13          ; Enter key
    je .done
    cmp al, 8           ; Backspace
    je .backspace
    
    ; Regular character - check if buffer has space
    cmp rcx, rdx
    jge .read_loop      ; If buffer is full, ignore character
    
    ; Store character in buffer
    mov [rbx + rcx], al
    inc rcx
    
    ; Echo character to screen
    movzx rdi, al
    call console_write_char
    jmp .read_loop
    
.backspace:
    ; Handle backspace - if we have characters to delete
    test rcx, rcx
    jz .read_loop       ; If at start of line, ignore
    
    ; Delete last character from buffer
    dec rcx
    
    ; Echo backspace to screen
    mov rdi, 8
    call console_write_char
    jmp .read_loop
    
.done:
    ; Add null terminator
    mov byte [rbx + rcx], 0
    
    ; Echo newline
    mov rdi, 10
    call console_write_char
    
    ; Return number of characters read
    mov rax, rcx
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Set cursor position
; Input: RDI = column, RSI = row
console_set_cursor:
    push rbp
    mov rbp, rsp
    push rax
    push rdx
    
    ; Calculate cursor position
    mov rax, rsi
    mov rdx, SCREEN_WIDTH
    mul rdx
    add rax, rdi
    
    ; Send low byte to CRT controller
    mov rdx, 0x3D4
    mov al, 0x0F
    out dx, al
    
    mov rdx, 0x3D5
    mov al, bl          ; Low byte of cursor position
    out dx, al
    
    ; Send high byte to CRT controller
    mov rdx, 0x3D4
    mov al, 0x0E
    out dx, al
    
    mov rdx, 0x3D5
    mov al, bh          ; High byte of cursor position
    out dx, al
    
    pop rdx
    pop rax
    pop rbp
    ret

; Get cursor position
; Output: RAX = row, RDX = column
console_get_cursor:
    push rbp
    mov rbp, rsp
    
    ; Read cursor position from CRT controller
    mov rdx, 0x3D4
    mov al, 0x0F
    out dx, al
    
    mov rdx, 0x3D5
    in al, dx
    mov bl, al          ; Low byte
    
    mov rdx, 0x3D4
    mov al, 0x0E
    out dx, al
    
    mov rdx, 0x3D5
    in al, dx
    mov bh, al          ; High byte
    
    ; Calculate row and column
    movzx rax, bx       ; Position = bx
    mov rdx, 0
    mov rbx, SCREEN_WIDTH
    div rbx             ; RAX = position / SCREEN_WIDTH, RDX = position % SCREEN_WIDTH
    
    pop rbp
    ret

section .data
    ; Console state
    console_row   dq 0   ; Current row
    console_col   dq 0   ; Current column
    console_color db DEFAULT_ATTRIB  ; Current text color
