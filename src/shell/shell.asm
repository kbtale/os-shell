; shell.asm
; Command shell for the x86-64 OS Shell
; Provides a command-line interface for user interaction

[BITS 64]
[GLOBAL shell_init]

section .text

; External functions
extern console_clear
extern console_write_string
extern console_write_char
extern console_write_line
extern console_read_line
extern memory_alloc
extern memory_free

; Initialize the shell
; No input parameters
shell_init:
    push rbp
    mov rbp, rsp
    
    ; Clear the screen
    call console_clear
    
    ; Display welcome message
    mov rdi, welcome_msg
    call console_write_line
    
    ; Display help message
    mov rdi, help_msg
    call console_write_line
    
    ; Main command loop
.command_loop:
    ; Display prompt
    mov rdi, prompt
    call console_write_string
    
    ; Read command
    mov rdi, command_buffer
    mov rsi, COMMAND_BUFFER_SIZE
    call console_read_line
    
    ; Process command
    mov rdi, command_buffer
    call process_command
    
    ; Loop back for next command
    jmp .command_loop
    
    ; We should never get here
    pop rbp
    ret

; Process a command
; Input: RDI = pointer to null-terminated command string
process_command:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save command pointer
    mov rbx, rdi
    
    ; Skip leading whitespace
    call skip_whitespace
    mov rbx, rax
    
    ; Check if command is empty
    cmp byte [rbx], 0
    je .done
    
    ; Parse command name
    mov rdi, rbx
    call get_token
    mov r12, rax        ; r12 = command name
    mov rbx, rdx        ; rbx = rest of command line
    
    ; Compare command with known commands
    
    ; "help" command
    mov rdi, r12
    mov rsi, cmd_help
    call string_compare
    test rax, rax
    jz .cmd_help
    
    ; "clear" command
    mov rdi, r12
    mov rsi, cmd_clear
    call string_compare
    test rax, rax
    jz .cmd_clear
    
    ; "echo" command
    mov rdi, r12
    mov rsi, cmd_echo
    call string_compare
    test rax, rax
    jz .cmd_echo
    
    ; "ls" command
    mov rdi, r12
    mov rsi, cmd_ls
    call string_compare
    test rax, rax
    jz .cmd_ls
    
    ; "cat" command
    mov rdi, r12
    mov rsi, cmd_cat
    call string_compare
    test rax, rax
    jz .cmd_cat
    
    ; "mkdir" command
    mov rdi, r12
    mov rsi, cmd_mkdir
    call string_compare
    test rax, rax
    jz .cmd_mkdir
    
    ; "rm" command
    mov rdi, r12
    mov rsi, cmd_rm
    call string_compare
    test rax, rax
    jz .cmd_rm
    
    ; "ps" command
    mov rdi, r12
    mov rsi, cmd_ps
    call string_compare
    test rax, rax
    jz .cmd_ps
    
    ; "kill" command
    mov rdi, r12
    mov rsi, cmd_kill
    call string_compare
    test rax, rax
    jz .cmd_kill
    
    ; "sysinfo" command
    mov rdi, r12
    mov rsi, cmd_sysinfo
    call string_compare
    test rax, rax
    jz .cmd_sysinfo
    
    ; "exit" command
    mov rdi, r12
    mov rsi, cmd_exit
    call string_compare
    test rax, rax
    jz .cmd_exit
    
    ; Unknown command
    mov rdi, unknown_cmd_msg
    call console_write_string
    mov rdi, r12
    call console_write_string
    mov rdi, newline
    call console_write_string
    jmp .done
    
.cmd_help:
    ; Display help message
    mov rdi, help_msg
    call console_write_line
    jmp .done
    
.cmd_clear:
    ; Clear the screen
    call console_clear
    jmp .done
    
.cmd_echo:
    ; Echo the rest of the command line
    mov rdi, rbx
    call console_write_line
    jmp .done
    
.cmd_ls:
    ; List files in directory
    call cmd_handler_ls
    jmp .done
    
.cmd_cat:
    ; Display file contents
    mov rdi, rbx
    call cmd_handler_cat
    jmp .done
    
.cmd_mkdir:
    ; Create directory
    mov rdi, rbx
    call cmd_handler_mkdir
    jmp .done
    
.cmd_rm:
    ; Remove file or directory
    mov rdi, rbx
    call cmd_handler_rm
    jmp .done
    
.cmd_ps:
    ; List processes
    call cmd_handler_ps
    jmp .done
    
