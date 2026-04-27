;=========================================
; memory.asm - Memory Functions
;=========================================

;=========================================
; Includes
;=========================================

INCLUDE structs.inc
INCLUDE winapi.inc

        .DATA
; Initialize structure
msEx            MEMORYSTATUSEX <>

        .CODE
; Returns: RAX = size of total physical memory in bytes (QWORD).
;          RDX = size of available physical memory in bytes (QWORD).
;          R8D = memory load percentage (DWORD).
GetMemory PROC
        mov     msEx.dwLength, SIZEOF MEMORYSTATUSEX
        lea     rcx, msEx
        call    GlobalMemoryStatusEx        ; Fills MEMORYSTATUSEX struct (after dwLength is set and RCX = pointer).

        test    rax, rax                    ; nz = success; 0 = failure
        jz      @fail

        mov     rax, msEx.ullTotalPhys      ; Load QWORD from struct (total RAM).
        mov     rdx, msEx.ullAvailPhys      ; Load QWORD from struct (available RAM).
        mov     r8d, msEx.dwMemoryLoad      ; Load DWORD from struct (memory load percentage).
        ret

@fail:
        xor     rax, rax                    ; Fail = return zeros.
        xor     rdx, rdx
        xor     r8, r8
        ret
GetMemory ENDP
        END
