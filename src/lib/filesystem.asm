; filesystem.asm
; File system implementation for the x86-64 OS Shell
; Provides functions for file and directory operations

[BITS 64]
[GLOBAL fs_init]
[GLOBAL fs_open]
[GLOBAL fs_close]
[GLOBAL fs_read]
[GLOBAL fs_write]
[GLOBAL fs_seek]
[GLOBAL fs_tell]
[GLOBAL fs_stat]
[GLOBAL fs_mkdir]
[GLOBAL fs_rmdir]
[GLOBAL fs_unlink]
[GLOBAL fs_readdir]

section .text

; External functions
extern memory_alloc
extern memory_free
extern memory_copy
extern memory_set

; Initialize the file system
; No input parameters
fs_init:
    push rbp
    mov rbp, rsp
    
    ; Initialize file system data structures
    mov qword [current_dir], root_dir
    
    ; Create root directory
    mov qword [root_dir], 0        ; No parent
    mov qword [root_dir + 8], 0    ; No entries yet
    mov qword [root_dir + 16], 0   ; No next sibling
    
    ; Set up initial file descriptor table
    xor rcx, rcx
    
.init_fd_loop:
    mov qword [fd_table + rcx * 8], 0  ; Mark as free
    inc rcx
    cmp rcx, MAX_OPEN_FILES
    jl .init_fd_loop
    
    pop rbp
    ret

; Open a file
; Input: RDI = pointer to filename, RSI = flags
; Output: RAX = file descriptor or -1 if error
fs_open:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Save parameters
    mov rbx, rdi        ; Filename
    mov r12, rsi        ; Flags
    
    ; Find the file in the current directory
    mov rdi, rbx
    call find_file
    
    ; Check if file exists
    test rax, rax
    jz .file_not_found
    
    ; File exists, check if we're creating a new file
    test r12, O_CREAT
    jz .open_existing
    
    ; If O_EXCL is set, fail if file exists
    test r12, O_EXCL
    jnz .file_exists_error
    
.open_existing:
    ; File exists, allocate a file descriptor
    mov r13, rax        ; Save file entry
    call allocate_fd
    
    ; Check if we got a valid file descriptor
    cmp rax, -1
    je .no_fd_error
    
    ; Set up file descriptor
    mov r14, rax        ; Save file descriptor
    mov rcx, rax
    shl rcx, 3          ; Multiply by 8
    
    mov rax, r13
    mov [fd_table + rcx], rax  ; Store file entry pointer
    
    ; Set initial file position to 0
    mov qword [fd_pos_table + rcx], 0
    
    ; Return file descriptor
    mov rax, r14
    jmp .done
    
.file_not_found:
    ; File not found, check if we should create it
    test r12, O_CREAT
    jz .error
    
    ; Create a new file
    mov rdi, rbx        ; Filename
    mov rsi, FILE_TYPE  ; Regular file
    call create_file
    
    ; Check if file was created successfully
    test rax, rax
    jz .error
    
    ; Allocate a file descriptor
    mov r13, rax        ; Save file entry
    call allocate_fd
    
    ; Check if we got a valid file descriptor
    cmp rax, -1
    je .no_fd_error
    
    ; Set up file descriptor
    mov r14, rax        ; Save file descriptor
    mov rcx, rax
    shl rcx, 3          ; Multiply by 8
    
    mov rax, r13
    mov [fd_table + rcx], rax  ; Store file entry pointer
    
    ; Set initial file position to 0
    mov qword [fd_pos_table + rcx], 0
    
    ; Return file descriptor
    mov rax, r14
    jmp .done
    
.file_exists_error:
    ; File exists but O_EXCL was specified
    mov rax, -1
    jmp .done
    
.no_fd_error:
    ; No file descriptors available
    mov rax, -1
    jmp .done
    
.error:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Close a file
; Input: RDI = file descriptor
; Output: RAX = 0 on success, -1 on error
fs_close:
    push rbp
    mov rbp, rsp
    
    ; Check if file descriptor is valid
    cmp rdi, 0
    jl .invalid_fd
    cmp rdi, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rdi
    shl rcx, 3          ; Multiply by 8
    cmp qword [fd_table + rcx], 0
    je .invalid_fd
    
    ; Mark file descriptor as free
    mov qword [fd_table + rcx], 0
    
    ; Success
    xor rax, rax
    jmp .done
    
