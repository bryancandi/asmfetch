;=========================================
; os.asm - Operating System Functions
;=========================================

;=========================================
; Includes
;=========================================

INCLUDE const.inc
INCLUDE public.inc
INCLUDE structs.inc
INCLUDE winapi.inc

        .DATA
; Initialize structure
osEx            RTL_OSVERSIONINFOEXW <>
; OS strings:
win_11          BYTE    "Windows 11"
win_10          BYTE    "Windows 10"
win_legacy      BYTE    "Windows (pre-10)"
ed_home         BYTE    "Home"
ed_home_sl      BYTE    "Home Single Language"
ed_home_n       BYTE    "Home N"
ed_pro          BYTE    "Pro"
ed_pro_n        BYTE    "Pro N"
ed_pro_edu      BYTE    "Pro Education"
ed_pro_ws       BYTE    "Pro for Workstations"
ed_edu          BYTE    "Education"
ed_ent          BYTE    "Enterprise"
ed_ent_e        BYTE    "Enterprise E"
ed_ent_n        BYTE    "Enterprise N"
productType     DWORD   ?                   ; Store return value from GetProductInfo function.
compNameBuf     BYTE    MaxBuf DUP (0)
compNameSize    DWORD   MaxBuf

        .CODE
; Return pointer to Windows version string in RAX; byte length in R8D.
GetWinVer PROC
        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     rcx, osEx
        call    RtlGetVersion

        test    eax, eax                    ; 0 = success; nz = failure
        jnz     @fail

        mov     eax, osEx.dwBuildNumber
        cmp     eax, 22000                  ; Is Windows 11 or newer?
        jae     is_win11                    ; Yes.
        cmp     eax, 10240                  ; Is Windows 10?
        jae     is_win10                    ; Yes.
        jmp     is_legacy                   ; No.

is_win11:
        lea     rax, win_11
        mov     r8d, LENGTHOF win_11
        ret
is_win10:
        lea     rax, win_10
        mov     r8d, LENGTHOF win_10
        ret
is_legacy:
        lea     rax, win_legacy
        mov     r8d, LENGTHOF win_legacy
        ret

@fail:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
        ret
GetWinVer ENDP

; Return pointer to Windows edition string in RAX; byte length in R8D.
GetWinEdition PROC
        mov     ecx, osEx.dwMajorVersion
        mov     edx, osEx.dwMinorVersion
        movzx   r8d, osEx.wServicePackMajor ; Copy 16-bit WORD; zero-extend to 32-bit DWORD in R8D.
        movzx   r9d, osEx.wServicePackMinor
        lea     rax, productType
        mov     [rsp + 32], rax             ; Shadow space + 5th arg.
        call    GetProductInfo

        test    eax, eax                    ; nz = success; 0 = failure
        jz      w_unknown

        mov     eax, [productType]
        cmp     eax, 00000065h
        je      w_home
        cmp     eax, 00000064h
        je      w_home_sl
        cmp     eax, 00000062h
        je      w_home_n
        cmp     eax, 00000030h
        je      w_pro
        cmp     eax, 00000031h
        je      w_pro_n
        cmp     eax, 000000A4h
        je      w_pro_edu
        cmp     eax, 000000A1h
        je      w_pro_ws
        cmp     eax, 00000079h
        je      w_edu
        cmp     eax, 00000004h
        je      w_ent
        cmp     eax, 00000046h
        je      w_ent_e
        cmp     eax, 0000001Bh
        je      w_ent_n

        jmp     w_unknown                   ; Default case if edition is not listed.

w_home:
        lea     rax, ed_home
        mov     r8d, LENGTHOF ed_home
        ret
w_home_sl:
        lea     rax, ed_home_sl
        mov     r8d, LENGTHOF ed_home_sl
        ret
w_home_n:
        lea     rax, ed_home_n
        mov     r8d, LENGTHOF ed_home_n
        ret
w_pro:
        lea     rax, ed_pro
        mov     r8d, LENGTHOF ed_pro
        ret
w_pro_n:
        lea     rax, ed_pro_n
        mov     r8d, LENGTHOF ed_pro_n
        ret
w_pro_edu:
        lea     rax, ed_pro_edu
        mov     r8d, LENGTHOF ed_pro_edu
        ret
w_pro_ws:
        lea     rax, ed_pro_ws
        mov     r8d, LENGTHOF ed_pro_ws
        ret
w_edu:
        lea     rax, ed_edu
        mov     r8d, LENGTHOF ed_edu
        ret
w_ent:
        lea     rax, ed_ent
        mov     r8d, LENGTHOF ed_ent
        ret
w_ent_e:
        lea     rax, ed_ent_e
        mov     r8d, LENGTHOF ed_ent_e
        ret
w_ent_n:
        lea     rax, ed_ent_n
        mov     r8d, LENGTHOF ed_ent_n
        ret
w_unknown:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
        ret
GetWinEdition ENDP

; Return Windows build number in EAX.
GetWinBuild PROC
        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     rcx, osEx
        call    RtlGetVersion

        test    eax, eax                    ; 0 = success; nz = failure
        jnz     @fail

        mov     eax, osEx.dwBuildNumber
        ret

@fail:
        xor     eax, eax                    ; Return build number: 0
        ret
GetWinBuild ENDP

; Return pointer to computer name string in RAX; byte length in R8D.
GetComputerNameStr PROC
        mov     compNameSize, MaxBuf

        lea     rcx, compNameBuf            ; Buffer for GetComputerNameA to write to.
        lea     rdx, compNameSize           ; Bytes written to buffer.
        call    GetComputerNameA

        test    eax, eax                    ; nz = success; 0 = failure
        jz      @fail

        lea     rax, compNameBuf
        mov     r8d, compNameSize
        ret

@fail:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
        ret
GetComputerNameStr ENDP
        END
