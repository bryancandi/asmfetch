;==============================================================================
; asmfetch: x64 System Information utility for Windows console.
; Author: Bryan C.
; Date  : 2026
;
; Assemble with Microsoft Macro Assembler (ml64.exe)
; Link with Microsoft Incremental Linker (link.exe)
;
; ml64.exe /c /Fo build\ src\main.asm
; link.exe /OUT:build\asmfetch.exe build\*.obj /SUBSYSTEM:console /ENTRY:main
;==============================================================================

INCLUDELIB kernel32.lib                     ; Win32 API functions.
INCLUDELIB ntdll.lib                        ; NT native system calls.

ExitProcess             PROTO               ; Terminate the current process.
GetStdHandle            PROTO               ; Retrieve a handle to a standard device (input/output).
WriteConsoleA           PROTO
GlobalMemoryStatusEx    PROTO :PTR MEMORYSTATUSEX
GetTickCount64          PROTO
RtlGetVersion           PROTO :PTR RTL_OSVERSIONINFOEXW
GetProductInfo          PROTO :DWORD, :DWORD, :DWORD, :DWORD, :PTR DWORD
GetNativeSystemInfo     PROTO :PTR SYSTEM_INFO
GetComputerNameA        PROTO :PTR BYTE, :PTR DWORD

STD_OUTPUT_HANDLE EQU   -11                 ; Device code for console output.
MaxBuf            EQU   256
BytesPerGib       EQU   1024 * 1024 * 1024
MsPerSecond       EQU   1000
SecPerDay         EQU   86400
SecPerHour        EQU   3600
SecPerMinute      EQU   60

; Macro: write a string to the console. addr may be RAX or a label; len is copied into R8D.
StrOut  MACRO   addr, len
        mov     RCX, [stdout]               ; Arg 1: output device handle.
IFIDNI  <addr>, <RAX>                       ; If addr is RAX, use it directly; otherwise LEA of the label.
        mov     RDX, RAX                    ; Arg 2: pointer to byte array in RAX register.
ELSE
        lea     RDX, addr                   ; Arg 2: pointer to byte array label.
ENDIF
        mov     R8D, len                    ; Arg 3: number of bytes to write.
        lea     R9, nbwr                    ; Arg 4: pointer to variable that receives number of bytes written.
        call    WriteConsoleA
        ENDM

; Structure used by GetNativeSystemInfo.
SYSTEM_INFO STRUCT
    wProcessorArchitecture      WORD    ?
    wReserved                   WORD    ?
    dwPageSize                  DWORD   ?
    lpMinimumApplicationAddress QWORD   ?
    lpMaximumApplicationAddress QWORD   ?
    dwActiveProcessorMask       QWORD   ?
    dwNumberOfProcessors        DWORD   ?
    dwProcessorType             DWORD   ?
    dwAllocationGranularity     DWORD   ?
    wProcessorLevel             WORD    ?
    wProcessorRevision          WORD    ?
SYSTEM_INFO ENDS

; Structure used by GlobalMemoryStatusEx; contains both physical and virtual memory state.
MEMORYSTATUSEX STRUCT
    dwLength                    DWORD   ?
    dwMemoryLoad                DWORD   ?
    ullTotalPhys                QWORD   ?
    ullAvailPhys                QWORD   ?
    ullTotalPageFile            QWORD   ?
    ullAvailPageFile            QWORD   ?
    ullTotalVirtual             QWORD   ?
    ullAvailVirtual             QWORD   ?
    ullAvailExtendedVirtual     QWORD   ?
MEMORYSTATUSEX ENDS

; Structure used by RtlGetVersion; contains operating system version information.
RTL_OSVERSIONINFOEXW STRUCT
    dwOSVersionInfoSize         DWORD   ?
    dwMajorVersion              DWORD   ?
    dwMinorVersion              DWORD   ?
    dwBuildNumber               DWORD   ?
    dwPlatformId                DWORD   ?
    szCSDVersion                WORD    128 DUP (?)
    wServicePackMajor           WORD    ?
    wServicePackMinor           WORD    ?
    wSuiteMask                  WORD    ?
    wProductType                WORD    ?
    wReserved                   WORD    ?
RTL_OSVERSIONINFOEXW ENDS

        .DATA