.invalid_fd:
    ; Invalid file descriptor
    mov rax, -1
    
.done:
    pop rbp
    ret

; Read from a file
; Input: RDI = file descriptor, RSI = buffer, RDX = count
; Output: RAX = number of bytes read or -1 on error
fs_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Save parameters
    mov rbx, rdi        ; File descriptor
    mov r12, rsi        ; Buffer
    mov r13, rdx        ; Count
    
    ; Check if file descriptor is valid
    cmp rbx, 0
    jl .invalid_fd
    cmp rbx, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rbx
    shl rcx, 3          ; Multiply by 8
    mov r14, [fd_table + rcx]
    test r14, r14
    jz .invalid_fd
    
    ; Get current file position
    mov rax, [fd_pos_table + rcx]
    
    ; Check if we're at end of file
    cmp rax, [r14 + 24]  ; Compare with file size
    jge .eof
    
    ; Calculate how many bytes we can read
    mov rdx, [r14 + 24]  ; File size
    sub rdx, rax         ; Bytes remaining
    cmp rdx, r13
    jle .read_remaining
    mov rdx, r13         ; Read requested count
    
.read_remaining:
    ; Read data from file
    mov rdi, r12         ; Destination buffer
    lea rsi, [r14 + 32]  ; Source (file data)
    add rsi, rax         ; Adjust for file position
    call memory_copy
    
    ; Update file position
    add rax, rdx
    mov [fd_pos_table + rcx], rax
    
    ; Return number of bytes read
    mov rax, rdx
    jmp .done
    
.eof:
    ; End of file, return 0
    xor rax, rax
    jmp .done
    
.invalid_fd:
    ; Invalid file descriptor
    mov rax, -1
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Write to a file
; Input: RDI = file descriptor, RSI = buffer, RDX = count
; Output: RAX = number of bytes written or -1 on error
fs_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save parameters
    mov rbx, rdi        ; File descriptor
    mov r12, rsi        ; Buffer
    mov r13, rdx        ; Count
    
    ; Check if file descriptor is valid
    cmp rbx, 0
    jl .invalid_fd
    cmp rbx, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rbx
    shl rcx, 3          ; Multiply by 8
    mov r14, [fd_table + rcx]
    test r14, r14
    jz .invalid_fd
    
    ; Get current file position
    mov r15, [fd_pos_table + rcx]
    
    ; Check if we need to extend the file
    add r15, r13
    cmp r15, [r14 + 24]  ; Compare with file size
    jle .no_extend
    
    ; Extend the file
    mov [r14 + 24], r15  ; Update file size
    
.no_extend:
    ; Write data to file
    lea rdi, [r14 + 32]  ; Destination (file data)
    add rdi, [fd_pos_table + rcx]  ; Adjust for file position
    mov rsi, r12         ; Source buffer
    mov rdx, r13         ; Count
    call memory_copy
    
    ; Update file position
    mov [fd_pos_table + rcx], r15
    
    ; Return number of bytes written
    mov rax, r13
    jmp .done
    
.invalid_fd:
    ; Invalid file descriptor
    mov rax, -1
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Seek within a file
; Input: RDI = file descriptor, RSI = offset, RDX = whence
; Output: RAX = new file position or -1 on error
fs_seek:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; File descriptor
    mov r12, rsi        ; Offset
    
    ; Check if file descriptor is valid
    cmp rbx, 0
    jl .invalid_fd
    cmp rbx, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rbx
    shl rcx, 3          ; Multiply by 8
    mov rax, [fd_table + rcx]
    test rax, rax
    jz .invalid_fd
    
    ; Calculate new position based on whence
    cmp rdx, SEEK_SET
    je .seek_set
    cmp rdx, SEEK_CUR
    je .seek_cur
    cmp rdx, SEEK_END
    je .seek_end
    jmp .invalid_whence
    
.seek_set:
    ; Seek from beginning of file
    mov rax, r12
    jmp .check_bounds
    
.seek_cur:
    ; Seek from current position
    mov rax, [fd_pos_table + rcx]
    add rax, r12
    jmp .check_bounds
    
.seek_end:
    ; Seek from end of file
    mov rax, [fd_table + rcx]
    mov rax, [rax + 24]  ; File size
    add rax, r12
    
