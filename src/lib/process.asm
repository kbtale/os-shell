; process.asm
; Process management for the x86-64 OS Shell
; Provides functions for creating, managing, and terminating processes

[BITS 64]
[GLOBAL process_init]
[GLOBAL process_create]
[GLOBAL process_exit]
[GLOBAL process_wait]
[GLOBAL process_sleep]
[GLOBAL process_yield]
[GLOBAL process_get_pid]
[GLOBAL process_get_ppid]
[GLOBAL process_list]
[GLOBAL process_kill]
[GLOBAL process_schedule]

section .text

; External functions
extern memory_alloc
extern memory_free
extern memory_copy
extern memory_set
extern console_write_string
extern console_write_char

; Initialize the process management system
; No input parameters
process_init:
    push rbp
    mov rbp, rsp
    
    ; Initialize process table
    mov rdi, process_table
    mov rsi, 0
    mov rdx, MAX_PROCESSES * PROCESS_ENTRY_SIZE
    call memory_set
    
    ; Initialize current process ID
    mov qword [current_pid], 0
    
    ; Create initial process (PID 0, kernel process)
    mov qword [next_pid], 1
    
    ; Mark PID 0 as used
    mov qword [process_table + PROCESS_STATE_OFFSET], PROCESS_STATE_RUNNING
    mov qword [process_table + PROCESS_NAME_OFFSET], kernel_process_name
    
    ; Set up initial process stack
    mov rax, kernel_stack_top
    mov qword [process_table + PROCESS_STACK_OFFSET], rax
    
    pop rbp
    ret

; Create a new process
; Input: RDI = entry point, RSI = pointer to name, RDX = priority
; Output: RAX = process ID or -1 if error
process_create:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Save parameters
    mov rbx, rdi        ; Entry point
    mov r12, rsi        ; Name
    mov r13, rdx        ; Priority
    
    ; Find a free process slot
    call find_free_process
    
    ; Check if we found a free slot
    cmp rax, -1
    je .no_slot
    
    ; Save process ID
    mov r14, rax
    
    ; Calculate process table entry address
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Initialize process entry
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_READY
    mov qword [rax + PROCESS_ENTRY_OFFSET], rbx
    mov qword [rax + PROCESS_PRIORITY_OFFSET], r13
    mov rdx, [current_pid]
    mov qword [rax + PROCESS_PARENT_OFFSET], rdx
    
    ; Copy process name
    mov rdi, [rax + PROCESS_NAME_OFFSET]
    mov rsi, r12
    call copy_string
    
    ; Allocate process stack
    mov rdi, PROCESS_STACK_SIZE
    call memory_alloc
    
    ; Check if stack allocation succeeded
    test rax, rax
    jz .stack_alloc_failed
    
    ; Save stack pointer
    mov rcx, r14
    imul rcx, PROCESS_ENTRY_SIZE
    add rcx, process_table
    mov qword [rcx + PROCESS_STACK_OFFSET], rax
    
    ; Initialize stack for process
    add rax, PROCESS_STACK_SIZE  ; Point to top of stack
    sub rax, 8                   ; Make room for return address
    mov qword [rax], process_exit ; Return address is process_exit
    
    ; Set up initial register values on stack
    sub rax, 128                 ; Space for 16 registers (8 bytes each)
    
    ; Save stack pointer in process entry
    mov qword [rcx + PROCESS_SP_OFFSET], rax
    
    ; Return the process ID
    mov rax, r14
    jmp .done
    
.no_slot:
    ; No free process slot
    mov rax, -1
    jmp .done
    
.stack_alloc_failed:
    ; Stack allocation failed, free process slot
    mov rax, r14
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    
    ; Return error
    mov rax, -1
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Exit the current process
; No input parameters, does not return
process_exit:
    push rbp
    mov rbp, rsp
    
    ; Mark process as terminated
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_TERMINATED
    
    ; Wake up parent if it's waiting
    mov rcx, [rax + PROCESS_PARENT_OFFSET]
    imul rcx, PROCESS_ENTRY_SIZE
    add rcx, process_table
    
    cmp qword [rcx + PROCESS_STATE_OFFSET], PROCESS_STATE_WAITING
    jne .no_parent_waiting
    
    ; Wake up parent
    mov qword [rcx + PROCESS_STATE_OFFSET], PROCESS_STATE_READY
    