; System information structures (zero-initialized):
sysInf          SYSTEM_INFO <>
msEx            MEMORYSTATUSEX <>
osEx            RTL_OSVERSIONINFOEXW <>
; Output buffers:
tmpbuf          DWORD   MaxBuf DUP (?)      ; Temp buffer for Int2Str or general use.
cpubuf          DWORD   MaxBuf DUP (?)      ; CPU strings buffer.
membuf          DWORD   MaxBuf DUP (?)      ; Memory data buffer.
timebuf         DWORD   MaxBuf DUP (?)      ; Uptime string buffer.
; Operating system strings:
os_title        BYTE    "--- Operating System ---", 0Dh, 0Ah
os_version      BYTE    "Version      : "
os_edition      BYTE    "Edition      : "
os_build        BYTE    "Build        : "
win_11          BYTE    "Windows 11+"
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
comp_name       BYTE    "Host         : "
compNameBuf     BYTE    MaxBuf DUP (0)
compNameSize    DWORD   MaxBuf
; Processor strings:
cpu_title       BYTE    "--- Processor ---", 0Dh, 0Ah
cpu_vendor      BYTE    "Vendor       : "
cpu_name        BYTE    "Model        : "
cpu_cores       BYTE    "Cores        : "
cpu_x86         BYTE    "Architecture : x86"
cpu_x64         BYTE    "Architecture : x64 (AMD64)"
cpu_arm         BYTE    "Architecture : ARM"
cpu_arm64       BYTE    "Architecture : ARM64"
cpu_ia64        BYTE    "Architecture : Intel Itanium"
cpu_unknown     BYTE    "Architecture : Unknown"
; Memory strings:
mem_title       BYTE    "--- Memory ---", 0Dh, 0Ah
mem_total       BYTE    "RAM Total    : "
mem_avail       BYTE    "RAM Free     : "
gibi_whole      QWORD   ?                   ; Store whole portion of RAM size.
gibi_fract      QWORD   ?                   ; Store fractional portion of RAM size.
gib_label       BYTE    " GiB"
decimal_pt      BYTE    "."
; Uptime strings:
uptime_title    BYTE    "--- System Uptime ---", 0Dh, 0Ah
comma_sp        BYTE    ", "
days            QWORD   ?                   ; Uptime days value.
days_label      BYTE    " days"
day_label       BYTE    " day"
hours           QWORD   ?                   ; Uptime hours value.
hours_label     BYTE    " hours"
hour_label      BYTE    " hour"
minutes         QWORD   ?                   ; Uptime minutes value.
minutes_label   BYTE    " minutes"
minute_label    BYTE    " minute"
seconds         QWORD   ?                   ; Uptime seconds value.
seconds_label   BYTE    " seconds"
second_label    BYTE    " second"
; Formatting and utility:
unknown         BYTE    "unknown"
newln           BYTE    0Dh, 0Ah            ; CRLF
stdout          QWORD   ?                   ; Handle to standard output device.
nbwr            DWORD   ?                   ; Number of bytes (characters) actually written.
nbrd            DWORD   ?                   ; Number of bytes (characters) actually read.

        .CODE
; Convert integer in RAX to ASCII string in buffer pointed to by RDI; digits are stored in reverse order.
Int2Str PROC
        push    RBX                         ; Preserve RBX register.

        mov     RBX, 10                     ; Divisor (10)
        xor     R8D, R8D                    ; Initial string length = 0

convert_loop:
        xor     RDX, RDX                    ; Clear RDX for division.
        div     RBX                         ; RAX = quotient, RDX = remainder.
        add     DL, '0'                     ; Remainder to ASCII digit.
        dec     RDI
        mov     [RDI], DL                   ; Store digit.
        inc     R8D                         ; Length + 1
        test    RAX, RAX
        jnz     convert_loop

        mov     RAX, RDI                    ; Return pointer to first digit.

        pop     RBX                         ; Restore RBX.
        ret
Int2Str ENDP