.check_bounds:
    ; Check if new position is valid
    cmp rax, 0
    jl .invalid_position
    
    ; Update file position
    mov [fd_pos_table + rcx], rax
    jmp .done
    
.invalid_fd:
.invalid_whence:
.invalid_position:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Get current file position
; Input: RDI = file descriptor
; Output: RAX = current file position or -1 on error
fs_tell:
    push rbp
    mov rbp, rsp
    
    ; Check if file descriptor is valid
    cmp rdi, 0
    jl .invalid_fd
    cmp rdi, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rdi
    shl rcx, 3          ; Multiply by 8
    cmp qword [fd_table + rcx], 0
    je .invalid_fd
    
    ; Return current file position
    mov rax, [fd_pos_table + rcx]
    jmp .done
    
.invalid_fd:
    ; Invalid file descriptor
    mov rax, -1
    
.done:
    pop rbp
    ret

; Get file status
; Input: RDI = pointer to filename, RSI = pointer to stat buffer
; Output: RAX = 0 on success, -1 on error
fs_stat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; Filename
    mov r12, rsi        ; Stat buffer
    
    ; Find the file
    call find_file
    
    ; Check if file was found
    test rax, rax
    jz .file_not_found
    
    ; Fill in stat buffer
    mov [r12], rax           ; File entry pointer
    mov rdx, [rax + 16]      ; File type
    mov [r12 + 8], rdx
    mov rdx, [rax + 24]      ; File size
    mov [r12 + 16], rdx
    
    ; Success
    xor rax, rax
    jmp .done
    
.file_not_found:
    ; File not found
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Create a directory
; Input: RDI = pointer to directory name
; Output: RAX = 0 on success, -1 on error
fs_mkdir:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save directory name
    mov rbx, rdi
    
    ; Check if directory already exists
    call find_file
    
    ; If directory exists, return error
    test rax, rax
    jnz .dir_exists
    
    ; Create a new directory
    mov rdi, rbx        ; Directory name
    mov rsi, DIR_TYPE   ; Directory type
    call create_file
    
    ; Check if directory was created successfully
    test rax, rax
    jz .error
    
    ; Success
    xor rax, rax
    jmp .done
    
.dir_exists:
    ; Directory already exists
    mov rax, -1
    jmp .done
    
.error:
    ; Error occurred
    mov rax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Remove a directory
; Input: RDI = pointer to directory name
; Output: RAX = 0 on success, -1 on error
fs_rmdir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save directory name
    mov rbx, rdi
    
    ; Find the directory
    call find_file
    
    ; Check if directory exists
    test rax, rax
    jz .dir_not_found
    
    ; Check if it's a directory
    cmp qword [rax + 16], DIR_TYPE
    jne .not_a_directory
    
    ; Check if directory is empty
    cmp qword [rax + 8], 0
    jne .dir_not_empty
    
    ; Remove the directory from its parent
    mov r12, rax        ; Save directory entry
    mov rdi, rbx        ; Directory name
    call remove_file_entry
    
    ; Free the directory entry
    mov rdi, r12
    call memory_free
    
    ; Success
    xor rax, rax
    jmp .done
    
.dir_not_found:
    ; Directory not found
    mov rax, -1
    jmp .done
    
.not_a_directory:
    ; Not a directory
    mov rax, -1
    jmp .done
    
.dir_not_empty:
    ; Directory not empty
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Remove a file
; Input: RDI = pointer to filename
; Output: RAX = 0 on success, -1 on error
fs_unlink:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save filename
    mov rbx, rdi
    
    ; Find the file
    call find_file
    
    ; Check if file exists
    test rax, rax
    jz .file_not_found
    
    ; Check if it's a regular file
    cmp qword [rax + 16], FILE_TYPE
    jne .not_a_file
    
    ; Remove the file from its parent
    mov r12, rax        ; Save file entry
    mov rdi, rbx        ; Filename
    call remove_file_entry
    
    ; Free the file entry
    mov rdi, r12
    call memory_free
    
    ; Success
    xor rax, rax
    jmp .done
    
.file_not_found:
    ; File not found
    mov rax, -1
    jmp .done
    