.no_parent_waiting:
    ; Schedule next process
    call process_schedule
    
    ; We should never get here
    pop rbp
    ret

; Wait for a child process to terminate
; Input: RDI = process ID to wait for (or -1 for any child)
; Output: RAX = process ID that terminated, or -1 if error
process_wait:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save process ID to wait for
    mov rbx, rdi
    
    ; Check if we have any children
    mov rax, [current_pid]
    call has_children
    
    ; If no children, return error
    test rax, rax
    jz .no_children
    
    ; Check if specific child or any child
    cmp rbx, -1
    je .wait_any
    
    ; Check if specific child exists and is our child
    mov rdi, rbx
    call is_child
    
    ; If not our child, return error
    test rax, rax
    jz .not_our_child
    
    ; Check if child has already terminated
    mov rax, rbx
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_TERMINATED
    je .already_terminated
    
    ; Child is still running, wait for it
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_WAITING
    mov qword [rax + PROCESS_WAITING_OFFSET], rbx
    
    ; Schedule next process
    call process_schedule
    
    ; When we return, the child has terminated
    mov rax, rbx
    jmp .done
    
.wait_any:
    ; Check if any child has already terminated
    mov rdi, -1
    call find_terminated_child
    
    ; If found, return its PID
    cmp rax, -1
    jne .done
    
    ; No terminated children, wait for one
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_WAITING
    mov qword [rax + PROCESS_WAITING_OFFSET], -1
    
    ; Schedule next process
    call process_schedule
    
    ; When we return, a child has terminated
    ; Find which one
    mov rdi, -1
    call find_terminated_child
    jmp .done
    
.already_terminated:
    ; Child has already terminated, return its PID
    mov rax, rbx
    jmp .done
    
.no_children:
.not_our_child:
    ; Error occurred
    mov rax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Sleep for a specified number of ticks
; Input: RDI = number of ticks to sleep
process_sleep:
    push rbp
    mov rbp, rsp
    
    ; Check if sleep time is 0
    test rdi, rdi
    jz .done
    
    ; Set process state to sleeping
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_SLEEPING
    mov qword [rax + PROCESS_SLEEP_OFFSET], rdi
    
    ; Schedule next process
    call process_schedule
    
.done:
    pop rbp
    ret

; Yield the CPU to another process
; No input parameters
process_yield:
    push rbp
    mov rbp, rsp
    
    ; Schedule next process
    call process_schedule
    
    pop rbp
    ret

; Get the current process ID
; Output: RAX = current process ID
process_get_pid:
    mov rax, [current_pid]
    ret

; Get the parent process ID
; Output: RAX = parent process ID
process_get_ppid:
    push rbp
    mov rbp, rsp
    
    ; Get current process entry
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Get parent PID
    mov rax, [rax + PROCESS_PARENT_OFFSET]
    
    pop rbp
    ret

; List all processes
; Input: RDI = buffer to store process list, RSI = buffer size
; Output: RAX = number of processes listed
process_list:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Buffer size
    
    ; Initialize process count
    xor r13, r13        ; Process count
    
    ; Iterate through process table
    xor r14, r14        ; Process index
    
.process_loop:
    ; Check if we've reached the end of the process table
    cmp r14, MAX_PROCESSES
    jge .done
    
    ; Calculate process entry address
    mov rax, r14
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Check if process slot is used
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .next_process
    
    ; Check if buffer has space
    cmp r13, r12
    jge .buffer_full
    
    ; Add process to buffer
    mov rdi, rbx
    
    ; Format: "PID STATE NAME"
    ; Add PID
    mov rsi, r14
    call format_number
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add state
    mov rsi, [rax + PROCESS_STATE_OFFSET]
    call format_state
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add name
    mov rsi, [rax + PROCESS_NAME_OFFSET]
    call copy_string
    
    ; Add newline
    mov byte [rdi], 10  ; Newline
    inc rdi
    
    ; Update buffer pointer
    mov rbx, rdi
    
    ; Increment process count
    inc r13
    
