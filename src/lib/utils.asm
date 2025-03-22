; utils.asm
; Utility functions for the x86-64 OS Shell
; Provides string manipulation, conversion, and other helper functions

[BITS 64]
[GLOBAL utils_init]
[GLOBAL utils_strcmp]
[GLOBAL utils_strncmp]
[GLOBAL utils_strlen]
[GLOBAL utils_strcpy]
[GLOBAL utils_strncpy]
[GLOBAL utils_strcat]
[GLOBAL utils_strncat]
[GLOBAL utils_atoi]
[GLOBAL utils_itoa]
[GLOBAL utils_htoa]
[GLOBAL utils_toupper]
[GLOBAL utils_tolower]
[GLOBAL utils_isalpha]
[GLOBAL utils_isdigit]
[GLOBAL utils_isalnum]
[GLOBAL utils_isspace]
[GLOBAL utils_split]
[GLOBAL utils_trim]

section .text

; Initialize utils module
; No input parameters
utils_init:
    push rbp
    mov rbp, rsp
    
    ; Nothing to initialize
    
    pop rbp
    ret

; Compare two strings
; Input: RDI = first string, RSI = second string
; Output: RAX = 0 if equal, negative if RDI < RSI, positive if RDI > RSI
utils_strcmp:
    push rbp
    mov rbp, rsp
    
.loop:
    ; Load characters
    movzx rax, byte [rdi]
    movzx rcx, byte [rsi]
    
    ; Compare characters
    cmp rax, rcx
    jne .not_equal
    
    ; Check for end of string
    test rax, rax
    jz .equal
    
    ; Move to next character
    inc rdi
    inc rsi
    jmp .loop
    
.not_equal:
    ; Return difference
    sub rax, rcx
    jmp .done
    
.equal:
    ; Strings are equal
    xor rax, rax
    
.done:
    pop rbp
    ret

; Compare two strings up to n characters
; Input: RDI = first string, RSI = second string, RDX = max characters
; Output: RAX = 0 if equal, negative if RDI < RSI, positive if RDI > RSI
utils_strncmp:
    push rbp
    mov rbp, rsp
    
    ; Check if n is 0
    test rdx, rdx
    jz .equal
    
.loop:
    ; Load characters
    movzx rax, byte [rdi]
    movzx rcx, byte [rsi]
    
    ; Compare characters
    cmp rax, rcx
    jne .not_equal
    
    ; Check for end of string
    test rax, rax
    jz .equal
    
    ; Move to next character
    inc rdi
    inc rsi
    
    ; Decrement counter
    dec rdx
    jnz .loop
    
    ; Reached max characters, strings are equal
    xor rax, rax
    jmp .done
    
.not_equal:
    ; Return difference
    sub rax, rcx
    jmp .done
    
.equal:
    ; Strings are equal
    xor rax, rax
    
.done:
    pop rbp
    ret

; Get string length
; Input: RDI = string
; Output: RAX = length
utils_strlen:
    push rbp
    mov rbp, rsp
    
    ; Save original pointer
    mov rax, rdi
    
.loop:
    ; Check for end of string
    cmp byte [rdi], 0
    je .done
    
    ; Move to next character
    inc rdi
    jmp .loop
    
.done:
    ; Calculate length
    sub rdi, rax
    mov rax, rdi
    
    pop rbp
    ret

; Copy string
; Input: RDI = destination, RSI = source
; Output: RAX = destination
utils_strcpy:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save destination
    mov rbx, rdi
    
.loop:
    ; Load character
    mov al, [rsi]
    mov [rdi], al
    
    ; Check for end of string
    test al, al
    jz .done
    
    ; Move to next character
    inc rsi
    inc rdi
    jmp .loop
    
.done:
    ; Return destination
    mov rax, rbx
    
    pop rbx
    pop rbp
    ret

; Copy string up to n characters
; Input: RDI = destination, RSI = source, RDX = max characters
; Output: RAX = destination
utils_strncpy:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save destination
    mov rbx, rdi
    
    ; Check if n is 0
    test rdx, rdx
    jz .done
    