; Convert bytes in RAX to GiB; store whole and fractional parts in gibi_whole and gibi_fract.
Byte2GiB PROC
        ; RAX = bytes
        xor     RDX, RDX
        mov     R8, BytesPerGib             ; R8 = 1 GiB in bytes.
        div     R8                          ; RAX = RAX/R8, RDX = remainder.

        ; RAX = whole portion of result, RDX = fractional portion of result.
        mov     [gibi_whole], RAX           ; Store whole portion.

        ; Scale remainder to 2 decimal digits: (remainder * 100) / GiB
        mov     RAX, RDX                    ; Move remainder into RAX.
        mov     R8, 100
        mul     R8                          ; Multiply by 100 to convert fractional GiB into a 2-digit integer (shift decimal right).
        mov     R8, BytesPerGib
        div     R8                          ; (remainder * 100) / GiB
        mov     [gibi_fract], RAX           ; Store fractional portion.

        ret
Byte2GiB ENDP

; Convert milliseconds in RAX to a human-readable format.
ConvertToDHMS PROC
        ; RAX = uptime milliseconds
        xor     RDX, RDX                    ; Clear RDX for division.
        mov     R8, MsPerSecond             ; Divisor in R8 = milliseconds per second.
        div     R8                          ; RAX = seconds.

        ; Seconds can now be divided out into Days, Hours, Minutes.
        ; Days:
        xor     RDX, RDX
        mov     R8, SecPerDay
        div     R8                          ; RAX = days, RDX = remaining seconds.
        mov     [days], RAX                 ; Store result.
        mov     RAX, RDX                    ; Carry remainder forward.

        ; Hours:
        xor     RDX, RDX
        mov     R8, SecPerHour
        div     R8
        mov     [hours], RAX
        mov     RAX, RDX

        ; Minutes
        xor     RDX, RDX
        mov     R8, SecPerMinute
        div     R8
        mov     [minutes], RAX
        mov     RAX, RDX

        ; Seconds:
        mov     [seconds], RAX

        ret
ConvertToDHMS ENDP

; Return pointer to Windows version string in RAX; byte length in R8D.
GetWinVer PROC
        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     RCX, osEx
        call    RtlGetVersion

        test    EAX, EAX                    ; 0 = success; nz = failure
        jz      winver_continue
        lea     RAX, unknown
        mov     R8D, LENGTHOF unknown
        ret

winver_continue:
        mov     EAX, osEx.dwBuildNumber
        cmp     EAX, 22000                  ; Is Windows 11 or newer?
        jae     is_win11                    ; Yes.
        cmp     EAX, 10240                  ; Is Windows 10?
        jae     is_win10                    ; Yes.
        jmp     is_legacy                   ; No.

is_win11:
        lea     RAX, win_11
        mov     R8D, LENGTHOF win_11
        ret
is_win10:
        lea     RAX, win_10
        mov     R8D, LENGTHOF win_10
        ret
is_legacy:
        lea     RAX, win_legacy
        mov     R8D, LENGTHOF win_legacy
        ret
GetWinVer ENDP

; Return pointer to Windows edition string in RAX; byte length in R8D.
GetWinEdition PROC
        mov     ECX, osEx.dwMajorVersion
        mov     EDX, osEx.dwMinorVersion
        movzx   R8D, osEx.wServicePackMajor ; Copy 16-bit WORD; zero-extend to 32-bit DWORD in R8D.
        movzx   R9D, osEx.wServicePackMinor
        lea     RAX, productType
        mov     [RSP + 32], RAX             ; Shadow space + 5th arg.
        call    GetProductInfo

        test    EAX, EAX                    ; nz = success; 0 = failure
        jz      w_unknown

        mov     EAX, [productType]
        cmp     EAX, 00000065h
        je      w_home
        cmp     EAX, 00000064h
        je      w_home_sl
        cmp     EAX, 00000062h
        je      w_home_n
        cmp     EAX, 00000030h
        je      w_pro
        cmp     EAX, 00000031h
        je      w_pro_n
        cmp     EAX, 000000A4h
        je      w_pro_edu
        cmp     EAX, 000000A1h
        je      w_pro_ws
        cmp     EAX, 00000079h
        je      w_edu
        cmp     EAX, 00000004h
        je      w_ent
        cmp     EAX, 00000046h
        je      w_ent_e
        cmp     EAX, 0000001Bh
        je      w_ent_n

        jmp     w_unknown                   ; Default case if edition is not listed.

w_home:
        lea     RAX, ed_home
        mov     R8D, LENGTHOF ed_home
        ret
w_home_sl:
        lea     RAX, ed_home_sl
        mov     R8D, LENGTHOF ed_home_sl
        ret