.cmd_kill:
    ; Kill a process
    mov rdi, rbx
    call cmd_handler_kill
    jmp .done
    
.cmd_sysinfo:
    ; Display system information
    call cmd_handler_sysinfo
    jmp .done
    
.cmd_exit:
    ; Exit the shell (halt the system in this case)
    mov rdi, exit_msg
    call console_write_line
    cli
    hlt
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Skip whitespace characters
; Input: RBX = pointer to string
; Output: RAX = pointer to first non-whitespace character
skip_whitespace:
    mov rax, rbx
    
.loop:
    cmp byte [rax], ' '
    jne .check_tab
    inc rax
    jmp .loop
    
.check_tab:
    cmp byte [rax], 9    ; Tab character
    jne .done
    inc rax
    jmp .loop
    
.done:
    ret

; Get the next token from a string
; Input: RDI = pointer to string
; Output: RAX = pointer to token (null-terminated), RDX = pointer to rest of string
get_token:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Save string pointer
    mov rbx, rdi
    
    ; Skip leading whitespace
    call skip_whitespace
    mov rbx, rax
    
    ; Find the end of the token
    mov rcx, rbx
    
.find_end:
    cmp byte [rcx], 0    ; End of string
    je .end_found
    cmp byte [rcx], ' '  ; Space
    je .end_found
    cmp byte [rcx], 9    ; Tab
    je .end_found
    inc rcx
    jmp .find_end
    
.end_found:
    ; Temporarily null-terminate the token
    mov al, [rcx]
    mov byte [rcx], 0
    
    ; Set up return values
    mov rax, rbx        ; Token
    mov rdx, rcx        ; Rest of string
    
    ; Restore the original character
    mov [rcx], al
    
    ; If we found a delimiter, skip it
    cmp byte [rcx], 0
    je .done
    inc rdx
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Compare two strings
; Input: RDI = first string, RSI = second string
; Output: RAX = 0 if strings are equal, non-zero otherwise
string_compare:
    push rbp
    mov rbp, rsp
    
.loop:
    mov al, [rdi]
    mov bl, [rsi]
    
    ; Check if we've reached the end of both strings
    test al, al
    jz .check_end
    
    ; Compare characters
    cmp al, bl
    jne .not_equal
    
    ; Move to next character
    inc rdi
    inc rsi
    jmp .loop
    
.check_end:
    ; We've reached the end of the first string
    ; Check if we've also reached the end of the second string
    test bl, bl
    jnz .not_equal
    
    ; Strings are equal
    xor rax, rax
    jmp .done
    
.not_equal:
    ; Strings are not equal
    mov rax, 1
    
.done:
    pop rbp
    ret

; Command handler for "ls"
cmd_handler_ls:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would list files in a directory
    ; For now, just display a message
    mov rdi, ls_msg
    call console_write_line
    
    pop rbp
    ret

; Command handler for "cat"
; Input: RDI = arguments
cmd_handler_cat:
    push rbp
    mov rbp, rsp
    
    ; Skip leading whitespace
    call skip_whitespace
    
    ; Check if filename is provided
    cmp byte [rax], 0
    je .no_filename
    
    ; In a real implementation, this would display file contents
    ; For now, just display a message
    mov rdi, cat_msg
    call console_write_string
    mov rdi, rax
    call console_write_line
    jmp .done
    
.no_filename:
    mov rdi, cat_no_file_msg
    call console_write_line
    
.done:
    pop rbp
    ret

; Command handler for "mkdir"
; Input: RDI = arguments
cmd_handler_mkdir:
    push rbp
    mov rbp, rsp
    
    ; Skip leading whitespace
    call skip_whitespace
    
    ; Check if directory name is provided
    cmp byte [rax], 0
    je .no_dirname
    
    ; In a real implementation, this would create a directory
    ; For now, just display a message
    mov rdi, mkdir_msg
    call console_write_string
    mov rdi, rax
    call console_write_line
    jmp .done
    
.no_dirname:
    mov rdi, mkdir_no_dir_msg
    call console_write_line
    
.done:
    pop rbp
    ret

; Command handler for "rm"
; Input: RDI = arguments
cmd_handler_rm:
    push rbp
    mov rbp, rsp
    
    ; Skip leading whitespace
    call skip_whitespace
    
    ; Check if filename is provided
    cmp byte [rax], 0
    je .no_filename
    
    ; In a real implementation, this would remove a file or directory
    ; For now, just display a message
    mov rdi, rm_msg
    call console_write_string
    mov rdi, rax
    call console_write_line
    jmp .done
    