.not_a_file:
    ; Not a regular file
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Read directory entries
; Input: RDI = directory file descriptor, RSI = buffer, RDX = buffer size
; Output: RAX = number of entries read or -1 on error
fs_readdir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save parameters
    mov rbx, rdi        ; Directory file descriptor
    mov r12, rsi        ; Buffer
    mov r13, rdx        ; Buffer size
    
    ; Check if file descriptor is valid
    cmp rbx, 0
    jl .invalid_fd
    cmp rbx, MAX_OPEN_FILES
    jge .invalid_fd
    
    ; Check if file descriptor is in use
    mov rcx, rbx
    shl rcx, 3          ; Multiply by 8
    mov r14, [fd_table + rcx]
    test r14, r14
    jz .invalid_fd
    
    ; Check if it's a directory
    cmp qword [r14 + 16], DIR_TYPE
    jne .not_a_directory
    
    ; Get current position in directory
    mov r15, [fd_pos_table + rcx]
    
    ; Get the first entry in the directory
    mov rax, [r14 + 8]  ; First entry
    
    ; Skip entries based on position
    mov rcx, 0
    
.skip_loop:
    cmp rcx, r15
    jge .read_entries
    test rax, rax
    jz .eof
    mov rax, [rax + 16]  ; Next sibling
    inc rcx
    jmp .skip_loop
    
.read_entries:
    ; Read entries into buffer
    xor rcx, rcx        ; Entry count
    mov rdi, r12        ; Buffer pointer
    
.read_loop:
    ; Check if we've reached the end of directory
    test rax, rax
    jz .done_reading
    
    ; Check if buffer is full
    cmp rcx, r13
    jge .done_reading
    
    ; Copy entry name to buffer
    lea rsi, [rax + 32]  ; Entry name
    call copy_string
    
    ; Move to next entry
    mov rax, [rax + 16]  ; Next sibling
    inc rcx
    jmp .read_loop
    
.done_reading:
    ; Update directory position
    mov rdx, rbx
    shl rdx, 3          ; Multiply by 8
    add [fd_pos_table + rdx], rcx
    
    ; Return number of entries read
    mov rax, rcx
    jmp .done
    
.eof:
    ; End of directory, return 0
    xor rax, rax
    jmp .done
    
.invalid_fd:
.not_a_directory:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Find a file in the current directory
; Input: RDI = pointer to filename
; Output: RAX = pointer to file entry or 0 if not found
find_file:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save filename
    mov rbx, rdi
    
    ; Start with the first entry in the current directory
    mov rax, [current_dir]
    mov rax, [rax + 8]  ; First entry
    
.find_loop:
    ; Check if we've reached the end of directory
    test rax, rax
    jz .not_found
    
    ; Compare filename
    mov r12, rax        ; Save entry pointer
    lea rdi, [rax + 32] ; Entry name
    mov rsi, rbx        ; Filename to find
    call string_compare
    
    ; Check if names match
    test rax, rax
    jz .found
    
    ; Move to next entry
    mov rax, [r12 + 16] ; Next sibling
    jmp .find_loop
    
.found:
    ; Return the entry pointer
    mov rax, r12
    jmp .done
    
.not_found:
    ; File not found
    xor rax, rax
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Create a new file or directory
; Input: RDI = pointer to name, RSI = type (FILE_TYPE or DIR_TYPE)
; Output: RAX = pointer to new entry or 0 if error
create_file:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Name
    mov r12, rsi        ; Type
    
    ; Calculate entry size (header + name)
    mov rdi, rbx
    call string_length
    add rax, 33         ; 32 bytes for header + length + null terminator
    
    ; Allocate memory for the entry
    mov rdi, rax
    call memory_alloc
    
    ; Check if allocation succeeded
    test rax, rax
    jz .error
    
    ; Save entry pointer
    mov r13, rax
    
    ; Initialize entry
    mov qword [r13], 0        ; No parent yet
    mov qword [r13 + 8], 0    ; No children
    mov qword [r13 + 16], 0   ; No siblings
    mov qword [r13 + 24], 0   ; Size 0
    
    ; Set type
    mov [r13 + 16], r12
    
    ; Copy name
    lea rdi, [r13 + 32]       ; Destination
    mov rsi, rbx              ; Source
    call copy_string
    
    ; Add entry to current directory
    mov rdi, r13
    call add_to_directory
    
    ; Return the new entry
    mov rax, r13
    jmp .done
    