w_home_n:
        lea     RAX, ed_home_n
        mov     R8D, LENGTHOF ed_home_n
        ret
w_pro:
        lea     RAX, ed_pro
        mov     R8D, LENGTHOF ed_pro
        ret
w_pro_n:
        lea     RAX, ed_pro_n
        mov     R8D, LENGTHOF ed_pro_n
        ret
w_pro_edu:
        lea     RAX, ed_pro_edu
        mov     R8D, LENGTHOF ed_pro_edu
        ret
w_pro_ws:
        lea     RAX, ed_pro_ws
        mov     R8D, LENGTHOF ed_pro_ws
        ret
w_edu:
        lea     RAX, ed_edu
        mov     R8D, LENGTHOF ed_edu
        ret
w_ent:
        lea     RAX, ed_ent
        mov     R8D, LENGTHOF ed_ent
        ret
w_ent_e:
        lea     RAX, ed_ent_e
        mov     R8D, LENGTHOF ed_ent_e
        ret
w_ent_n:
        lea     RAX, ed_ent_n
        mov     R8D, LENGTHOF ed_ent_n
        ret
w_unknown:
        lea     RAX, unknown
        mov     R8D, LENGTHOF unknown
        ret
GetWinEdition ENDP

; Return Windows build number in EAX.
GetWinBuild PROC
        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     RCX, osEx
        call    RtlGetVersion

        test    EAX, EAX                    ; 0 = success; nz = failure
        jz      build_continue
        xor     EAX, EAX                    ; Return build number: 0
        ret

build_continue:
        mov     EAX, osEx.dwBuildNumber
        ret
GetWinBuild ENDP

; Return pointer to computer name string in RAX; byte length in R8D.
GetComputerNameStr PROC
        mov     compNameSize, MaxBuf

        lea     RCX, compNameBuf            ; Buffer for GetComputerNameA to write to.
        lea     RDX, compNameSize           ; Bytes written to buffer.
        call    GetComputerNameA

        test    EAX, EAX                    ; nz = success; 0 = failure
        jz      cname_fail

        lea     RAX, compNameBuf
        mov     R8D, compNameSize
        ret

cname_fail:
        lea     RAX, unknown
        mov     R8D, LENGTHOF unknown
        ret
GetComputerNameStr ENDP

; Get CPU vendor string and store it in a buffer.
GetCpuVend PROC
        push    RBX

        mov     EAX, 0                      ; CPUID leaf 0 = vendor.
        cpuid                               ; CPUID instruction.
        mov     [cpubuf], EBX
        mov     [cpubuf + 4], EDX
        mov     [cpubuf + 8], ECX

        lea     RAX, cpubuf                 ; RAX: point to buffer address.
        mov     R8D, 12                     ; Return length in R8D.

        pop     RBX
        ret
GetCpuVend ENDP

; Get CPU brand string and store it in a buffer.
GetCpuBrand PROC
        push    RBX

        mov     EAX, 80000002h              ; 80000002h - 80000004h = processor brand string.
        cpuid
        mov     [cpubuf], EAX
        mov     [cpubuf + 4], EBX
        mov     [cpubuf + 8], ECX
        mov     [cpubuf + 12], EDX

        mov     EAX, 80000003h
        cpuid
        mov     [cpubuf + 16], EAX
        mov     [cpubuf + 20], EBX
        mov     [cpubuf + 24], ECX
        mov     [cpubuf + 28], EDX

        mov     EAX, 80000004h
        cpuid
        mov     [cpubuf + 32], EAX
        mov     [cpubuf + 36], EBX
        mov     [cpubuf + 40], ECX
        mov     [cpubuf + 44], EDX

        lea     RAX, cpubuf                 ; RAX: point to buffer address.
        mov     R8D, 48                     ; Return length in R8D.

        pop     RBX
        ret
GetCpuBrand ENDP

; Return CPU core count as an integer in EAX.
GetCpuCores PROC
        push    RBX

        mov     EAX, 0                      ; Load vendor string.
        cpuid
        cmp     EBX, 'Auth'                 ; Check for the first part of "AuthenticAMD" in vendor string.
        je      amd_proc

        ; Intel processor
        mov     EAX, 4
        xor     ECX, ECX                    ; Sub-leaf: 0
        cpuid
        shr     EAX, 26                     ; Shift bits 31:26 to bottom
        inc     EAX                         ; Core count in EAX.
        jmp     cores_done

        ; AMD Processor
