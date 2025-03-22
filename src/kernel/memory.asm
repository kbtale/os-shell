; memory.asm
; Memory management for the x86-64 OS Shell
; Provides functions for memory allocation, deallocation, and management

[BITS 64]
[GLOBAL memory_init]
[GLOBAL memory_alloc]
[GLOBAL memory_free]
[GLOBAL memory_copy]
[GLOBAL memory_set]

; Constants
HEAP_START  equ 0x1000000      ; 16 MB mark
HEAP_END    equ 0x2000000      ; 32 MB mark (16 MB heap)

section .text

; Initialize memory management system
; No input parameters
memory_init:
    push rbp
    mov rbp, rsp
    
    ; Initialize memory manager data structures
    mov qword [heap_start], HEAP_START
    mov qword [heap_end], HEAP_END
    mov qword [heap_current], HEAP_START
    
    ; Initialize the first free block to cover the entire heap
    mov rdi, free_list
    mov qword [rdi], HEAP_START     ; Address
    mov rax, HEAP_END
    sub rax, HEAP_START
    mov qword [rdi + 8], rax        ; Size
    mov qword [rdi + 16], 0         ; Next (null)
    
    ; Set the free list head
    mov qword [free_list_head], free_list
    
    pop rbp
    ret

; Allocate memory
; Input: RDI = size in bytes
; Output: RAX = pointer to allocated memory or 0 if failed
memory_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rsi
    
    ; Align size to 16 bytes (x86-64 standard)
    add rdi, 15
    and rdi, ~15
    
    ; Add header size (16 bytes for size and magic)
    add rdi, 16
    
    ; Find a free block that's large enough
    mov rsi, [free_list_head]
    mov rdx, 0          ; Previous block pointer
    
.find_block:
    test rsi, rsi
    jz .no_memory       ; End of list, no suitable block found
    
    ; Check if this block is large enough
    cmp qword [rsi + 8], rdi
    jge .block_found
    
    ; Move to next block
    mov rdx, rsi
    mov rsi, [rsi + 16]
    jmp .find_block
    
.block_found:
    ; We found a block, now determine if we should split it
    mov rax, [rsi + 8]      ; Block size
    sub rax, rdi            ; Remaining size after allocation
    
    cmp rax, 32             ; If remaining size is too small, don't split
    jl .use_entire_block
    
    ; Split the block
    mov rbx, [rsi]          ; Original block address
    add rbx, rdi            ; Address of the new free block
    
    ; Update the current block size
    mov qword [rsi + 8], rdi
    
    ; Create a new free block with the remaining space
    mov rcx, [free_list_count]
    imul rcx, 24            ; Each entry is 24 bytes
    add rcx, free_list      ; Address of new free list entry
    
    mov qword [rcx], rbx           ; Address
    mov qword [rcx + 8], rax       ; Size
    mov rdx, [rsi + 16]            ; Load the next pointer value
    mov qword [rcx + 16], rdx      ; Store it in the new block
    
    ; Update the next pointer of the current block
    mov qword [rsi + 16], rcx
    
    ; Increment free list count
    inc qword [free_list_count]
    
    jmp .allocate_block
    
.use_entire_block:
    ; Use the entire block without splitting
    
.allocate_block:
    ; Get the address of the block
    mov rax, [rsi]
    
    ; Remove the block from the free list
    test rdx, rdx
    jz .remove_head
    
    ; Not the head, update previous block's next pointer
    mov rbx, [rsi + 16]
    mov qword [rdx + 16], rbx
    jmp .setup_header
    
.remove_head:
    ; Removing the head block, update free_list_head
    mov rbx, [rsi + 16]
    mov qword [free_list_head], rbx
    
.setup_header:
    ; Set up the allocation header
    mov rbx, [rsi + 8]      ; Size
    mov qword [rax], rbx    ; Store size at the beginning of the block
    mov rbx, 0x1234567890ABCDEF  ; Magic number for allocated blocks
    mov qword [rax + 8], rbx     ; Store magic number
    
    ; Return pointer to the usable memory (after header)
    add rax, 16
    jmp .done
    
.no_memory:
    ; Return null if no suitable block found
    xor rax, rax
    
.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Free allocated memory
; Input: RDI = pointer to memory to free
; No output
memory_free:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Check if pointer is valid
    test rdi, rdi
    jz .done
    
    ; Adjust pointer to get to the header
    sub rdi, 16
    
    ; Verify magic number
    cmp qword [rdi + 8], 0x1234567890ABCDEF
    jne .invalid_free
    
    ; Get block size
    mov rbx, [rdi]
    
    ; Add block to free list
    mov rcx, [free_list_count]
    imul rcx, 24            ; Each entry is 24 bytes
    add rcx, free_list      ; Address of new free list entry
    
    mov qword [rcx], rdi           ; Address
    mov qword [rcx + 8], rbx       ; Size
    mov rdx, [free_list_head]      ; Load the free list head value
    mov qword [rcx + 16], rdx      ; Store it in the new block
    
    ; Update free list head
    mov qword [free_list_head], rcx
    
    ; Increment free list count
    inc qword [free_list_count]
    
    ; TODO: Coalesce adjacent free blocks (merge them)
    ; This would make the allocator more efficient but is omitted for simplicity
    
    jmp .done
    
.invalid_free:
    ; Handle invalid free attempt (could log error or panic)
    ; For now, just ignore it
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Copy memory from source to destination
; Input: RDI = destination, RSI = source, RDX = size
; No output
memory_copy:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Check if source and destination overlap
    mov rax, rdi
    sub rax, rsi
    cmp rax, rdx
    jb .backward_copy
    
    ; Forward copy (source before destination or no overlap)
    mov rcx, rdx
    shr rcx, 3          ; Divide by 8 to get number of quadwords
    rep movsq           ; Copy quadwords
    
    ; Copy remaining bytes
    mov rcx, rdx
    and rcx, 7
    rep movsb
    jmp .done
    
.backward_copy:
    ; Backward copy (source after destination)
    add rdi, rdx
    dec rdi
    add rsi, rdx
    dec rsi
    
    std                 ; Set direction flag for backward copy
    
    mov rcx, rdx
    rep movsb           ; Copy bytes backward
    
    cld                 ; Clear direction flag
    
.done:
    pop rcx
    pop rbp
    ret

; Set memory to a specific value
; Input: RDI = destination, RSI = value (byte), RDX = size
; No output
memory_set:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    
    ; Expand byte value to fill RAX
    mov al, sil
    mov ah, al
    mov rsi, rax
    shl rsi, 16
    or rsi, rax
    shl rsi, 32
    or rsi, rax
    
    ; Set memory using quadwords for speed
    mov rcx, rdx
    shr rcx, 3          ; Divide by 8 to get number of quadwords
    mov rax, rsi
    rep stosq           ; Store quadwords
    
    ; Set remaining bytes
    mov rcx, rdx
    and rcx, 7
    mov al, sil
    rep stosb           ; Store bytes
    
    pop rcx
    pop rax
    pop rbp
    ret

section .data
    ; Memory manager state
    heap_start  dq HEAP_START
    heap_end    dq HEAP_END
    heap_current dq HEAP_START
    free_list_head dq 0
    free_list_count dq 1
    magic_alloc dq 0x1234567890ABCDEF  ; Magic number for allocated blocks

section .bss
    ; Free list entries: [address (8 bytes), size (8 bytes), next (8 bytes)]
    free_list resb 24 * 1024  ; Support up to 1024 free blocks