.error:
    ; Error occurred
    xor rax, rax
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Add an entry to the current directory
; Input: RDI = pointer to entry
add_to_directory:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save entry pointer
    mov rbx, rdi
    
    ; Set parent pointer
    mov rax, [current_dir]
    mov [rbx], rax
    
    ; Check if directory is empty
    mov rax, [current_dir]
    cmp qword [rax + 8], 0
    jne .add_sibling
    
    ; Directory is empty, add as first child
    mov [rax + 8], rbx
    jmp .done
    
.add_sibling:
    ; Find the last sibling
    mov rax, [rax + 8]  ; First child
    
.find_last:
    cmp qword [rax + 16], 0
    je .found_last
    mov rax, [rax + 16]
    jmp .find_last
    
.found_last:
    ; Add as last sibling
    mov [rax + 16], rbx
    
.done:
    pop rbx
    pop rbp
    ret

; Remove a file entry from its parent directory
; Input: RDI = pointer to filename
; Output: RAX = 0 on success, -1 on error
remove_file_entry:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save filename
    mov rbx, rdi
    
    ; Find the file
    call find_file
    
    ; Check if file exists
    test rax, rax
    jz .file_not_found
    
    ; Save file entry pointer
    mov r12, rax
    
    ; Get parent directory
    mov r13, [r12]
    
    ; Check if it's the first child
    mov rax, [r13 + 8]
    cmp rax, r12
    je .remove_first
    
    ; Find the previous sibling
    mov rbx, rax        ; First child
    
.find_prev:
    mov rax, [rbx + 16]
    cmp rax, r12
    je .found_prev
    mov rbx, rax
    jmp .find_prev
    
.found_prev:
    ; Update previous sibling's next pointer
    mov rax, [r12 + 16]
    mov [rbx + 16], rax
    jmp .success
    
.remove_first:
    ; Update parent's first child pointer
    mov rax, [r12 + 16]
    mov [r13 + 8], rax
    
.success:
    ; Success
    xor rax, rax
    jmp .done
    
.file_not_found:
    ; File not found
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Allocate a file descriptor
; Output: RAX = file descriptor or -1 if no descriptors available
allocate_fd:
    push rbp
    mov rbp, rsp
    
    ; Find a free file descriptor
    xor rcx, rcx
    
.find_fd:
    cmp rcx, MAX_OPEN_FILES
    jge .no_fd
    
    ; Check if this descriptor is free
    mov rax, rcx
    shl rax, 3          ; Multiply by 8
    cmp qword [fd_table + rax], 0
    je .found_fd
    
    ; Try next descriptor
    inc rcx
    jmp .find_fd
    
.found_fd:
    ; Return the file descriptor
    mov rax, rcx
    jmp .done
    
.no_fd:
    ; No file descriptors available
    mov rax, -1
    
.done:
    pop rbp
    ret

; Get string length
; Input: RDI = pointer to string
; Output: RAX = length of string
string_length:
    push rbp
    mov rbp, rsp
    
    xor rax, rax
    
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
    
.done:
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

; Copy a string
; Input: RDI = destination, RSI = source
; Output: RDI = pointer to end of destination string
copy_string:
    push rbp
    mov rbp, rsp
    
.loop:
    mov al, [rsi]
    mov [rdi], al
    
    ; Check if we've reached the end of the string
    test al, al
    jz .done
    
    ; Move to next character
    inc rsi
    inc rdi
    jmp .loop
    
.done:
    pop rbp
    ret

section .data
    ; Constants
    MAX_OPEN_FILES equ 16
    
    ; File types
    FILE_TYPE equ 1
    DIR_TYPE equ 2
    
    ; Seek constants
    SEEK_SET equ 0
    SEEK_CUR equ 1
    SEEK_END equ 2
    
    ; Open flags
    O_RDONLY equ 0
    O_WRONLY equ 1
    O_RDWR   equ 2
    O_CREAT  equ 4
    O_EXCL   equ 8
    O_TRUNC  equ 16
    O_APPEND equ 32
    
    ; Current directory
    current_dir dq 0

section .bss
    ; Root directory entry
    root_dir resq 4      ; 32 bytes for header
    root_name resb 2     ; "/" and null terminator
    
    ; File descriptor table
    fd_table resq MAX_OPEN_FILES
    
    ; File position table
    fd_pos_table resq MAX_OPEN_FILES
