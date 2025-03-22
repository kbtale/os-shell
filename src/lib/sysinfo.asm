; sysinfo.asm
; System information module for the x86-64 OS Shell
; Provides functions to query CPU, memory, and other system information

[BITS 64]
[GLOBAL sysinfo_init]
[GLOBAL sysinfo_get_cpu_info]
[GLOBAL sysinfo_get_memory_info]
[GLOBAL sysinfo_get_uptime]
[GLOBAL sysinfo_get_load_avg]
[GLOBAL sysinfo_get_disk_info]

section .text

; External functions
extern memory_copy
extern console_write_string
extern console_write_char

; Initialize system information module
; No input parameters
sysinfo_init:
    push rbp
    mov rbp, rsp
    
    ; Detect CPU information
    call detect_cpu
    
    ; Detect memory information
    call detect_memory
    
    ; Initialize uptime counter
    mov qword [uptime_ticks], 0
    
    pop rbp
    ret

; Get CPU information
; Input: RDI = buffer to store CPU info, RSI = buffer size
; Output: RAX = number of bytes written to buffer
sysinfo_get_cpu_info:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Buffer size
    
    ; Check if buffer is large enough
    cmp r12, cpu_info_size
    jl .buffer_too_small
    
    ; Copy CPU information to buffer
    mov rdi, rbx
    mov rsi, cpu_info
    mov rdx, cpu_info_size
    call memory_copy
    
    ; Return number of bytes written
    mov rax, cpu_info_size
    jmp .done
    
.buffer_too_small:
    ; Buffer is too small, copy as much as possible
    mov rdi, rbx
    mov rsi, cpu_info
    mov rdx, r12
    call memory_copy
    
    ; Return number of bytes written
    mov rax, r12
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Get memory information
; Input: RDI = buffer to store memory info, RSI = buffer size
; Output: RAX = number of bytes written to buffer
sysinfo_get_memory_info:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Buffer size
    
    ; Check if buffer is large enough
    cmp r12, memory_info_size
    jl .buffer_too_small
    
    ; Copy memory information to buffer
    mov rdi, rbx
    mov rsi, memory_info
    mov rdx, memory_info_size
    call memory_copy
    
    ; Return number of bytes written
    mov rax, memory_info_size
    jmp .done
    
.buffer_too_small:
    ; Buffer is too small, copy as much as possible
    mov rdi, rbx
    mov rsi, memory_info
    mov rdx, r12
    call memory_copy
    
    ; Return number of bytes written
    mov rax, r12
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Get system uptime
; Output: RAX = uptime in seconds
sysinfo_get_uptime:
    push rbp
    mov rbp, rsp
    
    ; Convert ticks to seconds (assuming 100 Hz tick rate)
    mov rax, [uptime_ticks]
    mov rcx, 100
    xor rdx, rdx
    div rcx
    
    pop rbp
    ret

; Get system load average
; Input: RDI = buffer to store load averages (3 doubles)
; Output: RAX = number of bytes written to buffer
sysinfo_get_load_avg:
    push rbp
    mov rbp, rsp
    
    ; Copy load averages to buffer
    mov rax, [load_avg]
    mov [rdi], rax
    mov rax, [load_avg + 8]
    mov [rdi + 8], rax
    mov rax, [load_avg + 16]
    mov [rdi + 16], rax
    
    ; Return number of bytes written
    mov rax, 24         ; 3 doubles, 8 bytes each
    
    pop rbp
    ret

; Get disk information
; Input: RDI = buffer to store disk info, RSI = buffer size
; Output: RAX = number of bytes written to buffer
sysinfo_get_disk_info:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Save parameters
    mov rbx, rdi        ; Buffer
    mov r12, rsi        ; Buffer size
    
    ; Check if buffer is large enough
    cmp r12, disk_info_size
    jl .buffer_too_small
    
    ; Copy disk information to buffer
    mov rdi, rbx
    mov rsi, disk_info
    mov rdx, disk_info_size
    call memory_copy
    
    ; Return number of bytes written
    mov rax, disk_info_size
    jmp .done
    
