;=========================================
; cpu.asm - Processor Functions
;=========================================

INCLUDE const.inc
INCLUDE globals.inc
INCLUDE structs.inc
INCLUDE winapi.inc

        .DATA
sysInf          SYSTEM_INFO <>              ; Initialize structure
cpubuf          DWORD   MaxBuf DUP (?)      ; CPU strings buffer.
cpu_x86         BYTE    "x86"
cpu_x64         BYTE    "x86_64"
cpu_arm         BYTE    "ARM"
cpu_arm64       BYTE    "ARM64"
cpu_ia64        BYTE    "Intel Itanium"

        .CODE
; Returns: RAX = pointer to CPU architecture string in RAX.
;          R8D = length of string in R8D.
GetCpuArch PROC
        lea     rcx, sysInf
        call    GetNativeSystemInfo
        movzx   eax, sysInf.wProcessorArchitecture
        cmp     eax, 0                      ; 0 = x86
        je      is_x86
        cmp     eax, 9                      ; 9 = x64
        je      is_x64
        cmp     eax, 5                      ; 5 = ARM
        je      is_arm
        cmp     eax, 12                     ; 12 = ARM64
        je      is_arm64
        cmp     eax, 6                      ; 6 = IA64
        je      is_ia64

        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
        ret
is_x86:
        lea     rax, cpu_x86
        mov     r8d, LENGTHOF cpu_x86
        ret
is_x64:
        lea     rax, cpu_x64
        mov     r8d, LENGTHOF cpu_x64
        ret
is_arm:
        lea     rax, cpu_arm
        mov     r8d, LENGTHOF cpu_arm
        ret
is_arm64:
        lea     rax, cpu_arm64
        mov     r8d, LENGTHOF cpu_arm64
        ret
is_ia64:
        lea     rax, cpu_ia64
        mov     r8d, LENGTHOF cpu_ia64
        ret
GetCpuArch ENDP

; Get CPU brand string and store it in 'cpubuf' buffer.
GetCpuBrand PROC
        push    rbx

        mov     eax, 80000002h              ; 80000002h - 80000004h = processor brand string.
        cpuid
        mov     [cpubuf], eax
        mov     [cpubuf + 4], ebx
        mov     [cpubuf + 8], ecx
        mov     [cpubuf + 12], edx

        mov     eax, 80000003h
        cpuid
        mov     [cpubuf + 16], eax
        mov     [cpubuf + 20], ebx
        mov     [cpubuf + 24], ecx
        mov     [cpubuf + 28], edx

        mov     eax, 80000004h
        cpuid
        mov     [cpubuf + 32], eax
        mov     [cpubuf + 36], ebx
        mov     [cpubuf + 40], ecx
        mov     [cpubuf + 44], edx

        lea     rax, cpubuf                 ; RAX: point to buffer address.
        mov     r8d, 48                     ; Return length in R8D.

        pop     rbx
        ret
GetCpuBrand ENDP

; Return CPU core count as an integer in EAX.
GetCpuCores PROC
        push    rbx

        mov     eax, 0                      ; Load vendor string.
        cpuid
        cmp     ebx, 'Auth'                 ; Check for the first part of "AuthenticAMD" in vendor string.
        je      amd_proc

        ; Intel processor
        mov     eax, 4
        xor     ecx, ecx                    ; Sub-leaf: 0
        cpuid
        shr     eax, 26                     ; Shift bits 31:26 to bottom
        inc     eax                         ; Core count in EAX.
        jmp     cores_done

        ; AMD Processor
amd_proc:
        mov     eax, 80000008h
        cpuid
        and     ecx, 0FFh                   ; Mask bits 7:0
        inc     ecx                         ; Core count in ECX.
        mov     eax, ecx                    ; Normalize: core count in EAX.

cores_done:
        pop     rbx
        ret
GetCpuCores ENDP

; Get CPU vendor string and store it in 'cpubuf' buffer.
GetCpuVend PROC
        push    rbx

        mov     eax, 0                      ; CPUID leaf 0 = vendor.
        cpuid                               ; CPUID instruction.
        mov     [cpubuf], ebx
        mov     [cpubuf + 4], edx
        mov     [cpubuf + 8], ecx

        lea     rax, cpubuf                 ; RAX: point to buffer address.
        mov     r8d, 12                     ; Return length in R8D.

        pop     rbx
        ret
GetCpuVend ENDP
        END