amd_proc:
        mov     EAX, 80000008h
        cpuid
        and     ECX, 0FFh                   ; Mask bits 7:0
        inc     ECX                         ; Core count in ECX.
        mov     EAX, ECX                    ; Normalize: core count in EAX.

cores_done:
        pop     RBX
        ret
GetCpuCores ENDP

; Return pointer to CPU architecture string in RAX; byte length in R8D.
GetCpuArch PROC
        lea     RCX, sysInf
        call    GetNativeSystemInfo
        movzx   EAX, sysInf.wProcessorArchitecture
        cmp     EAX, 0                      ; 0 = x86
        je      is_x86
        cmp     EAX, 9                      ; 9 = x64
        je      is_x64
        cmp     EAX, 5                      ; 5 = ARM
        je      is_arm
        cmp     EAX, 12                     ; 12 = ARM64
        je      is_arm64
        cmp     EAX, 6                      ; 6 = IA64
        je      is_ia64

        lea     RAX, cpu_unknown
        mov     R8D, LENGTHOF cpu_unknown
        ret
is_x86:
        lea     RAX, cpu_x86
        mov     R8D, LENGTHOF cpu_x86
        ret
is_x64:
        lea     RAX, cpu_x64
        mov     R8D, LENGTHOF cpu_x64
        ret
is_arm:
        lea     RAX, cpu_arm
        mov     R8D, LENGTHOF cpu_arm
        ret
is_arm64:
        lea     RAX, cpu_arm64
        mov     R8D, LENGTHOF cpu_arm64
        ret
is_ia64:
        lea     RAX, cpu_ia64
        mov     R8D, LENGTHOF cpu_ia64
        ret
GetCpuArch ENDP

; Return total memory in bytes as integer in RAX.
GetMemTotal PROC
        mov     msEx.dwLength, SIZEOF MEMORYSTATUSEX
        lea     RCX, msEx
        call    GlobalMemoryStatusEx        ; Fills MEMORYSTATUSEX struct (after dwLength is set and RCX = pointer).

        test    RAX, RAX                    ; nz = success; 0 = failure
        jz      mem_fail

        mov     RAX, msEx.ullTotalPhys      ; Load QWORD from struct.
        ret

mem_fail:
        xor     RAX, RAX                    ; Fail = return zeros.
        xor     R10, R10
        ret
GetMemTotal ENDP

; Return free memory in bytes as integer in RAX.
GetMemAvail PROC
        mov     msEx.dwLength, SIZEOF MEMORYSTATUSEX
        lea     RCX, msEx
        call    GlobalMemoryStatusEx        ; Fills MEMORYSTATUSEX struct (after dwLength is set and RCX = pointer).

        test    RAX, RAX                    ; nz = success; 0 = failure
        jz      mem_fail

        mov     RAX, msEx.ullAvailPhys      ; Load QWORD from struct.
        ret

mem_fail:
        xor     RAX, RAX                    ; Fail = return zeros.
        xor     R10, R10
        ret
GetMemAvail ENDP

; Print a formatted uptime string directly to the console when called.
PrintFormatUptime PROC
        push    RDI

        call    GetTickCount64              ; RAX = uptime in milliseconds.
        call    ConvertToDHMS               ; Convert milliseconds and store in 'days', 'hours', 'minutes', 'seconds'.

        xor     R10D, R10D                  ; Comma flag: 0 = first unit, 1 = comma before next unit.

        mov     RAX, [days]
        cmp     RAX, 0                      ; Days = 0?
        je      hours_out                   ; Yes, jump to hours.
        cmp     RAX, 1                      ; Days = 1?
        je      single_day                  ; Yes, jump.

        lea     RDI, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  days_label, LENGTHOF days_label
        jmp     days_done

single_day:
        lea     RDI, timebuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  day_label, LENGTHOF day_label

days_done:
        mov     R10D, 1                     ; Set comma flag.

hours_out:
        mov     RAX, [hours]
        cmp     RAX, 0                      ; Hours = 0?
        je      minutes_out                 ; Yes, jump to minutes.

        cmp     R10D, 0                     ; Already printed a previous value?
        je      hours_no_comma              ; No, do not print a comma.
        push    RAX                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     RAX                         ; Restore RAX for next function call.
