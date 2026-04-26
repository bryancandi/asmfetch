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

;==============================================================================
; Libraries and Prototypes
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

;==============================================================================
; Constants
;==============================================================================

STD_OUTPUT_HANDLE EQU   -11                 ; Device code for console output.
MaxBuf            EQU   256
BytesPerGib       EQU   1024 * 1024 * 1024
MsPerSecond       EQU   1000
SecPerDay         EQU   86400
SecPerHour        EQU   3600
SecPerMinute      EQU   60

;==============================================================================
; Macros
;==============================================================================

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

;==============================================================================
; Structure Definitions (Win32/NT)
;==============================================================================

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
; Header strings:
header_line     BYTE    "==============================", 0Dh, 0Ah
header_hw       BYTE    "           Hardware", 0Dh, 0Ah
header_sw       BYTE    "           Software", 0Dh, 0Ah
; Processor strings:
cpu_vendor      BYTE    "CPU Vendor    : "
cpu_name        BYTE    "CPU Model     : "
cpu_cores       BYTE    "CPU Threads   : "
cpu_arch        BYTE    "CPU Arch      : "
cpu_x86         BYTE    "x86"
cpu_x64         BYTE    "x64 (AMD64)"
cpu_arm         BYTE    "ARM"
cpu_arm64       BYTE    "ARM64"
cpu_ia64        BYTE    "Intel Itanium"
; Memory strings:
mem_total       BYTE    "RAM Total     : "
mem_avail       BYTE    "RAM Available : "
mem_load        BYTE    "RAM Load      : "
gibi_whole      QWORD   ?                   ; Store whole portion of RAM size.
gibi_fract      QWORD   ?                   ; Store fractional portion of RAM size.
gib_label       BYTE    " GiB"
decimal_pt      BYTE    "."
percent_sn      BYTE    "%"
; Operating system strings:
os_version      BYTE    "OS Version    : "
os_edition      BYTE    "OS Edition    : "
os_build        BYTE    "OS Build      : "
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
comp_name       BYTE    "Hostname      : "
compNameBuf     BYTE    MaxBuf DUP (0)
compNameSize    DWORD   MaxBuf
; Uptime strings:
uptime          BYTE    "Uptime        : "
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
;==============================================================================
; Utility functions
;==============================================================================

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

; Convert bytes in RAX to GiB; store whole and fractional parts in gibi_whole and gibi_fract.
Byte2GiB PROC
        ; RAX = bytes
        xor     rdx, rdx
        mov     r8, BytesPerGib             ; R8 = 1 GiB in bytes.
        div     r8                          ; RAX = RAX/R8, RDX = remainder.

        ; RAX = whole portion of result, RDX = fractional portion of result.
        mov     [gibi_whole], rax           ; Store whole portion.

        ; Scale remainder to 2 decimal digits: (remainder * 100) / GiB
        mov     rax, rdx                    ; Move remainder into RAX.
        mov     r8, 100
        mul     r8                          ; Multiply by 100 to convert fractional GiB into a 2-digit integer (shift decimal right).
        mov     r8, BytesPerGib
        div     r8                          ; (remainder * 100) / GiB
        mov     [gibi_fract], rax           ; Store fractional portion.

        ret
Byte2GiB ENDP

; Convert milliseconds in RAX to a human-readable format.
ConvertToDHMS PROC
        ; RAX = uptime milliseconds
        xor     rdx, rdx                    ; Clear RDX for division.
        mov     r8, MsPerSecond             ; Divisor in R8 = milliseconds per second.
        div     r8                          ; RAX = seconds.

        ; Seconds can now be divided out into Days, Hours, Minutes.
        ; Days:
        xor     rdx, rdx
        mov     r8, SecPerDay
        div     r8                          ; RAX = days, RDX = remaining seconds.
        mov     [days], rax                 ; Store result.
        mov     rax, rdx                    ; Carry remainder forward.

        ; Hours:
        xor     rdx, rdx
        mov     r8, SecPerHour
        div     r8
        mov     [hours], rax
        mov     rax, rdx

        ; Minutes
        xor     rdx, rdx
        mov     r8, SecPerMinute
        div     r8
        mov     [minutes], rax
        mov     rax, rdx

        ; Seconds:
        mov     [seconds], rax

        ret
ConvertToDHMS ENDP

;==============================================================================
; Operating System related functions
;==============================================================================

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

; Print a formatted uptime string directly to the console when called.
PrintFormatUptime PROC
        push    rdi

        call    GetTickCount64              ; RAX = uptime in milliseconds.
        call    ConvertToDHMS               ; Convert milliseconds and store in 'days', 'hours', 'minutes', 'seconds'.

        xor     r10d, r10d                  ; Comma flag: 0 = first unit, 1 = comma before next unit.

        mov     rax, [days]
        cmp     rax, 0                      ; Days = 0?
        je      hours_out                   ; Yes, jump to hours.
        cmp     rax, 1                      ; Days = 1?
        je      single_day                  ; Yes, jump.

        lea     rdi, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  days_label, LENGTHOF days_label
        jmp     days_done

single_day:
        lea     rdi, timebuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  day_label, LENGTHOF day_label

days_done:
        mov     r10d, 1                     ; Set comma flag.

hours_out:
        mov     rax, [hours]
        cmp     rax, 0                      ; Hours = 0?
        je      minutes_out                 ; Yes, jump to minutes.

        cmp     r10d, 0                     ; Already printed a previous value?
        je      hours_no_comma              ; No, do not print a comma.
        push    rax                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     rax                         ; Restore RAX for next function call.
hours_no_comma:

        cmp     rax, 1                      ; Hours = 1?
        je      single_hour                 ; Yes, jump.

        lea     rdi, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  hours_label, LENGTHOF hours_label
        jmp     hours_done

single_hour:
        lea     rdi, timebuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  hour_label, LENGTHOF hour_label

hours_done:
        mov     r10d, 1                     ; Set comma flag.

minutes_out:
        mov     rax, [minutes]
        cmp     rax, 0                      ; Minutes = 0?
        je      seconds_out                 ; Yes, jump to seconds.

        cmp     r10d, 0                     ; Already printed a previous value?
        je      minutes_no_comma            ; No, do not print comma.
        push    rax                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     rax                         ; Restore RAX for next function call.
minutes_no_comma:

        cmp     rax, 1                      ; Minutes = 1?
        je      single_minute               ; Yes, jump.

        lea     rdi, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  minutes_label, LENGTHOF minutes_label
        jmp     minutes_done

single_minute:
        lea     rdi, timebuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  minute_label, LENGTHOF minute_label

minutes_done:
        mov     r10d, 1                     ; Set comma flag.

seconds_out:
        mov     rax, [seconds]
        cmp     rax, 0                      ; Seconds = 0?
        je      uptime_done

        cmp     r10d, 0                     ; Already printed a value?
        je      seconds_no_comma            ; No, do not print comma.
        push    rax                         ; Preserve RAX before StrOut macro call.
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma.
        pop     rax                         ; Restore RAX for next function call.
seconds_no_comma:

        cmp     rax, 1                      ; Seconds = 1?
        je      single_second               ; Yes, jump.

        lea     rdi, timebuf + MaxBuf       ; No, continue with plural.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  seconds_label, LENGTHOF seconds_label
        jmp     uptime_done

single_second:
        lea     rdi, timebuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  second_label, LENGTHOF second_label

uptime_done:
        StrOut  newln, LENGTHOF newln
        pop     rdi
        ret
PrintFormatUptime ENDP

;==============================================================================
; Processor functions
;==============================================================================

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

;==============================================================================
; Memory functions
;==============================================================================

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

;==============================================================================
; Program entry point / main
;==============================================================================

main    PROC
        sub     rsp, 40                     ; Reserve "shadow space" on stack for 4 args (32 shadow + 8 alignment).

        ; Obtain handle for standard output.
        mov     rcx, STD_OUTPUT_HANDLE      ; Standard output device code for GetStdHandle.
        call    GetStdHandle                ; Return handle to standard output.
        mov     [stdout], rax               ; Store the handle for console output.

;       HARDWARE section:
        StrOut  newln, LENGTHOF newln
        StrOut  header_line, LENGTHOF header_line
        StrOut  header_hw, LENGTHOF header_hw
        StrOut  header_line, LENGTHOF header_line
        StrOut  newln, LENGTHOF newln

        ; Processor:
        StrOut  cpu_vendor, LENGTHOF cpu_vendor
        call    GetCpuVend
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_name, LENGTHOF cpu_name
        call    GetCpuBrand
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_cores, LENGTHOF cpu_cores
        call    GetCpuCores
        lea     rdi, cpubuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_arch, LENGTHOF cpu_arch
        call    GetCpuArch
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        ; Memory:
        StrOut  mem_total, LENGTHOF mem_total
        call    GetMemory
        mov     r12, rdx                    ; Save free memory QWORD for later use.
        mov     r13d, r8d                   ; Save memory load DWORD for later use.
        call    Byte2GiB
        mov     rax, [gibi_whole]
        lea     rdi, membuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, [gibi_fract]
        lea     rdi, membuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_avail, LENGTHOF mem_avail
        mov     rax, r12                    ; Load free memory QWORD.
        call    Byte2GiB
        mov     rax, [gibi_whole]
        lea     rdi, membuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, [gibi_fract]
        lea     rdi, membuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_load, LENGTHOF mem_load
        mov     eax, r13d                   ; Load memory load DWORD.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  percent_sn, LENGTHOF percent_sn
        StrOut  newln, LENGTHOF newln

;       SOFTWARE section:
        StrOut  newln, LENGTHOF newln
        StrOut  header_line, LENGTHOF header_line
        StrOut  header_sw, LENGTHOF header_sw
        StrOut  header_line, LENGTHOF header_line
        StrOut  newln, LENGTHOF newln

        ; Operating system:
        StrOut  os_version, LENGTHOF os_version
        call    GetWinVer
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  os_edition, LENGTHOF os_edition
        call    GetWinEdition
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  os_build, LENGTHOF os_build
        call    GetWinBuild
        lea     rdi, tmpbuf + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  comp_name, LENGTHOF comp_name
        call    GetComputerNameStr
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        ; Uptime:
        StrOut  uptime, LENGTHOF uptime
        call    PrintFormatUptime
        StrOut  newln, LENGTHOF newln

        xor     rcx, rcx
        call    ExitProcess
main    ENDP
        END