.buffer_too_small:
    ; Buffer is too small, copy as much as possible
    mov rdi, rbx
    mov rsi, disk_info
    mov rdx, r12
    call memory_copy
    
    ; Return number of bytes written
    mov rax, r12
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; Detect CPU information
; No input parameters
detect_cpu:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check CPUID support
    pushfq
    pop rax
    mov rbx, rax
    xor rax, 0x200000   ; Flip ID bit
    push rax
    popfq
    pushfq
    pop rax
    cmp rax, rbx
    je .no_cpuid
    
    ; Get vendor ID
    mov eax, 0
    cpuid
    
    ; Store vendor ID
    mov [cpu_info], ebx
    mov [cpu_info + 4], edx
    mov [cpu_info + 8], ecx
    mov byte [cpu_info + 12], 0
    
    ; Get processor info and feature bits
    mov eax, 1
    cpuid
    
    ; Store processor info
    mov [cpu_info + 16], eax  ; Stepping, model, family
    
    ; Store feature flags
    mov [cpu_info + 20], edx  ; Feature flags
    mov [cpu_info + 24], ecx  ; Extended feature flags
    
    ; Check for extended functions
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .no_brand_string
    
    ; Get processor brand string
    mov eax, 0x80000002
    cpuid
    mov [cpu_info + 32], eax
    mov [cpu_info + 36], ebx
    mov [cpu_info + 40], ecx
    mov [cpu_info + 44], edx
    
    mov eax, 0x80000003
    cpuid
    mov [cpu_info + 48], eax
    mov [cpu_info + 52], ebx
    mov [cpu_info + 56], ecx
    mov [cpu_info + 60], edx
    
    mov eax, 0x80000004
    cpuid
    mov [cpu_info + 64], eax
    mov [cpu_info + 68], ebx
    mov [cpu_info + 72], ecx
    mov [cpu_info + 76], edx
    
    ; Null-terminate brand string
    mov byte [cpu_info + 80], 0
    jmp .done
    
.no_cpuid:
    ; CPUID not supported
    mov rdi, cpu_info
    mov rsi, no_cpuid_str
    call copy_string
    jmp .done
    
.no_brand_string:
    ; Brand string not available
    mov byte [cpu_info + 32], 0
    
.done:
    pop rbx
    pop rbp
    ret

; Detect memory information
; No input parameters
detect_memory:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would use BIOS/UEFI calls
    ; or parse multiboot information to get memory map
    ; For now, we'll use hardcoded values
    
    ; Total memory: 128 MB
    mov qword [memory_info], 128 * 1024 * 1024
    
    ; Free memory: 64 MB
    mov qword [memory_info + 8], 64 * 1024 * 1024
    
    ; Used memory: 64 MB
    mov qword [memory_info + 16], 64 * 1024 * 1024
    
    ; Shared memory: 0
    mov qword [memory_info + 24], 0
    
    ; Buffer/cache memory: 16 MB
    mov qword [memory_info + 32], 16 * 1024 * 1024
    
    ; Available memory: 80 MB
    mov qword [memory_info + 40], 80 * 1024 * 1024
    
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

; Update system uptime (called by timer interrupt handler)
; No input parameters
update_uptime:
    push rbp
    mov rbp, rsp
    
    ; Increment uptime counter
    inc qword [uptime_ticks]
    
    ; Update load averages periodically
    mov rax, [uptime_ticks]
    and rax, 0xFF       ; Every 256 ticks
    jnz .skip_load_update
    
    ; Update load averages
    call update_load_averages
    
.skip_load_update:
    pop rbp
    ret

; Update load averages
; No input parameters
update_load_averages:
    push rbp
    mov rbp, rsp
    
    ; In a real implementation, this would calculate actual system load
    ; For now, we'll use dummy values
    
    ; 1-minute load average
    mov qword [load_avg], 0x3FF0000000000000  ; 1.0 in double
    
    ; 5-minute load average
    mov qword [load_avg + 8], 0x3FF8000000000000  ; 1.5 in double
    
    ; 15-minute load average
    mov qword [load_avg + 16], 0x4000000000000000  ; 2.0 in double
    
    pop rbp
    ret

section .data
    ; CPU information structure
    ; 0-12: Vendor ID string
    ; 16-19: Processor info (stepping, model, family)
    ; 20-23: Feature flags
    ; 24-27: Extended feature flags
    ; 32-79: Processor brand string
    cpu_info_size equ 128
    cpu_info times cpu_info_size db 0
    
    ; Memory information structure
    ; 0-7: Total memory
    ; 8-15: Free memory
    ; 16-23: Used memory
    ; 24-31: Shared memory
    ; 32-39: Buffer/cache memory
    ; 40-47: Available memory
    memory_info_size equ 48
    memory_info times memory_info_size db 0
    
    ; Disk information structure
    ; 0-7: Total disk space
    ; 8-15: Free disk space
    ; 16-23: Used disk space
    disk_info_size equ 24
    disk_info times disk_info_size db 0
    
    ; Strings
    no_cpuid_str db "CPU does not support CPUID", 0
    
    ; System uptime (in ticks)
    uptime_ticks dq 0
    
    ; Load averages (1, 5, and 15 minutes)
    ; Stored as 3 doubles (8 bytes each)
    load_avg times 24 db 0

section .bss
    ; Reserved space for additional information
    sysinfo_reserved resb 256