hours_no_comma:

        cmp     RAX, 1                      ; Hours = 1?
        je      single_hour                 ; Yes, jump.

        lea     RDI, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  hours_label, LENGTHOF hours_label
        jmp     hours_done

single_hour:
        lea     RDI, timebuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  hour_label, LENGTHOF hour_label

hours_done:
        mov     R10D, 1                     ; Set comma flag.

minutes_out:
        mov     RAX, [minutes]
        cmp     RAX, 0                      ; Minutes = 0?
        je      seconds_out                 ; Yes, jump to seconds.

        cmp     R10D, 0                     ; Already printed a previous value?
        je      minutes_no_comma            ; No, do not print comma.
        push    RAX                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     RAX                         ; Restore RAX for next function call.
minutes_no_comma:

        cmp     RAX, 1                      ; Minutes = 1?
        je      single_minute               ; Yes, jump.

        lea     RDI, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  minutes_label, LENGTHOF minutes_label
        jmp     minutes_done

single_minute:
        lea     RDI, timebuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  minute_label, LENGTHOF minute_label

minutes_done:
        mov     R10D, 1                     ; Set comma flag.

seconds_out:
        mov     RAX, [seconds]
        cmp     RAX, 0                      ; Seconds = 0?
        je      uptime_done

        cmp     R10D, 0                     ; Already printed a value?
        je      seconds_no_comma            ; No, do not print comma.
        push    RAX                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     RAX                         ; Restore RAX for next function call.
seconds_no_comma:

        cmp     RAX, 1                      ; Seconds = 1?
        je      single_second               ; Yes, jump.

        lea     RDI, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  seconds_label, LENGTHOF seconds_label
        jmp     uptime_done

single_second:
        lea     RDI, timebuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  second_label, LENGTHOF second_label

uptime_done:
        StrOut  newln, LENGTHOF newln
        pop     RDI
        ret
PrintFormatUptime ENDP

main    PROC
        sub     RSP, 40                     ; Reserve "shadow space" on stack for 4 args (32 shadow + 8 alignment).

        ; Obtain handle for standard output.
        mov     RCX, STD_OUTPUT_HANDLE      ; Standard output device code for GetStdHandle.
        call    GetStdHandle                ; Return handle to standard output.
        mov     [stdout], RAX               ; Store the handle for console output.

;       Operating system section:
        StrOut  newln, LENGTHOF newln
        StrOut  os_title, LENGTHOF os_title

        StrOut  os_version, LENGTHOF os_version
        call    GetWinVer
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        StrOut  os_edition, LENGTHOF os_edition
        call    GetWinEdition
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        StrOut  os_build, LENGTHOF os_build
        call    GetWinBuild
        lea     RDI, tmpbuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        StrOut  comp_name, LENGTHOF comp_name
        call    GetComputerNameStr
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

;       Processor section:
        StrOut  newln, LENGTHOF newln
        StrOut  cpu_title, LENGTHOF cpu_title

        StrOut  cpu_vendor, LENGTHOF cpu_vendor
        call    GetCpuVend
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_name, LENGTHOF cpu_name
        call    GetCpuBrand
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_cores, LENGTHOF cpu_cores
        call    GetCpuCores
        lea     RDI, cpubuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

        call    GetCpuArch
        StrOut  RAX, R8D
        StrOut  newln, LENGTHOF newln

;       Memory section:
        StrOut  newln, LENGTHOF newln
        StrOut  mem_title, LENGTHOF mem_title

        StrOut  mem_total, LENGTHOF mem_total
        call    GetMemTotal
        call    Byte2GiB
        mov     RAX, [gibi_whole]
        lea     RDI, membuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     RAX, [gibi_fract]
        lea     RDI, membuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_avail, LENGTHOF mem_avail
        call    GetMemAvail
        call    Byte2GiB
        mov     RAX, [gibi_whole]
        lea     RDI, membuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     RAX, [gibi_fract]
        lea     RDI, membuf + MaxBuf
        call    Int2Str
        StrOut  RAX, R8D
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

;       Uptime section:
        StrOut  newln, LENGTHOF newln
        StrOut  uptime_title, LENGTHOF uptime_title

        call    PrintFormatUptime
        StrOut  newln, LENGTHOF newln

        xor     RCX, RCX
        call    ExitProcess
main    ENDP
        END