.loop:
    ; Load character
    mov al, [rsi]
    mov [rdi], al
    
    ; Check for end of string
    test al, al
    jz .pad
    
    ; Move to next character
    inc rsi
    inc rdi
    
    ; Decrement counter
    dec rdx
    jnz .loop
    
    ; Reached max characters
    jmp .done
    
.pad:
    ; Pad with zeros
    inc rdi
    dec rdx
    jz .done
    
    mov byte [rdi], 0
    jmp .pad
    
.done:
    ; Return destination
    mov rax, rbx
    
    pop rbx
    pop rbp
    ret

; Concatenate strings
; Input: RDI = destination, RSI = source
; Output: RAX = destination
utils_strcat:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save destination
    mov rbx, rdi
    
    ; Find end of destination
    call utils_strlen
    add rdi, rax
    
    ; Copy source to end of destination
    call utils_strcpy
    
    ; Return destination
    mov rax, rbx
    
    pop rbx
    pop rbp
    ret

; Concatenate strings up to n characters
; Input: RDI = destination, RSI = source, RDX = max characters
; Output: RAX = destination
utils_strncat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; Destination
    mov r12, rdx        ; Max characters
    
    ; Find end of destination
    call utils_strlen
    add rdi, rax
    
    ; Copy source to end of destination
    mov rdx, r12
    call utils_strncpy
    
    ; Return destination
    mov rax, rbx
    
    pop r12
    pop rbx
    pop rbp
    ret

; Convert ASCII string to integer
; Input: RDI = string
; Output: RAX = integer value
utils_atoi:
    push rbp
    mov rbp, rsp
    
    ; Initialize result
    xor rax, rax
    
    ; Check for sign
    cmp byte [rdi], '-'
    jne .positive
    
    ; Negative number
    inc rdi
    
    ; Convert digits
    call .convert
    
    ; Negate result
    neg rax
    jmp .done
    
.positive:
    ; Check for plus sign
    cmp byte [rdi], '+'
    jne .convert
    
    ; Skip plus sign
    inc rdi
    
.convert:
    ; Check for end of string
    cmp byte [rdi], 0
    je .done
    
    ; Check if character is a digit
    movzx rcx, byte [rdi]
    sub rcx, '0'
    cmp rcx, 10
    jae .done
    
    ; Multiply result by 10
    imul rax, 10
    
    ; Add digit
    add rax, rcx
    
    ; Move to next character
    inc rdi
    jmp .convert
    
.done:
    pop rbp
    ret

; Convert integer to ASCII string
; Input: RDI = buffer, RSI = integer
; Output: RAX = buffer
utils_itoa:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Integer
    
    ; Check if number is negative
    test r12, r12
    jns .positive
    
    ; Negative number
    mov byte [rbx], '-'
    inc rbx
    neg r12
    
.positive:
    ; Convert number to string (in reverse order)
    mov rdi, rbx
    mov rax, r12
    mov r13, 10         ; Base 10
    
    ; Handle special case for 0
    test rax, rax
    jnz .convert
    
    mov byte [rdi], '0'
    inc rdi
    jmp .terminate
    
.convert:
    ; Check if number is 0
    test rax, rax
    jz .reverse
    
    ; Divide by 10
    xor rdx, rdx
    div r13
    
    ; Convert remainder to ASCII
    add dl, '0'
    
    ; Store digit
    mov [rdi], dl
    inc rdi
    
    jmp .convert
    
.reverse:
    ; Terminate string
    mov byte [rdi], 0
    
    ; Reverse the string (excluding sign)
    mov rdi, rbx
    lea rsi, [rdi - 1]
    
.reverse_loop:
    ; Check if we're done
    cmp rdi, rsi
    jae .done
    
    ; Swap characters
    mov al, [rdi]
    mov ah, [rsi]
    mov [rdi], ah
    mov [rsi], al
    
    ; Move pointers
    inc rdi
    dec rsi
    jmp .reverse_loop
    
.terminate:
    ; Terminate string
    mov byte [rdi], 0
    
