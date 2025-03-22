; drivers.asm
; Device driver management for the x86-64 OS Shell
; Provides functions for registering and using device drivers

[BITS 64]
[GLOBAL drivers_init]
[GLOBAL driver_register]
[GLOBAL driver_unregister]
[GLOBAL driver_find]
[GLOBAL driver_open]
[GLOBAL driver_close]
[GLOBAL driver_read]
[GLOBAL driver_write]
[GLOBAL driver_ioctl]

section .text

; External functions
extern memory_alloc
extern memory_free
extern memory_copy
extern utils_strcmp
extern console_write_string

; Initialize driver management
; No input parameters
drivers_init:
    push rbp
    mov rbp, rsp
    
    ; Initialize driver table
    mov qword [driver_count], 0
    
    ; Register built-in drivers
    call register_builtin_drivers
    
    pop rbp
    ret

; Register a new driver
; Input: RDI = driver name, RSI = driver operations structure
; Output: RAX = 0 on success, -1 on error
driver_register:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Driver name
    mov r12, rsi        ; Driver operations
    
    ; Check if driver table is full
    mov rax, [driver_count]
    cmp rax, MAX_DRIVERS
    jge .table_full
    
    ; Check if driver already exists
    mov rdi, rbx
    call driver_find
    
    ; If driver exists, return error
    cmp rax, -1
    jne .already_exists
    
    ; Calculate driver entry address
    mov rax, [driver_count]
    imul r13, rax, DRIVER_ENTRY_SIZE
    add r13, driver_table
    
    ; Copy driver name
    mov rdi, driver_name_buffer
    mov rsi, rbx
    call copy_string
    
    ; Store driver entry
    mov qword [r13 + DRIVER_NAME_OFFSET], driver_name_buffer
    mov qword [r13 + DRIVER_OPS_OFFSET], r12
    
    ; Increment driver count
    inc qword [driver_count]
    
    ; Success
    xor rax, rax
    jmp .done
    
.table_full:
.already_exists:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Unregister a driver
; Input: RDI = driver name
; Output: RAX = 0 on success, -1 on error
driver_unregister:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Find driver
    call driver_find
    
    ; Check if driver exists
    cmp rax, -1
    je .not_found
    
    ; Save driver index
    mov rbx, rax
    
    ; Calculate driver entry address
    imul r12, rbx, DRIVER_ENTRY_SIZE
    add r12, driver_table
    
    ; Check if this is the last driver
    mov rax, [driver_count]
    dec rax
    cmp rbx, rax
    je .last_driver
    
    ; Move last driver to this slot
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Copy driver entry
    mov rdi, r12
    mov rsi, rax
    mov rdx, DRIVER_ENTRY_SIZE
    call memory_copy
    
.last_driver:
    ; Decrement driver count
    dec qword [driver_count]
    
    ; Success
    xor rax, rax
    jmp .done
    
.not_found:
    ; Driver not found
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Find a driver by name
; Input: RDI = driver name
; Output: RAX = driver index or -1 if not found
driver_find:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save driver name
    mov rbx, rdi
    
    ; Iterate through driver table
    xor r12, r12
    
.find_loop:
    ; Check if we've checked all drivers
    cmp r12, [driver_count]
    jge .not_found
    
    ; Calculate driver entry address
    mov rax, r12
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Compare driver name
    mov rdi, rbx
    mov rsi, [rax + DRIVER_NAME_OFFSET]
    call utils_strcmp
    
    ; Check if names match
    test rax, rax
    jz .found
    
    ; Check next driver
    inc r12
    jmp .find_loop
    
.found:
    ; Return driver index
    mov rax, r12
    jmp .done
    
.not_found:
    ; Driver not found
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Open a device
; Input: RDI = driver name, RSI = device path, RDX = flags
; Output: RAX = device handle or -1 on error
driver_open:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Driver name
    mov r12, rsi        ; Device path
    mov r13, rdx        ; Flags
    
    ; Find driver
    mov rdi, rbx
    call driver_find
    
    ; Check if driver exists
    cmp rax, -1
    je .not_found
    
    ; Calculate driver entry address
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Get driver operations
    mov rax, [rax + DRIVER_OPS_OFFSET]
    
    ; Check if open operation is supported
    cmp qword [rax + DRIVER_OPEN_OFFSET], 0
    je .not_supported
    
    ; Call driver open function
    mov rdi, r12        ; Device path
    mov rsi, r13        ; Flags
    call [rax + DRIVER_OPEN_OFFSET]
    
    ; Return device handle
    jmp .done
    