.no_filename:
    mov rdi, rm_no_file_msg
    call console_write_line
    
.done:
    pop rbp
    ret

; Command handler for "ps"
cmd_handler_ps:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would list processes
    ; For now, just display a message
    mov rdi, ps_msg
    call console_write_line
    mov rdi, ps_header
    call console_write_line
    mov rdi, ps_entry1
    call console_write_line
    mov rdi, ps_entry2
    call console_write_line
    
    pop rbp
    ret

; Command handler for "kill"
; Input: RDI = arguments
cmd_handler_kill:
    push rbp
    mov rbp, rsp
    
    ; Skip leading whitespace
    call skip_whitespace
    
    ; Check if PID is provided
    cmp byte [rax], 0
    je .no_pid
    
    ; In a real implementation, this would kill a process
    ; For now, just display a message
    mov rdi, kill_msg
    call console_write_string
    mov rdi, rax
    call console_write_line
    jmp .done
    
.no_pid:
    mov rdi, kill_no_pid_msg
    call console_write_line
    
.done:
    pop rbp
    ret

; Command handler for "sysinfo"
cmd_handler_sysinfo:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would display system information
    ; For now, just display some sample information
    mov rdi, sysinfo_msg
    call console_write_line
    mov rdi, sysinfo_cpu
    call console_write_line
    mov rdi, sysinfo_mem
    call console_write_line
    mov rdi, sysinfo_uptime
    call console_write_line
    
    pop rbp
    ret

section .data
    ; Constants
    COMMAND_BUFFER_SIZE equ 256
    
    ; Command strings
    cmd_help db 'help', 0
    cmd_clear db 'clear', 0
    cmd_echo db 'echo', 0
    cmd_ls db 'ls', 0
    cmd_cat db 'cat', 0
    cmd_mkdir db 'mkdir', 0
    cmd_rm db 'rm', 0
    cmd_ps db 'ps', 0
    cmd_kill db 'kill', 0
    cmd_sysinfo db 'sysinfo', 0
    cmd_exit db 'exit', 0
    
    ; Messages
    welcome_msg db 'Welcome to x86-64 OS Shell', 0
    help_msg db 'Available commands:', 0x0A, \
              '  help     - Display this help message', 0x0A, \
              '  clear    - Clear the screen', 0x0A, \
              '  echo     - Display a message', 0x0A, \
              '  ls       - List files in directory', 0x0A, \
              '  cat      - Display file contents', 0x0A, \
              '  mkdir    - Create directory', 0x0A, \
              '  rm       - Remove file or directory', 0x0A, \
              '  ps       - List processes', 0x0A, \
              '  kill     - Kill a process', 0x0A, \
              '  sysinfo  - Display system information', 0x0A, \
              '  exit     - Exit the shell', 0
    prompt db 'shell> ', 0
    unknown_cmd_msg db 'Unknown command: ', 0
    newline db 0x0A, 0
    exit_msg db 'Exiting shell...', 0
    
    ; Command handler messages
    ls_msg db 'Directory listing:', 0x0A, \
            '  file1.txt', 0x0A, \
            '  file2.txt', 0x0A, \
            '  directory1/', 0
    cat_msg db 'Contents of file: ', 0
    cat_no_file_msg db 'Error: No filename specified', 0
    mkdir_msg db 'Created directory: ', 0
    mkdir_no_dir_msg db 'Error: No directory name specified', 0
    rm_msg db 'Removed: ', 0
    rm_no_file_msg db 'Error: No filename specified', 0
    ps_msg db 'Process list:', 0
    ps_header db '  PID  STATE  NAME', 0
    ps_entry1 db '    1  RUN    init', 0
    ps_entry2 db '    2  RUN    shell', 0
    kill_msg db 'Killed process with PID: ', 0
    kill_no_pid_msg db 'Error: No PID specified', 0
    sysinfo_msg db 'System Information:', 0
    sysinfo_cpu db '  CPU: x86-64 @ 3.7 GHz', 0
    sysinfo_mem db '  Memory: 128 MB total, 64 MB free', 0
    sysinfo_uptime db '  Uptime: 0 days, 0 hours, 5 minutes', 0

section .bss
    ; Command buffer
    command_buffer resb COMMAND_BUFFER_SIZE