.done:
    ; Return buffer
    mov rax, rbx
    
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Convert integer to hexadecimal ASCII string
; Input: RDI = buffer, RSI = integer
; Output: RAX = buffer
utils_htoa:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Integer
    
    ; Add "0x" prefix
    mov word [rbx], "0x"
    add rbx, 2
    
    ; Convert number to hexadecimal (in reverse order)
    mov rdi, rbx
    mov rax, r12
    mov r13, 16         ; Base 16
    mov r14, hex_digits ; Digit characters
    
    ; Handle special case for 0
    test rax, rax
    jnz .convert
    
    mov byte [rdi], '0'
    inc rdi
    jmp .terminate
    
.convert:
    ; Check if number is 0
    test rax, rax
    jz .reverse
    
    ; Divide by 16
    xor rdx, rdx
    div r13
    
    ; Convert remainder to ASCII
    movzx rdx, dl
    mov dl, [r14 + rdx]
    
    ; Store digit
    mov [rdi], dl
    inc rdi
    
    jmp .convert
    
.reverse:
    ; Terminate string
    mov byte [rdi], 0
    
    ; Reverse the string (excluding prefix)
    mov rdi, rbx
    lea rsi, [rdi - 1]
    
.reverse_loop:
    ; Check if we're done
    cmp rdi, rsi
    jae .done
    
    ; Swap characters
    mov al, [rdi]
    mov ah, [rsi]
    mov [rdi], ah
    mov [rsi], al
    
    ; Move pointers
    inc rdi
    dec rsi
    jmp .reverse_loop
    
.terminate:
    ; Terminate string
    mov byte [rdi], 0
    
.done:
    ; Return buffer
    mov rax, rbx
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Convert character to uppercase
; Input: RDI = character
; Output: RAX = uppercase character
utils_toupper:
    push rbp
    mov rbp, rsp
    
    ; Check if character is lowercase
    cmp rdi, 'a'
    jl .done
    cmp rdi, 'z'
    jg .done
    
    ; Convert to uppercase
    sub rdi, 32
    
.done:
    ; Return character
    mov rax, rdi
    
    pop rbp
    ret

; Convert character to lowercase
; Input: RDI = character
; Output: RAX = lowercase character
utils_tolower:
    push rbp
    mov rbp, rsp
    
    ; Check if character is uppercase
    cmp rdi, 'A'
    jl .done
    cmp rdi, 'Z'
    jg .done
    
    ; Convert to lowercase
    add rdi, 32
    
.done:
    ; Return character
    mov rax, rdi
    
    pop rbp
    ret

; Check if character is alphabetic
; Input: RDI = character
; Output: RAX = 1 if alphabetic, 0 otherwise
utils_isalpha:
    push rbp
    mov rbp, rsp
    
    ; Check if character is uppercase
    cmp rdi, 'A'
    jl .not_alpha
    cmp rdi, 'Z'
    jle .alpha
    
    ; Check if character is lowercase
    cmp rdi, 'a'
    jl .not_alpha
    cmp rdi, 'z'
    jle .alpha
    
.not_alpha:
    ; Not alphabetic
    xor rax, rax
    jmp .done
    
.alpha:
    ; Alphabetic
    mov rax, 1
    
.done:
    pop rbp
    ret

; Check if character is a digit
; Input: RDI = character
; Output: RAX = 1 if digit, 0 otherwise
utils_isdigit:
    push rbp
    mov rbp, rsp
    
    ; Check if character is a digit
    cmp rdi, '0'
    jl .not_digit
    cmp rdi, '9'
    jle .digit
    
.not_digit:
    ; Not a digit
    xor rax, rax
    jmp .done
    
.digit:
    ; Digit
    mov rax, 1
    
.done:
    pop rbp
    ret

; Check if character is alphanumeric
; Input: RDI = character
; Output: RAX = 1 if alphanumeric, 0 otherwise
utils_isalnum:
    push rbp
    mov rbp, rsp
    
    ; Check if character is alphabetic
    call utils_isalpha
    test rax, rax
    jnz .done
    
    ; Check if character is a digit
    call utils_isdigit
    
.done:
    pop rbp
    ret