.next_process:
    ; Move to next process
    inc r14
    jmp .process_loop
    
.buffer_full:
    ; Buffer is full, stop listing
    
.done:
    ; Return number of processes listed
    mov rax, r13
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Kill a process
; Input: RDI = process ID to kill
; Output: RAX = 0 on success, -1 on error
process_kill:
    push rbp
    mov rbp, rsp
    
    ; Check if process ID is valid
    cmp rdi, 0
    jl .invalid_pid
    cmp rdi, MAX_PROCESSES
    jge .invalid_pid
    
    ; Check if process exists
    imul rax, rdi, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .process_not_found
    
    ; Can't kill the kernel process (PID 0)
    test rdi, rdi
    jz .cant_kill_kernel
    
    ; Mark process as terminated
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_TERMINATED
    
    ; Wake up parent if it's waiting
    mov rcx, [rax + PROCESS_PARENT_OFFSET]
    imul rcx, PROCESS_ENTRY_SIZE
    add rcx, process_table
    
    cmp qword [rcx + PROCESS_STATE_OFFSET], PROCESS_STATE_WAITING
    jne .no_parent_waiting
    
    mov rdx, [rcx + PROCESS_WAITING_OFFSET]
    
    ; Check if parent is waiting for this specific process
    cmp rdx, rdi
    je .wake_parent
    
    ; Check if parent is waiting for any child
    cmp rdx, -1
    jne .no_parent_waiting
    
.wake_parent:
    ; Wake up parent
    mov qword [rcx + PROCESS_STATE_OFFSET], PROCESS_STATE_READY
    
.no_parent_waiting:
    ; Free process resources
    mov rdi, [rax + PROCESS_STACK_OFFSET]
    call memory_free
    
    ; Mark process slot as unused
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    
    ; Success
    xor rax, rax
    jmp .done
    
.invalid_pid:
.process_not_found:
.cant_kill_kernel:
    ; Error occurred
    mov rax, -1
    
.done:
    pop rbp
    ret

; Schedule the next process to run
; No input parameters
process_schedule:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save current process state
    mov rax, [current_pid]
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Save stack pointer
    mov [rax + PROCESS_SP_OFFSET], rsp
    
    ; Find next process to run
    call find_next_process
    
    ; Check if we found a process
    cmp rax, -1
    je .no_process
    
    ; Update current process ID
    mov [current_pid], rax
    
    ; Get process entry
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Set process state to running
    mov qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_RUNNING
    
    ; Restore stack pointer
    mov rsp, [rax + PROCESS_SP_OFFSET]
    
    ; Return to the process
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.no_process:
    ; No process to run, halt the system
    cli
    hlt

; Find a free process slot
; Output: RAX = process ID or -1 if no slots available
find_free_process:
    push rbp
    mov rbp, rsp
    
    ; Start with next_pid
    mov rax, [next_pid]
    mov rcx, 0          ; Counter
    
.find_loop:
    ; Check if we've checked all processes
    cmp rcx, MAX_PROCESSES
    jge .no_slot
    
    ; Check if this slot is free
    push rax
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    pop rax
    je .found_slot
    
    ; Try next slot
    inc rax
    cmp rax, MAX_PROCESSES
    jl .no_wrap
    xor rax, rax        ; Wrap around to 0
    
.no_wrap:
    inc rcx
    jmp .find_loop
    
.found_slot:
    ; Update next_pid
    mov rcx, rax
    inc rcx
    cmp rcx, MAX_PROCESSES
    jl .no_wrap_next
    xor rcx, rcx        ; Wrap around to 0
    
.no_wrap_next:
    mov [next_pid], rcx
    jmp .done
    
.no_slot:
    ; No free slots
    mov rax, -1
    
.done:
    pop rbp
    ret

; Find the next process to run
; Output: RAX = process ID or -1 if no process is ready
find_next_process:
    push rbp
    mov rbp, rsp
    
    ; Start with current process
    mov rax, [current_pid]
    inc rax
    cmp rax, MAX_PROCESSES
    jl .no_wrap
    xor rax, rax        ; Wrap around to 0
    
.no_wrap:
    mov rcx, 0          ; Counter
    