.not_found:
.not_supported:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Close a device
; Input: RDI = device handle
; Output: RAX = 0 on success, -1 on error
driver_close:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save device handle
    mov rbx, rdi
    
    ; Get driver from device handle
    mov rax, rdi
    shr rax, 48         ; Extract driver index
    
    ; Check if driver index is valid
    cmp rax, [driver_count]
    jge .invalid_handle
    
    ; Calculate driver entry address
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Get driver operations
    mov rax, [rax + DRIVER_OPS_OFFSET]
    
    ; Check if close operation is supported
    cmp qword [rax + DRIVER_CLOSE_OFFSET], 0
    je .not_supported
    
    ; Call driver close function
    mov rdi, rbx        ; Device handle
    call [rax + DRIVER_CLOSE_OFFSET]
    
    ; Return status
    jmp .done
    
.invalid_handle:
.not_supported:
    ; Error occurred
    mov rax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Read from a device
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes read or -1 on error
driver_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Device handle
    mov r12, rsi        ; Buffer
    mov r13, rdx        ; Count
    
    ; Get driver from device handle
    mov rax, rdi
    shr rax, 48         ; Extract driver index
    
    ; Check if driver index is valid
    cmp rax, [driver_count]
    jge .invalid_handle
    
    ; Calculate driver entry address
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Get driver operations
    mov rax, [rax + DRIVER_OPS_OFFSET]
    
    ; Check if read operation is supported
    cmp qword [rax + DRIVER_READ_OFFSET], 0
    je .not_supported
    
    ; Call driver read function
    mov rdi, rbx        ; Device handle
    mov rsi, r12        ; Buffer
    mov rdx, r13        ; Count
    call [rax + DRIVER_READ_OFFSET]
    
    ; Return bytes read
    jmp .done
    
.invalid_handle:
.not_supported:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Write to a device
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes written or -1 on error
driver_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Device handle
    mov r12, rsi        ; Buffer
    mov r13, rdx        ; Count
    
    ; Get driver from device handle
    mov rax, rdi
    shr rax, 48         ; Extract driver index
    
    ; Check if driver index is valid
    cmp rax, [driver_count]
    jge .invalid_handle
    
    ; Calculate driver entry address
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Get driver operations
    mov rax, [rax + DRIVER_OPS_OFFSET]
    
    ; Check if write operation is supported
    cmp qword [rax + DRIVER_WRITE_OFFSET], 0
    je .not_supported
    
    ; Call driver write function
    mov rdi, rbx        ; Device handle
    mov rsi, r12        ; Buffer
    mov rdx, r13        ; Count
    call [rax + DRIVER_WRITE_OFFSET]
    
    ; Return bytes written
    jmp .done
    
.invalid_handle:
.not_supported:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Perform I/O control operation on a device
; Input: RDI = device handle, RSI = request, RDX = arg
; Output: RAX = result or -1 on error
driver_ioctl:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save parameters
    mov rbx, rdi        ; Device handle
    mov r12, rsi        ; Request
    mov r13, rdx        ; Arg
    
    ; Get driver from device handle
    mov rax, rdi
    shr rax, 48         ; Extract driver index
    
    ; Check if driver index is valid
    cmp rax, [driver_count]
    jge .invalid_handle
    
    ; Calculate driver entry address
    imul rax, DRIVER_ENTRY_SIZE
    add rax, driver_table
    
    ; Get driver operations
    mov rax, [rax + DRIVER_OPS_OFFSET]
    
    ; Check if ioctl operation is supported
    cmp qword [rax + DRIVER_IOCTL_OFFSET], 0
    je .not_supported
    
    ; Call driver ioctl function
    mov rdi, rbx        ; Device handle
    mov rsi, r12        ; Request
    mov rdx, r13        ; Arg
    call [rax + DRIVER_IOCTL_OFFSET]
    
    ; Return result
    jmp .done
    
.invalid_handle:
.not_supported:
    ; Error occurred
    mov rax, -1
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Register built-in drivers
; No input parameters
register_builtin_drivers:
    push rbp
    mov rbp, rsp
    
    ; Register console driver
    mov rdi, console_driver_name
    mov rsi, console_driver_ops
    call driver_register
    
    ; Register keyboard driver
    mov rdi, keyboard_driver_name
    mov rsi, keyboard_driver_ops
    call driver_register
    
    ; Register disk driver
    mov rdi, disk_driver_name
    mov rsi, disk_driver_ops
    call driver_register
    
    pop rbp
    ret

; Copy a string
; Input: RDI = destination, RSI = source
; Output: RDI = pointer to end of destination string
copy_string:
    push rbp
    mov rbp, rsp
    push rax
    
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
    pop rax
    pop rbp
    ret

; Console driver operations

; Open console device
; Input: RDI = device path, RSI = flags
; Output: RAX = device handle or -1 on error
console_open:
    push rbp
    mov rbp, rsp
    
    ; Create device handle (driver index in high 16 bits)
    xor rax, rax
    mov ax, 0           ; Console driver index
    shl rax, 48
    or rax, 1           ; Device instance 1
    
    pop rbp
    ret