; Check if character is whitespace
; Input: RDI = character
; Output: RAX = 1 if whitespace, 0 otherwise
utils_isspace:
    push rbp
    mov rbp, rsp
    
    ; Check if character is whitespace
    cmp rdi, ' '        ; Space
    je .space
    cmp rdi, 9          ; Tab
    je .space
    cmp rdi, 10         ; Line feed
    je .space
    cmp rdi, 11         ; Vertical tab
    je .space
    cmp rdi, 12         ; Form feed
    je .space
    cmp rdi, 13         ; Carriage return
    je .space
    
    ; Not whitespace
    xor rax, rax
    jmp .done
    
.space:
    ; Whitespace
    mov rax, 1
    
.done:
    pop rbp
    ret

; Split string into tokens
; Input: RDI = string, RSI = delimiter, RDX = array of pointers, RCX = max tokens
; Output: RAX = number of tokens
utils_split:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save parameters
    mov rbx, rdi        ; String
    mov r12, rsi        ; Delimiter
    mov r13, rdx        ; Array of pointers
    mov r14, rcx        ; Max tokens
    
    ; Initialize token count
    xor r15, r15        ; Token count
    
    ; Check if string is empty
    cmp byte [rbx], 0
    je .done
    
    ; Start of first token
    mov [r13], rbx
    inc r15
    
.find_loop:
    ; Check if we've reached max tokens
    cmp r15, r14
    jge .done
    
    ; Find next delimiter
    mov rdi, rbx
    mov rsi, r12
    call utils_strchr
    
    ; Check if delimiter found
    test rax, rax
    jz .done
    
    ; Replace delimiter with null terminator
    mov byte [rax], 0
    
    ; Move to next character
    lea rbx, [rax + 1]
    
    ; Check if end of string
    cmp byte [rbx], 0
    je .done
    
    ; Store pointer to next token
    mov [r13 + r15*8], rbx
    inc r15
    
    jmp .find_loop
    
.done:
    ; Return token count
    mov rax, r15
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Find first occurrence of character in string
; Input: RDI = string, RSI = character
; Output: RAX = pointer to character or NULL if not found
utils_strchr:
    push rbp
    mov rbp, rsp
    
.loop:
    ; Load character
    movzx rax, byte [rdi]
    
    ; Check if character matches
    cmp rax, rsi
    je .found
    
    ; Check for end of string
    test rax, rax
    jz .not_found
    
    ; Move to next character
    inc rdi
    jmp .loop
    
.found:
    ; Return pointer to character
    mov rax, rdi
    jmp .done
    
.not_found:
    ; Character not found
    xor rax, rax
    
.done:
    pop rbp
    ret

; Trim whitespace from beginning and end of string
; Input: RDI = string
; Output: RAX = trimmed string
utils_trim:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save string
    mov rbx, rdi
    
    ; Trim leading whitespace
    call .trim_left
    mov r12, rax        ; Save trimmed string
    
    ; Find end of string
    mov rdi, r12
    call utils_strlen
    lea rdi, [r12 + rax - 1]
    
    ; Trim trailing whitespace
    call .trim_right
    
    ; Return trimmed string
    mov rax, r12
    
    pop r12
    pop rbx
    pop rbp
    ret
    
.trim_left:
    ; Check if string is empty
    cmp byte [rdi], 0
    je .left_done
    
    ; Check if character is whitespace
    movzx rsi, byte [rdi]
    push rdi
    mov rdi, rsi
    call utils_isspace
    pop rdi
    
    ; If not whitespace, we're done
    test rax, rax
    jz .left_done
    
    ; Move to next character
    inc rdi
    jmp .trim_left
    
.left_done:
    ; Return trimmed string
    mov rax, rdi
    ret
    
.trim_right:
    ; Check if we've gone past the beginning of the string
    cmp rdi, r12
    jl .right_done
    
    ; Check if character is whitespace
    movzx rsi, byte [rdi]
    push rdi
    mov rdi, rsi
    call utils_isspace
    pop rdi
    
    ; If not whitespace, we're done
    test rax, rax
    jz .right_done
    
    ; Replace with null terminator
    mov byte [rdi], 0
    
    ; Move to previous character
    dec rdi
    jmp .trim_right
    
.right_done:
    ret

section .data
    ; Hexadecimal digits
    hex_digits db "0123456789ABCDEF"
