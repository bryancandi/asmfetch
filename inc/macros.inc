;=========================================
; macros.inc - Macros
;=========================================

EXTERNDEF stdout:QWORD
EXTERNDEF nbwr:DWORD

; Macro: write a string to the console. addr may be RAX or a label; len is copied into R8D.
StrOut  MACRO   addr, len
        mov     rcx, [stdout]               ; Arg 1: output device handle.
IFIDNI  <addr>, <rax>                       ; If addr is RAX, use it directly; otherwise LEA of the label.
        mov     rdx, rax                    ; Arg 2: pointer to byte array in RAX register.
ELSE
        lea     rdx, addr                   ; Arg 2: pointer to byte array label.
ENDIF
        mov     r8d, len                    ; Arg 3: number of bytes to write.
        lea     r9, nbwr                    ; Arg 4: pointer to variable that receives number of bytes written.
        call    WriteConsoleA
        ENDM