.find_loop:
    ; Check if we've checked all processes
    cmp rcx, MAX_PROCESSES
    jge .no_process
    
    ; Check if this process is ready
    push rax
    imul rax, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_READY
    pop rax
    je .found_process
    
    ; Try next process
    inc rax
    cmp rax, MAX_PROCESSES
    jl .no_wrap2
    xor rax, rax        ; Wrap around to 0
    
.no_wrap2:
    inc rcx
    jmp .find_loop
    
.found_process:
    ; Return the process ID
    jmp .done
    
.no_process:
    ; No process is ready, return kernel process
    xor rax, rax
    
.done:
    pop rbp
    ret

; Check if a process has any children
; Input: RAX = process ID
; Output: RAX = 1 if process has children, 0 otherwise
has_children:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save process ID
    mov rbx, rax
    
    ; Iterate through process table
    xor rcx, rcx
    
.check_loop:
    ; Check if we've checked all processes
    cmp rcx, MAX_PROCESSES
    jge .no_children
    
    ; Skip the process itself
    cmp rcx, rbx
    je .next_process
    
    ; Check if this process is used
    imul rax, rcx, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .next_process
    
    ; Check if this process is a child of the specified process
    cmp qword [rax + PROCESS_PARENT_OFFSET], rbx
    je .has_children
    
.next_process:
    ; Check next process
    inc rcx
    jmp .check_loop
    
.has_children:
    ; Process has children
    mov rax, 1
    jmp .done
    
.no_children:
    ; Process has no children
    xor rax, rax
    
.done:
    pop rbx
    pop rbp
    ret

; Check if a process is a child of the current process
; Input: RDI = process ID
; Output: RAX = 1 if process is a child, 0 otherwise
is_child:
    push rbp
    mov rbp, rsp
    
    ; Check if process ID is valid
    cmp rdi, 0
    jl .not_child
    cmp rdi, MAX_PROCESSES
    jge .not_child
    
    ; Check if process exists
    imul rax, rdi, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .not_child
    
    ; Check if parent is current process
    mov rcx, [current_pid]
    cmp qword [rax + PROCESS_PARENT_OFFSET], rcx
    jne .not_child
    
    ; Process is a child
    mov rax, 1
    jmp .done
    
.not_child:
    ; Process is not a child
    xor rax, rax
    
.done:
    pop rbp
    ret

; Find a terminated child of the current process
; Input: RDI = specific child PID or -1 for any child
; Output: RAX = process ID of terminated child or -1 if none found
find_terminated_child:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save specific child PID
    mov rbx, rdi
    
    ; Check if looking for specific child
    cmp rbx, -1
    jne .specific_child
    
    ; Looking for any terminated child
    xor rcx, rcx
    
.check_loop:
    ; Check if we've checked all processes
    cmp rcx, MAX_PROCESSES
    jge .not_found
    
    ; Check if this process is used
    imul rax, rcx, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .next_process
    
    ; Check if this process is a child of the current process
    mov rdx, [current_pid]
    cmp qword [rax + PROCESS_PARENT_OFFSET], rdx
    jne .next_process
    
    ; Check if this process is terminated
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_TERMINATED
    jne .next_process
    
    ; Found a terminated child
    mov rax, rcx
    jmp .done
    
.next_process:
    ; Check next process
    inc rcx
    jmp .check_loop
    
.specific_child:
    ; Check if specific child exists and is terminated
    imul rax, rbx, PROCESS_ENTRY_SIZE
    add rax, process_table
    
    ; Check if process exists
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_UNUSED
    je .not_found
    
    ; Check if process is a child of the current process
    mov rdx, [current_pid]
    cmp qword [rax + PROCESS_PARENT_OFFSET], rdx
    jne .not_found
    
    ; Check if process is terminated
    cmp qword [rax + PROCESS_STATE_OFFSET], PROCESS_STATE_TERMINATED
    jne .not_found
    
    ; Found the terminated child
    mov rax, rbx
    jmp .done
    
.not_found:
    ; No terminated child found
    mov rax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Format a number as a string
; Input: RDI = destination buffer, RSI = number
; Output: RDI = pointer to end of string
format_number:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Check if number is 0
    test rsi, rsi
    jnz .not_zero
    
    ; Number is 0
    mov byte [rdi], '0'
    inc rdi
    jmp .done
    
