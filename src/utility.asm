;=========================================
; utility.asm - Utility Functions
;=========================================

INCLUDE const.inc

        .CODE
; Convert integer in RAX to ASCII string in buffer pointed to by RDI; digits are stored in reverse order.
Int2Str PROC
        push    rbx                         ; Preserve RBX register.

        mov     rbx, 10                     ; Divisor (10)
        xor     r8d, r8d                    ; Initial string length = 0

@loop:
        xor     rdx, rdx                    ; Clear RDX for division.
        div     rbx                         ; RAX = quotient, RDX = remainder.
        add     dl, '0'                     ; Remainder to ASCII digit.
        dec     rdi
        mov     [rdi], dl                   ; Store digit.
        inc     r8d                         ; Length + 1
        test    rax, rax
        jnz     @loop

        mov     rax, rdi                    ; Return pointer to first digit.

        pop     rbx                         ; Restore RBX.
        ret
Int2Str ENDP

; Convert bytes in RAX to GiB.
; Returns: RAX = whole portion of result.
;          RDX = fractional portion of result.
Byte2GiB PROC
        ; RAX = bytes
        xor     rdx, rdx
        mov     r8, BytesPerGib             ; R8 = 1 GiB in bytes.
        div     r8                          ; RAX = RAX/R8, RDX = remainder.

        ; RAX = whole portion of result, RDX = fractional portion of result.
        mov     r10, rax                    ; Store whole portion temporarily.

        ; Scale remainder to 2 decimal digits: (remainder * 100) / GiB
        mov     rax, rdx                    ; Move remainder into RAX.
        mov     r8, 100
        mul     r8                          ; Multiply by 100 to convert fractional GiB into a 2-digit integer (shift decimal right).
        mov     r8, BytesPerGib
        div     r8                          ; (remainder * 100) / GiB
        mov     rdx, rax                    ; Store fractional portion in RDX.
        mov     rax, r10                    ; Move whole portion back into RAX.

        ret
Byte2GiB ENDP
        END