; Close console device
; Input: RDI = device handle
; Output: RAX = 0 on success, -1 on error
console_close:
    push rbp
    mov rbp, rsp
    
    ; Nothing to do
    xor rax, rax
    
    pop rbp
    ret

; Read from console
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes read or -1 on error
console_read:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would read from the console
    ; For now, just return 0 bytes read
    xor rax, rax
    
    pop rbp
    ret

; Write to console
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes written or -1 on error
console_write:
    push rbp
    mov rbp, rsp
    
    ; Write to console
    push rdi
    mov rdi, rsi
    call console_write_string
    pop rdi
    
    ; Return bytes written
    mov rax, rdx
    
    pop rbp
    ret

; Keyboard driver operations

; Open keyboard device
; Input: RDI = device path, RSI = flags
; Output: RAX = device handle or -1 on error
keyboard_open:
    push rbp
    mov rbp, rsp
    
    ; Create device handle (driver index in high 16 bits)
    xor rax, rax
    mov ax, 1           ; Keyboard driver index
    shl rax, 48
    or rax, 1           ; Device instance 1
    
    pop rbp
    ret

; Close keyboard device
; Input: RDI = device handle
; Output: RAX = 0 on success, -1 on error
keyboard_close:
    push rbp
    mov rbp, rsp
    
    ; Nothing to do
    xor rax, rax
    
    pop rbp
    ret

; Read from keyboard
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes read or -1 on error
keyboard_read:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would read from the keyboard buffer
    ; For now, just return 0 bytes read
    xor rax, rax
    
    pop rbp
    ret

; Disk driver operations

; Open disk device
; Input: RDI = device path, RSI = flags
; Output: RAX = device handle or -1 on error
disk_open:
    push rbp
    mov rbp, rsp
    
    ; Create device handle (driver index in high 16 bits)
    xor rax, rax
    mov ax, 2           ; Disk driver index
    shl rax, 48
    or rax, 1           ; Device instance 1
    
    pop rbp
    ret

; Close disk device
; Input: RDI = device handle
; Output: RAX = 0 on success, -1 on error
disk_close:
    push rbp
    mov rbp, rsp
    
    ; Nothing to do
    xor rax, rax
    
    pop rbp
    ret

; Read from disk
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes read or -1 on error
disk_read:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would read from the disk
    ; For now, just return 0 bytes read
    xor rax, rax
    
    pop rbp
    ret

; Write to disk
; Input: RDI = device handle, RSI = buffer, RDX = count
; Output: RAX = bytes written or -1 on error
disk_write:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would write to the disk
    ; For now, just return 0 bytes written
    xor rax, rax
    
    pop rbp
    ret

; Perform I/O control operation on disk
; Input: RDI = device handle, RSI = request, RDX = arg
; Output: RAX = result or -1 on error
disk_ioctl:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would perform disk I/O control
    ; For now, just return error
    mov rax, -1
    
    pop rbp
    ret

section .data
    ; Constants
    MAX_DRIVERS equ 16
    DRIVER_ENTRY_SIZE equ 32
    
    ; Driver entry offsets
    DRIVER_NAME_OFFSET equ 0
    DRIVER_OPS_OFFSET equ 8
    
    ; Driver operations offsets
    DRIVER_OPEN_OFFSET equ 0
    DRIVER_CLOSE_OFFSET equ 8
    DRIVER_READ_OFFSET equ 16
    DRIVER_WRITE_OFFSET equ 24
    DRIVER_IOCTL_OFFSET equ 32
    
    ; Driver count
    driver_count dq 0
    
    ; Driver names
    console_driver_name db "console", 0
    keyboard_driver_name db "keyboard", 0
    disk_driver_name db "disk", 0
    
    ; Driver operations
    console_driver_ops:
    dq console_open     ; open
    dq console_close    ; close
    dq console_read     ; read
    dq console_write    ; write
    dq 0                ; ioctl
    
    keyboard_driver_ops:
    dq keyboard_open    ; open
    dq keyboard_close   ; close
    dq keyboard_read    ; read
    dq 0                ; write
    dq 0                ; ioctl
    
    disk_driver_ops:
    dq disk_open        ; open
    dq disk_close       ; close
    dq disk_read        ; read
    dq disk_write       ; write
    dq disk_ioctl       ; ioctl

section .bss
    ; Driver table (16 entries, 32 bytes each)
    driver_table resb MAX_DRIVERS * DRIVER_ENTRY_SIZE
    
    ; Driver name buffer (256 bytes per name, 16 names)
    driver_name_buffer resb 256 * MAX_DRIVERS