.not_zero:
    ; Convert number to string
    mov rax, rsi
    mov rbx, 10         ; Base 10
    mov rcx, 0          ; Digit count
    
    ; Buffer for digits (in reverse order)
    sub rsp, 32
    mov rdx, rsp
    
.convert_loop:
    ; Divide by 10
    xor rdx, rdx
    div rbx
    
    ; Convert remainder to ASCII
    add dl, '0'
    
    ; Store digit
    mov [rsp + rcx], dl
    inc rcx
    
    ; Check if we're done
    test rax, rax
    jnz .convert_loop
    
    ; Copy digits in reverse order
    dec rcx
    
.copy_loop:
    mov al, [rsp + rcx]
    mov [rdi], al
    inc rdi
    dec rcx
    jns .copy_loop
    
    ; Clean up
    add rsp, 32
    
.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret

; Format process state as a string
; Input: RDI = destination buffer, RSI = state
; Output: RDI = pointer to end of string
format_state:
    push rbp
    mov rbp, rsp
    push rax
    push rsi
    
    ; Check state and copy appropriate string
    cmp rsi, PROCESS_STATE_UNUSED
    je .unused
    cmp rsi, PROCESS_STATE_READY
    je .ready
    cmp rsi, PROCESS_STATE_RUNNING
    je .running
    cmp rsi, PROCESS_STATE_SLEEPING
    je .sleeping
    cmp rsi, PROCESS_STATE_WAITING
    je .waiting
    cmp rsi, PROCESS_STATE_TERMINATED
    je .terminated
    
    ; Unknown state
    mov rsi, state_unknown
    jmp .copy
    
.unused:
    mov rsi, state_unused
    jmp .copy
    
.ready:
    mov rsi, state_ready
    jmp .copy
    
.running:
    mov rsi, state_running
    jmp .copy
    
.sleeping:
    mov rsi, state_sleeping
    jmp .copy
    
.waiting:
    mov rsi, state_waiting
    jmp .copy
    
.terminated:
    mov rsi, state_terminated
    
.copy:
    ; Copy state string
    call copy_string
    
    pop rsi
    pop rax
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

section .data
    ; Constants
    MAX_PROCESSES equ 64
    PROCESS_ENTRY_SIZE equ 128
    PROCESS_STACK_SIZE equ 16384  ; 16 KB
    
    ; Process state constants
    PROCESS_STATE_UNUSED     equ 0
    PROCESS_STATE_READY      equ 1
    PROCESS_STATE_RUNNING    equ 2
    PROCESS_STATE_SLEEPING   equ 3
    PROCESS_STATE_WAITING    equ 4
    PROCESS_STATE_TERMINATED equ 5
    
    ; Process entry offsets
    PROCESS_STATE_OFFSET    equ 0
    PROCESS_ENTRY_OFFSET    equ 8
    PROCESS_STACK_OFFSET    equ 16
    PROCESS_SP_OFFSET       equ 24
    PROCESS_PRIORITY_OFFSET equ 32
    PROCESS_PARENT_OFFSET   equ 40
    PROCESS_SLEEP_OFFSET    equ 48
    PROCESS_WAITING_OFFSET  equ 56
    PROCESS_NAME_OFFSET     equ 64
    
    ; State strings
    state_unused     db "UNUSED", 0
    state_ready      db "READY", 0
    state_running    db "RUNNING", 0
    state_sleeping   db "SLEEPING", 0
    state_waiting    db "WAITING", 0
    state_terminated db "TERMINATED", 0
    state_unknown    db "UNKNOWN", 0
    
    ; Kernel process name
    kernel_process_name db "kernel", 0
    
    ; Current process ID
    current_pid dq 0
    
    ; Next process ID to allocate
    next_pid dq 1

section .bss
    ; Process table (64 entries, 128 bytes each)
    process_table resb MAX_PROCESSES * PROCESS_ENTRY_SIZE
    
    ; Kernel stack
    align 16
    kernel_stack_bottom:
    resb 16384            ; 16 KB stack
    kernel_stack_top:
