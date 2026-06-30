;============================================================================
;                                 ____         __            __
;   ____ _   _____   ____ ___    / __/  ___   / /_  _____   / /_
;  / __ `/  / ___/  / __ `__ \  / /_   / _ \ / __/ / ___/  / __ \
; / /_/ /  (__  )  / / / / / / / __/  /  __// /_  / /__   / / / /
; \__,_/  /____/  /_/ /_/ /_/ /_/     \___/ \__/  \___/  /_/ /_/
; ---------------------------------------------------------------------------
; asmfetch.asm - x64 System Information Utility for the Windows Console
;
; Assemble and link with:
; ml64.exe /c asmfetch.asm
; link.exe asmfetch.obj /SUBSYSTEM:console /ENTRY:start /OUT:asmfetch.exe
;
; Copyright (c) 2026 by Bryan C.
; Licensed under the Apache License, Version 2.0
;============================================================================

INCLUDELIB advapi32.lib                     ; Advanced Windows Base API
INCLUDELIB iphlpapi.lib                     ; Windows Networking API
INCLUDELIB kernel32.lib                     ; User-mode Windows Kernel API
INCLUDELIB ntdll.lib                        ; Windows Native API

;----------------------------------------------------------------------------
; Win32 function prototypes
; x64 args in: RCX, RDX, R8, R9, stack
;----------------------------------------------------------------------------

; System
ExitProcess             PROTO uExitCode:DWORD
GetProcessHeap          PROTO
HeapAlloc               PROTO hHeap:QWORD, dwFlags:DWORD, dwBytes:QWORD
HeapFree                PROTO hHeap:QWORD, dwFlags:DWORD, lpMem:PTR
RegGetValueA            PROTO hkey:QWORD, lpSubKey:PTR BYTE, lpValue:PTR BYTE, dwFlags:DWORD, pdwType:PTR DWORD, pvData:PTR, pcbData:PTR DWORD

; Console I/O
GetStdHandle            PROTO nStdHandle:DWORD
WriteConsoleA           PROTO hConsoleOutput:QWORD, lpBuffer:PTR, nNumberOfCharsToWrite:DWORD, lpNumberOfCharsWritten:PTR DWORD, lpReserved:PTR

; System Information
GetAdaptersInfo         PROTO AdapterInfo:QWORD, SizePointer:QWORD
GetComputerNameA        PROTO lpBuffer:PTR BYTE, nSize:PTR DWORD
GetDiskFreeSpaceExA     PROTO lpDirectoryName:PTR BYTE, lpFreeBytesAvailableToCaller:PTR QWORD, lpTotalNumberOfBytes:PTR QWORD, lpTotalNumberOfFreeBytes:PTR QWORD
GetLogicalDriveStringsA PROTO nBufferLength:DWORD, lpBuffer:PTR BYTE
GetNativeSystemInfo     PROTO lpSystemInfo:PTR SYSTEM_INFO
GetProductInfo          PROTO dwOSMajorVersion:DWORD, dwOSMinorVersion:DWORD, dwSpMajorVersion:DWORD, dwSpMinorVersion:DWORD, pdwReturnedProductType:PTR DWORD
GetTickCount64          PROTO
GlobalMemoryStatusEx    PROTO lpBuffer:PTR MEMORYSTATUSEX
RtlGetVersion           PROTO lpVersionInformation:PTR RTL_OSVERSIONINFOEXW

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------

; Win32 handles and flags
STD_OUTPUT_HANDLE               EQU -11
HKEY_LOCAL_MACHINE              EQU 80000002h
RRF_RT_REG_DWORD                EQU 10h
ERROR_BUFFER_OVERFLOW           EQU 6Fh

; IP_ADAPTER_INFO limits 
MAX_ADAPTER_ADDRESS_LENGTH      EQU 8
MAX_ADAPTER_DESCRIPTION_LENGTH  EQU 128
MAX_ADAPTER_NAME_LENGTH         EQU 256
IP_STRING_LENGTH                EQU 16

; Size units
KIBIBYTE                        EQU 1024
MEBIBYTE                        EQU 1024 * 1024
GIBIBYTE                        EQU 1024 * 1024 * 1024

; asmfetch
MaxBuf                          EQU 256

;----------------------------------------------------------------------------
; Macros
;----------------------------------------------------------------------------

; Macro: write a string to the console. addr may be RAX or a label; len is copied into R8D.
StrOut  MACRO   addr, len
        mov     rcx, [stdout]               ; Arg 1: output device handle
IFIDNI  <addr>, <rax>                       ; If addr is RAX, use it directly; otherwise LEA of the label
        mov     rdx, rax                    ; Arg 2: pointer to byte array in RAX register
ELSE
        lea     rdx, addr                   ; Arg 2: pointer to byte array label
ENDIF
        mov     r8d, len                    ; Arg 3: number of bytes to write
        lea     r9, nbwr                    ; Arg 4: pointer to variable that receives number of bytes written
        mov     QWORD PTR [rsp+32], 0       ; Arg 5: lpOverlapped (NULL pointer on stack)
        call    WriteConsoleA
        ENDM

;----------------------------------------------------------------------------
; Structure Definitions
;----------------------------------------------------------------------------

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

; Structures used by GetAdaptersInfo; contains information about a particular network adapter.
; PIP_ADDR_STRING: Pointer to an IP_ADDR_STRING structure
PIP_ADDR_STRING TYPEDEF PTR IP_ADDR_STRING

IP_ADDR_STRING STRUCT 8
    Next                        PIP_ADDR_STRING ? ; Pointer to next IP_ADDR_STRING struct
    IpAddress                   BYTE  IP_STRING_LENGTH DUP (?) ; char array
    IpMask                      BYTE  IP_STRING_LENGTH DUP (?) ; char array
    Context                     DWORD ?           ; DWORD
IP_ADDR_STRING ENDS

; PIP_ADAPTER_INFO: Pointer to an IP_ADAPTER_INFO structure
PIP_ADAPTER_INFO TYPEDEF PTR IP_ADAPTER_INFO

IP_ADAPTER_INFO STRUCT 8
    Next                        PIP_ADAPTER_INFO ? ; Pointer to next IP_ADAPTER_INFO structure
    ComboIndex                  DWORD ?            ; DWORD
    AdapterName                 BYTE  MAX_ADAPTER_NAME_LENGTH + 4 DUP (?) ; char array
    Description                 BYTE  MAX_ADAPTER_DESCRIPTION_LENGTH + 4 DUP (?) ; char array
    AddressLength               DWORD ?            ; UINT
    Address                     BYTE  MAX_ADAPTER_ADDRESS_LENGTH DUP (?) ; BYTE
    Index                       DWORD ?            ; DWORD
    dwType                      DWORD ?            ; UINT (renamed from 'Type' due to ml64 syntax error)
    DhcpEnabled                 DWORD ?            ; UINT
    CurrentIpAddress            PIP_ADDR_STRING ?  ; PIP_ADDR_STRING
    IpAddressList               IP_ADDR_STRING <>  ; Linked list of IP_ADDR_STRING structures
    GatewayList                 IP_ADDR_STRING <>  ; Linked list of IP_ADDR_STRING structures
    DhcpServer                  IP_ADDR_STRING <>  ; Linked list of IP_ADDR_STRING structures
    HaveWins                    DWORD ?            ; BOOL
    PrimaryWinsServer           IP_ADDR_STRING <>  ; Linked list of IP_ADDR_STRING structures
    SecondaryWinsServer         IP_ADDR_STRING <>  ; Linked list of IP_ADDR_STRING structures
    LeaseObtained               QWORD ?            ; time_t (64-bit)
    LeaseExpires                QWORD ?            ; time_t (64-bit)
IP_ADAPTER_INFO ENDS

;----------------------------------------------------------------------------
; Data Segment
;----------------------------------------------------------------------------

        .DATA
; System information structures (zero-initialized)
sysInf          SYSTEM_INFO <>
msEx            MEMORYSTATUSEX <>
osEx            RTL_OSVERSIONINFOEXW <>

; Size buffer for GetAdaptersInfo
pAdapterSize    QWORD   0

; Output buffers
tmpbuf          BYTE    MaxBuf DUP (?)      ; Temp buffer for Int2Str or general use
timebuf         BYTE    MaxBuf DUP (?)      ; Uptime string buffer
cpubuf          DWORD   MaxBuf DUP (?)      ; CPU strings buffer
membuf          BYTE    MaxBuf DUP (?)      ; Memory data buffer
logicaldrives   BYTE    MaxBuf DUP (?)      ; Logical disk drive letters buffer
currentdrive    BYTE    MaxBuf DUP (?)      ; Current disk drive letter buffer
disktotalbytes  QWORD   ?                   ; Drive total bytes buffer
diskfreebytes   QWORD   ?                   ; Drive free bytes buffer

; Header strings
header_line     BYTE    "----------------------------------------", 0Dh, 0Ah
header_proc     BYTE    0Dh, 0Ah, "Processor", 0Dh, 0Ah
header_mem      BYTE    0Dh, 0Ah, "Memory", 0Dh, 0Ah
header_os       BYTE    0Dh, 0Ah, "Operating System", 0Dh, 0Ah
header_disks    BYTE    0Dh, 0Ah, "Disks", 0Dh, 0Ah
header_network  BYTE    0Dh, 0Ah, "Network", 0Dh, 0Ah

; Processor strings
cpu_vendor      BYTE    "Vendor       : "
cpu_name        BYTE    "Model        : "
cpu_cores       BYTE    "Threads      : "
cpu_arch        BYTE    "Architecture : "
cpu_x86         BYTE    "x86"
cpu_x64         BYTE    "x86_64"
cpu_arm         BYTE    "ARM"
cpu_arm64       BYTE    "ARM64"
cpu_ia64        BYTE    "Intel Itanium"

; Memory strings
mem_total       BYTE    "Total        : "
mem_avail       BYTE    "Available    : "
mem_load        BYTE    "Load         : "
gibi_whole      QWORD   ?                   ; Store whole portion of RAM size
gibi_fract      QWORD   ?                   ; Store fractional portion of RAM size

; Disk strings
disk_total      BYTE    "Total        : "
disk_avail      BYTE    "Available    : "

; Operating system strings
os_version      BYTE    "Version      : "
os_edition      BYTE    "Edition      : "
os_build        BYTE    "Build        : "
win_next        BYTE    "Windows"
win_11          BYTE    "Windows 11"
win_10          BYTE    "Windows 10"
win_legacy      BYTE    "Windows (pre-10)"
ed_business     BYTE    "Business"
ed_business_n   BYTE    "Business N"
ed_cluster_srv  BYTE    "HPC Edition"
ed_cluster_srv_v BYTE   "Server Hyper Core V"
ed_home         BYTE    "Home"
ed_home_china   BYTE    "Home China"
ed_home_n       BYTE    "Home N"
ed_home_sl      BYTE    "Home Single Language"
ed_dc_eval      BYTE    "Server Datacenter (evaluation installation)"
ed_dc_sac_core  BYTE    "Server Datacenter, Semi-Annual Channel (core installation)"
ed_std_sac_core BYTE    "Server Standard, Semi-Annual Channel (core installation)"
ed_dc_srv       BYTE    "Server Datacenter (full installation)"
ed_dc_srv_core  BYTE    "Server Datacenter (core installation)"
ed_dc_srv_core_v BYTE   "Server Datacenter without Hyper-V (core installation)"
ed_dc_srv_v     BYTE    "Server Datacenter without Hyper-V (full installation)"
ed_edu          BYTE    "Education"
ed_ent          BYTE    "Enterprise"
ed_ent_e        BYTE    "Enterprise E"
ed_ent_eval     BYTE    "Enterprise Evaluation"
ed_ent_n        BYTE    "Enterprise N"
ed_ent_n_eval   BYTE    "Enterprise N Evaluation"
ed_ent_ltsb     BYTE    "Enterprise 2015 LTSB"
ed_ent_ltsb_eval BYTE   "Enterprise 2015 LTSB Evaluation"
ed_ent_ltsb_n   BYTE    "Enterprise 2015 LTSB N"
ed_ent_ltsb_n_eval BYTE "Enterprise 2015 LTSB N Evaluation"
ed_ent_srv      BYTE    "Server Enterprise (full installation)"
ed_ent_srv_core BYTE    "Server Enterprise (core installation)"
ed_ent_srv_core_v BYTE  "Server Enterprise without Hyper-V (core installation)"
ed_ent_srv_ia64 BYTE    "Server Enterprise for Itanium-based Systems"
ed_ent_srv_v    BYTE    "Server Enterprise without Hyper-V (full installation)"
ed_ebs_addl     BYTE    "Essential Server Solution Additional"
ed_ebs_addlsvc  BYTE    "Essential Server Solution Additional SVC"
ed_ebs_mgmt     BYTE    "Essential Server Solution Management"
ed_ebs_mgmtsvc  BYTE    "Essential Server Solution Management SVC"
ed_home_basic   BYTE    "Home Basic"
ed_home_basic_n BYTE    "Home Basic N"
ed_home_prem    BYTE    "Home Premium"
ed_home_prem_n  BYTE    "Home Premium N"
ed_home_srv     BYTE    "Windows Home Server 2011"
ed_stor_srv_ess BYTE    "Storage Server 2008 R2 Essentials"
ed_hyperv       BYTE    "Microsoft Hyper-V Server"
ed_iot_ent      BYTE    "IoT Enterprise"
ed_iot_ent_ltsc BYTE    "IoT Enterprise LTSC"
ed_iot_core     BYTE    "IoT Core"
ed_iot_core_comm BYTE   "IoT Core Commercial"
ed_ebs_mgmt_srv BYTE    "Essential Business Server Management Server"
ed_ebs_msg_srv  BYTE    "Essential Business Server Messaging Server"
ed_ebs_sec_srv  BYTE    "Essential Business Server Security Server"
ed_mobile       BYTE    "Mobile"
ed_mobile_ent   BYTE    "Mobile Enterprise"
ed_mp_prem      BYTE    "MultiPoint Server Premium"
ed_mp_std       BYTE    "MultiPoint Server Standard"
ed_team         BYTE    "Team"
ed_pro_edu      BYTE    "Pro Education"
ed_pro_ws       BYTE    "Pro for Workstations"
ed_pro          BYTE    "Pro"
ed_pro_n        BYTE    "Pro N"
ed_pro_wmc      BYTE    "Professional with Media Center"
ed_sbs_ess      BYTE    "Small Business Server 2011 Essentials"
ed_sbs_em       BYTE    "Server For SB Solutions EM"
ed_srv_sbs      BYTE    "Server For SB Solutions"
ed_srv_sbs_em   BYTE    "Server For SB Solutions EM"
ed_srv_ess      BYTE    "Server 2008 for Windows Essential Server Solutions"
ed_srv_ess_v    BYTE    "Server 2008 without Hyper-V for Windows Essential Server Solutions"
ed_srv_foundation BYTE  "Server Foundation"
ed_ent_vdesktop BYTE    "Enterprise for Virtual Desktops"
ed_sbs          BYTE    "Small Business Server"
ed_sbs_prem     BYTE    "Small Business Server Premium"
ed_sbs_prem_core BYTE   "Small Business Server Premium (core installation)"
ed_mp_srv       BYTE    "MultiPoint Server"
ed_std_eval     BYTE    "Server Standard (evaluation installation)"
ed_std_srv      BYTE    "Server Standard (full installation)"
ed_std_srv_core BYTE    "Server Standard (core installation)"
ed_std_srv_core_v BYTE  "Server Standard without Hyper-V (core installation)"
ed_std_srv_v    BYTE    "Server Standard without Hyper-V"
ed_std_srv_sol  BYTE    "Server Solutions Premium"
ed_std_srv_sol_core BYTE "Server Solutions Premium (core installation)"
ed_starter      BYTE    "Starter"
ed_starter_n    BYTE    "Starter N"
ed_stor_ent     BYTE    "Storage Server Enterprise"
ed_stor_ent_core BYTE   "Storage Server Enterprise (core installation)"
ed_stor_exp     BYTE    "Storage Server Express"
ed_stor_exp_core BYTE   "Storage Server Express (core installation)"
ed_stor_std_eval BYTE   "Storage Server Standard (evaluation installation)"
ed_stor_std     BYTE    "Storage Server Standard"
ed_stor_std_core BYTE   "Storage Server Standard (core installation)"
ed_stor_wg_eval BYTE    "Storage Server Workgroup (evaluation installation)"
ed_stor_wg      BYTE    "Storage Server Workgroup"
ed_stor_wg_core BYTE    "Storage Server Workgroup (core installation)"
ed_ultimate     BYTE    "Ultimate"
ed_ultimate_n   BYTE    "Ultimate N"
ed_web          BYTE    "Web Server (full installation)"
ed_web_core     BYTE    "Web Server (core installation)"
productType     DWORD   ?                   ; Store return value from GetProductInfo function
comp_name       BYTE    "Hostname     : "
compNameBuf     BYTE    MaxBuf DUP (0)
compNameSize    DWORD   MaxBuf

; Uptime strings
uptime          BYTE    "Uptime       : "
comma_sp        BYTE    ", "
days            QWORD   ?                   ; Uptime days value
days_label      BYTE    " days"
day_label       BYTE    " day"
hours           QWORD   ?                   ; Uptime hours value
hours_label     BYTE    " hours"
hour_label      BYTE    " hour"
minutes         QWORD   ?                   ; Uptime minutes value
minutes_label   BYTE    " minutes"
minute_label    BYTE    " minute"
seconds         QWORD   ?                   ; Uptime seconds value
seconds_label   BYTE    " seconds"
second_label    BYTE    " second"

; Formatting and utility
unknown         BYTE    "unknown"
error_msg       BYTE    "error"
not_avail       BYTE    "Not available"
kib_label       BYTE    " KiB"
mib_label       BYTE    " MiB"
gib_label       BYTE    " GiB"
decimal_pt      BYTE    "."
percent_sn      BYTE    "%"
space           BYTE    " "
l_paren         BYTE    "("
r_paren         BYTE    ")"
newln           BYTE    0Dh, 0Ah            ; CRLF
dblsp           BYTE    0Dh, 0Ah, 0Ah       ; CRLFLF
stdout          QWORD   ?                   ; Handle to standard output device
nbwr            DWORD   ?                   ; Number of bytes (characters) actually written
nbrd            DWORD   ?                   ; Number of bytes (characters) actually read

; Heap
hHeap           QWORD   ?                   ; Heap handle from GetProcessHeap
pAdapterMemory  QWORD   ?                   ; Pointer to allocated memory block from HeapAlloc for GetNetworkAdapters

; Registry
ubrSubKey       BYTE    "SOFTWARE\Microsoft\Windows NT\CurrentVersion", 0
ubrValName      BYTE    "UBR", 0
ubrBuffer       DWORD   ?
ubrLength       DWORD   4

;----------------------------------------------------------------------------
; Code Segment
;----------------------------------------------------------------------------

        .CODE
start   PROC                                ; Program entry procedure / start
        sub     rsp, 40                     ; Reserve "shadow space" on stack for 4 args (32 shadow + 8 alignment)

        ; Obtain handle for standard output.
        mov     rcx, STD_OUTPUT_HANDLE      ; Standard output device code for GetStdHandle
        call    GetStdHandle                ; Return handle to standard output
        mov     [stdout], rax               ; Store the handle for console output

        ; Operating System:
        StrOut  header_os, LENGTHOF header_os
        StrOut  header_line, LENGTHOF header_line

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
        mov     rcx, rax
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        call    GetWinUBR
        mov     rcx, rax
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
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

        ; Processor section:
        StrOut  header_proc, LENGTHOF header_proc
        StrOut  header_line, LENGTHOF header_line

        StrOut  cpu_vendor, LENGTHOF cpu_vendor
        lea     rcx, cpubuf
        call    GetCpuVend
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_name, LENGTHOF cpu_name
        lea     rcx, cpubuf
        call    GetCpuBrand
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_cores, LENGTHOF cpu_cores
        call    GetCpuCores
        mov     rcx, rax
        lea     rdx, cpubuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_arch, LENGTHOF cpu_arch
        call    GetCpuArch
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        ; Memory section:
        StrOut  header_mem, LENGTHOF header_mem
        StrOut  header_line, LENGTHOF header_line

        StrOut  mem_total, LENGTHOF mem_total
        call    GetMemory
        mov     r12, rdx                    ; Save free memory QWORD for later use
        mov     r13d, r8d                   ; Save memory load DWORD for later use
        mov     rcx, rax                    ; Move return value from GetMemory into RCX for Byte2GiB
        lea     rdx, gibi_whole             ; Pointer to buffer to store whole portion of GiB
        lea     r8, gibi_fract              ; Pointer to buffer to store decimal portion of GiB
        call    Byte2GiB
        mov     rax, [gibi_whole]
        mov     rcx, rax
        lea     rdx, membuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, [gibi_fract]
        mov     rcx, rax
        lea     rdx, membuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_avail, LENGTHOF mem_avail
        mov     rcx, r12                    ; Load previously saved free memory QWORD
        lea     rdx, gibi_whole
        lea     r8, gibi_fract
        call    Byte2GiB
        mov     rax, [gibi_whole]
        mov     rcx, rax
        lea     rdx, membuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, [gibi_fract]
        mov     rcx, rax
        lea     rdx, membuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_load, LENGTHOF mem_load
        mov     ecx, r13d                   ; Load memory load DWORD
        lea     rdx, membuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  percent_sn, LENGTHOF percent_sn
        StrOut  newln, LENGTHOF newln

        ; Disks section:
        StrOut  header_disks, LENGTHOF header_disks
        StrOut  header_line, LENGTHOF header_line
        call    PrintDisks

        ; Network section:
        StrOut  header_network, LENGTHOF header_network
        StrOut  header_line, LENGTHOF header_line
        call    GetNetworkAdapters
        test    eax, eax
        jz      skip_network_print          ; GetNetworkAdapters failed

        call    PrintNetworkAdapters

        mov     rcx, [hHeap]
        mov     rdx, 0
        mov     r8, [pAdapterMemory]
        call    HeapFree                    ; Free memory allocated by GetNetworkAdapters

skip_network_print:
       ;StrOut  dblsp, LENGTHOF dblsp
        StrOut  newln, LENGTHOF newln

        xor     ecx, ecx
        call    ExitProcess
start   ENDP

;=========================================
; Utility Functions
;=========================================

; Converts an integer to ASCII string. Digits are stored in reverse order in buffer pointed to by RDI.
; Returns: RAX = pointer to string
;          R8D = number of chars written
;
; Input:   RCX = integer to convert
;          RDX = pointer to buffer
;          R8  = buffer size
Int2Str PROC
        push    rdi                         ; Preserve RDI register

        mov     rax, rcx                    ; Move integer into RAX for division
        mov     rdi, rdx                    ; RDI points to buffer
        add     rdi, r8                     ; RDI now points to the end of the buffer

        mov     r10, 10                     ; Divisor (10)
        mov     r9d, r8d                    ; Save buffer size
        xor     r8d, r8d                    ; Initial string length = 0

convert_loop:
        cmp     r8d, r9d                    ; Is the buffer full?
        je      done

        xor     rdx, rdx                    ; Clear RDX for division
        div     r10                         ; RAX = quotient, RDX = remainder
        add     dl, '0'                     ; Remainder to ASCII digit
        dec     rdi
        mov     [rdi], dl                   ; Store digit
        inc     r8d                         ; Length + 1
        test    rax, rax
        jnz     convert_loop

done:
        mov     rax, rdi                    ; Return pointer to first digit
        pop     rdi                         ; Restore RDI
        ret
Int2Str ENDP

; Convert bytes in RCX to GiB.
; Returns: store whole and fractional parts of GiB in specified buffers
;
; Input:   RCX = bytes
;          RDX = pointer to buffer to store whole portion of GiB (XX.xx)
;          R8  = pointer to buffer to store decimal portion of GiB (xx.XX)

Byte2GiB PROC
        mov     rax, rcx                    ; Bytes
        mov     r9, rdx                     ; Pointer to buffer for quotient
                                            ; R8 already points to buffer for remainder

        xor     rdx, rdx
        mov     r10, 1024 * 1024 * 1024     ; R10 = 1 GiB in bytes
        div     r10                         ; RAX = RAX/R10, RDX = remainder

        ; RAX = whole portion of result, RDX = fractional portion of result
        mov     [r9], rax                   ; Store whole portion in buffer pointed to by r9

        ; Scale remainder to 2 decimal digits: (remainder * 100) / GiB
        mov     rax, rdx                    ; Move remainder into RAX
        mov     r10, 100
        mul     r10                         ; Multiply by 100 to convert fractional GiB into a 2-digit integer (shift decimal right)
        mov     r10, 1024 * 1024 * 1024
        div     r10                         ; (remainder * 100) / GiB
        mov     [r8], rax                   ; Store fractional portion in buffer pointed to by r8

        ret
Byte2GiB ENDP

; Convert milliseconds in RAX to a human-readable format.
ConvertToDHMS PROC
        ; RAX = uptime milliseconds
        xor     rdx, rdx                    ; Clear RDX for division
        mov     r8, 1000                    ; Divisor in R8 = milliseconds per second (1000)
        div     r8                          ; RAX = seconds

        ; Seconds can now be divided out into Days, Hours, Minutes
        ; Days:
        xor     rdx, rdx
        mov     r8, 86400                   ; Seconds per day
        div     r8                          ; RAX = days, RDX = remaining seconds
        mov     [days], rax                 ; Store result
        mov     rax, rdx                    ; Carry remainder forward

        ; Hours:
        xor     rdx, rdx
        mov     r8, 3600                    ; Seconds per hour
        div     r8
        mov     [hours], rax
        mov     rax, rdx

        ; Minutes
        xor     rdx, rdx
        mov     r8, 60                      ; Seconds per minute
        div     r8
        mov     [minutes], rax
        mov     rax, rdx

        ; Seconds:
        mov     [seconds], rax

        ret
ConvertToDHMS ENDP

;=========================================
; Operating System Functions
;=========================================

; Return pointer to Windows version string in RAX; byte length in R8D.
GetWinVer PROC
        sub     rsp, 40                     ; Shadow space

        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     rcx, osEx
        call    RtlGetVersion

        test    eax, eax                    ; 0 = success; nz = failure
        jnz     fail

        mov     eax, osEx.dwMajorVersion
        cmp     eax, 10                     ; Future / unknown Windows family
        ja      is_win_next

        mov     eax, osEx.dwBuildNumber
        cmp     eax, 22000                  ; Windows 11
        jae     is_win11
        cmp     eax, 10240                  ; Windows 10
        jae     is_win10
        jmp     is_legacy

is_win_next:
        lea     rax, win_next
        mov     r8d, LENGTHOF win_next
        jmp     done
is_win11:
        lea     rax, win_11
        mov     r8d, LENGTHOF win_11
        jmp     done
is_win10:
        lea     rax, win_10
        mov     r8d, LENGTHOF win_10
        jmp     done
is_legacy:
        lea     rax, win_legacy
        mov     r8d, LENGTHOF win_legacy
        jmp     done

fail:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
done:
        add     rsp, 40
        ret
GetWinVer ENDP

; Return pointer to Windows edition string in RAX; byte length in R8D.
GetWinEdition PROC
        sub     rsp, 40                     ; Shadow space

        mov     ecx, osEx.dwMajorVersion
        mov     edx, osEx.dwMinorVersion
        movzx   r8d, osEx.wServicePackMajor ; Copy 16-bit WORD; zero-extend to 32-bit DWORD in R8D
        movzx   r9d, osEx.wServicePackMinor
        lea     rax, productType
        mov     [rsp + 32], rax             ; Shadow space + 5th arg
        call    GetProductInfo

        test    eax, eax                    ; nz = success; 0 = failure
        jz      w_unknown

        mov     eax, [productType]
        cmp     eax, 00000006h
        je      w_business
        cmp     eax, 00000010h
        je      w_business_n
        cmp     eax, 00000012h
        je      w_cluster_srv
        cmp     eax, 00000040h
        je      w_cluster_srv_v
        cmp     eax, 00000065h
        je      w_home
        cmp     eax, 00000063h
        je      w_home_china
        cmp     eax, 00000062h
        je      w_home_n
        cmp     eax, 00000064h
        je      w_home_sl
        cmp     eax, 00000050h
        je      w_dc_eval
        cmp     eax, 00000091h
        je      w_dc_sac_core
        cmp     eax, 00000092h
        je      w_std_sac_core
        cmp     eax, 00000008h
        je      w_dc_srv
        cmp     eax, 0000000Ch
        je      w_dc_srv_core
        cmp     eax, 00000027h
        je      w_dc_srv_core_v
        cmp     eax, 00000025h
        je      w_dc_srv_v
        cmp     eax, 00000079h
        je      w_edu
        cmp     eax, 00000004h
        je      w_ent
        cmp     eax, 00000046h
        je      w_ent_e
        cmp     eax, 00000048h
        je      w_ent_eval
        cmp     eax, 0000001Bh
        je      w_ent_n
        cmp     eax, 00000054h
        je      w_ent_n_eval
        cmp     eax, 0000007Dh
        je      w_ent_ltsb
        cmp     eax, 00000081h
        je      w_ent_ltsb_eval
        cmp     eax, 0000007Eh
        je      w_ent_ltsb_n
        cmp     eax, 00000082h
        je      w_ent_ltsb_n_eval
        cmp     eax, 0000000Ah
        je      w_ent_srv
        cmp     eax, 0000000Eh
        je      w_ent_srv_core
        cmp     eax, 00000029h
        je      w_ent_srv_core_v
        cmp     eax, 0000000Fh
        je      w_ent_srv_ia64
        cmp     eax, 00000026h
        je      w_ent_srv_v
        cmp     eax, 0000003Ch
        je      w_ebs_addl
        cmp     eax, 0000003Eh
        je      w_ebs_addlsvc
        cmp     eax, 0000003Bh
        je      w_ebs_mgmt
        cmp     eax, 0000003Dh
        je      w_ebs_mgmtsvc
        cmp     eax, 00000002h
        je      w_home_basic
        cmp     eax, 00000005h
        je      w_home_basic_n
        cmp     eax, 00000003h
        je      w_home_prem
        cmp     eax, 0000001Ah
        je      w_home_prem_n
        cmp     eax, 00000022h
        je      w_home_srv
        cmp     eax, 00000013h
        je      w_stor_srv_ess
        cmp     eax, 0000002Ah
        je      w_hyperv
        cmp     eax, 000000BCh
        je      w_iot_ent
        cmp     eax, 000000BFh
        je      w_iot_ent_ltsc
        cmp     eax, 0000007Bh
        je      w_iot_core
        cmp     eax, 00000083h
        je      w_iot_core_comm
        cmp     eax, 0000001Eh
        je      w_ebs_mgmt_srv
        cmp     eax, 00000020h
        je      w_ebs_msg_srv
        cmp     eax, 0000001Fh
        je      w_ebs_sec_srv
        cmp     eax, 00000068h
        je      w_mobile
        cmp     eax, 00000085h
        je      w_mobile_ent
        cmp     eax, 0000004Dh
        je      w_mp_prem
        cmp     eax, 0000004Ch
        je      w_mp_std
        cmp     eax, 00000077h
        je      w_team
        cmp     eax, 000000A4h
        je      w_pro_edu
        cmp     eax, 000000A1h
        je      w_pro_ws
        cmp     eax, 00000030h
        je      w_pro
        cmp     eax, 00000031h
        je      w_pro_n
        cmp     eax, 00000067h
        je      w_pro_wmc
        cmp     eax, 00000032h
        je      w_sbs_ess
        cmp     eax, 00000036h
        je      w_sbs_em
        cmp     eax, 00000033h
        je      w_srv_sbs
        cmp     eax, 00000037h
        je      w_srv_sbs_em
        cmp     eax, 00000018h
        je      w_srv_ess
        cmp     eax, 00000023h
        je      w_srv_ess_v
        cmp     eax, 00000021h
        je      w_srv_foundation
        cmp     eax, 000000AFh
        je      w_ent_vdesktop
        cmp     eax, 00000009h
        je      w_sbs
        cmp     eax, 00000019h
        je      w_sbs_prem
        cmp     eax, 0000003Fh
        je      w_sbs_prem_core
        cmp     eax, 00000038h
        je      w_mp_srv
        cmp     eax, 0000004Fh
        je      w_std_eval
        cmp     eax, 00000007h
        je      w_std_srv
        cmp     eax, 0000000Dh
        je      w_std_srv_core
        cmp     eax, 00000028h
        je      w_std_srv_core_v
        cmp     eax, 00000024h
        je      w_std_srv_v
        cmp     eax, 00000034h
        je      w_std_srv_sol
        cmp     eax, 00000035h
        je      w_std_srv_sol_core
        cmp     eax, 0000000Bh
        je      w_starter
        cmp     eax, 0000002Fh
        je      w_starter_n
        cmp     eax, 00000017h
        je      w_stor_ent
        cmp     eax, 0000002Eh
        je      w_stor_ent_core
        cmp     eax, 00000014h
        je      w_stor_exp
        cmp     eax, 0000002Bh
        je      w_stor_exp_core
        cmp     eax, 00000060h
        je      w_stor_std_eval
        cmp     eax, 00000015h
        je      w_stor_std
        cmp     eax, 0000002Ch
        je      w_stor_std_core
        cmp     eax, 0000005Fh
        je      w_stor_wg_eval
        cmp     eax, 00000016h
        je      w_stor_wg
        cmp     eax, 0000002Dh
        je      w_stor_wg_core
        cmp     eax, 00000001h
        je      w_ultimate
        cmp     eax, 0000001Ch
        je      w_ultimate_n
        cmp     eax, 00000011h
        je      w_web
        cmp     eax, 0000001Dh
        je      w_web_core
        jmp     w_unknown                   ; Default case if edition is not listed

w_business:
        lea     rax, ed_business
        mov     r8d, LENGTHOF ed_business
        jmp     done
w_business_n:
        lea     rax, ed_business_n
        mov     r8d, LENGTHOF ed_business_n
        jmp     done
w_cluster_srv:
        lea     rax, ed_cluster_srv
        mov     r8d, LENGTHOF ed_cluster_srv
        jmp     done
w_cluster_srv_v:
        lea     rax, ed_cluster_srv_v
        mov     r8d, LENGTHOF ed_cluster_srv_v
        jmp     done
w_home:
        lea     rax, ed_home
        mov     r8d, LENGTHOF ed_home
        jmp     done
w_home_china:
        lea     rax, ed_home_china
        mov     r8d, LENGTHOF ed_home_china
        jmp     done
w_home_n:
        lea     rax, ed_home_n
        mov     r8d, LENGTHOF ed_home_n
        jmp     done
w_home_sl:
        lea     rax, ed_home_sl
        mov     r8d, LENGTHOF ed_home_sl
        jmp     done
w_dc_eval:
        lea     rax, ed_dc_eval
        mov     r8d, LENGTHOF ed_dc_eval
        jmp     done
w_dc_sac_core:
        lea     rax, ed_dc_sac_core
        mov     r8d, LENGTHOF ed_dc_sac_core
        jmp     done
w_std_sac_core:
        lea     rax, ed_std_sac_core
        mov     r8d, LENGTHOF ed_std_sac_core
        jmp     done
w_dc_srv:
        lea     rax, ed_dc_srv
        mov     r8d, LENGTHOF ed_dc_srv
        jmp     done
w_dc_srv_core:
        lea     rax, ed_dc_srv_core
        mov     r8d, LENGTHOF ed_dc_srv_core
        jmp     done
w_dc_srv_core_v:
        lea     rax, ed_dc_srv_core_v
        mov     r8d, LENGTHOF ed_dc_srv_core_v
        jmp     done
w_dc_srv_v:
        lea     rax, ed_dc_srv_v
        mov     r8d, LENGTHOF ed_dc_srv_v
        jmp     done
w_edu:
        lea     rax, ed_edu
        mov     r8d, LENGTHOF ed_edu
        jmp     done
w_ent:
        lea     rax, ed_ent
        mov     r8d, LENGTHOF ed_ent
        jmp     done
w_ent_e:
        lea     rax, ed_ent_e
        mov     r8d, LENGTHOF ed_ent_e
        jmp     done
w_ent_eval:
        lea     rax, ed_ent_eval
        mov     r8d, LENGTHOF ed_ent_eval
        jmp     done
w_ent_n:
        lea     rax, ed_ent_n
        mov     r8d, LENGTHOF ed_ent_n
        jmp     done
w_ent_n_eval:
        lea     rax, ed_ent_n_eval
        mov     r8d, LENGTHOF ed_ent_n_eval
        jmp     done
w_ent_ltsb:
        lea     rax, ed_ent_ltsb
        mov     r8d, LENGTHOF ed_ent_ltsb
        jmp     done
w_ent_ltsb_eval:
        lea     rax, ed_ent_ltsb_eval
        mov     r8d, LENGTHOF ed_ent_ltsb_eval
        jmp     done
w_ent_ltsb_n:
        lea     rax, ed_ent_ltsb_n
        mov     r8d, LENGTHOF ed_ent_ltsb_n
        jmp     done
w_ent_ltsb_n_eval:
        lea     rax, ed_ent_ltsb_n_eval
        mov     r8d, LENGTHOF ed_ent_ltsb_n_eval
        jmp     done
w_ent_srv:
        lea     rax, ed_ent_srv
        mov     r8d, LENGTHOF ed_ent_srv
        jmp     done
w_ent_srv_core:
        lea     rax, ed_ent_srv_core
        mov     r8d, LENGTHOF ed_ent_srv_core
        jmp     done
w_ent_srv_core_v:
        lea     rax, ed_ent_srv_core_v
        mov     r8d, LENGTHOF ed_ent_srv_core_v
        jmp     done
w_ent_srv_ia64:
        lea     rax, ed_ent_srv_ia64
        mov     r8d, LENGTHOF ed_ent_srv_ia64
        jmp     done
w_ent_srv_v:
        lea     rax, ed_ent_srv_v
        mov     r8d, LENGTHOF ed_ent_srv_v
        jmp     done
w_ebs_addl:
        lea     rax, ed_ebs_addl
        mov     r8d, LENGTHOF ed_ebs_addl
        jmp     done
w_ebs_addlsvc:
        lea     rax, ed_ebs_addlsvc
        mov     r8d, LENGTHOF ed_ebs_addlsvc
        jmp     done
w_ebs_mgmt:
        lea     rax, ed_ebs_mgmt
        mov     r8d, LENGTHOF ed_ebs_mgmt
        jmp     done
w_ebs_mgmtsvc:
        lea     rax, ed_ebs_mgmtsvc
        mov     r8d, LENGTHOF ed_ebs_mgmtsvc
        jmp     done
w_home_basic:
        lea     rax, ed_home_basic
        mov     r8d, LENGTHOF ed_home_basic
        jmp     done
w_home_basic_n:
        lea     rax, ed_home_basic_n
        mov     r8d, LENGTHOF ed_home_basic_n
        jmp     done
w_home_prem:
        lea     rax, ed_home_prem
        mov     r8d, LENGTHOF ed_home_prem
        jmp     done
w_home_prem_n:
        lea     rax, ed_home_prem_n
        mov     r8d, LENGTHOF ed_home_prem_n
        jmp     done
w_home_srv:
        lea     rax, ed_home_srv
        mov     r8d, LENGTHOF ed_home_srv
        jmp     done
w_stor_srv_ess:
        lea     rax, ed_stor_srv_ess
        mov     r8d, LENGTHOF ed_stor_srv_ess
        jmp     done
w_hyperv:
        lea     rax, ed_hyperv
        mov     r8d, LENGTHOF ed_hyperv
        jmp     done
w_iot_ent:
        lea     rax, ed_iot_ent
        mov     r8d, LENGTHOF ed_iot_ent
        jmp     done
w_iot_ent_ltsc:
        lea     rax, ed_iot_ent_ltsc
        mov     r8d, LENGTHOF ed_iot_ent_ltsc
        jmp     done
w_iot_core:
        lea     rax, ed_iot_core
        mov     r8d, LENGTHOF ed_iot_core
        jmp     done
w_iot_core_comm:
        lea     rax, ed_iot_core_comm
        mov     r8d, LENGTHOF ed_iot_core_comm
        jmp     done
w_ebs_mgmt_srv:
        lea     rax, ed_ebs_mgmt_srv
        mov     r8d, LENGTHOF ed_ebs_mgmt_srv
        jmp     done
w_ebs_msg_srv:
        lea     rax, ed_ebs_msg_srv
        mov     r8d, LENGTHOF ed_ebs_msg_srv
        jmp     done
w_ebs_sec_srv:
        lea     rax, ed_ebs_sec_srv
        mov     r8d, LENGTHOF ed_ebs_sec_srv
        jmp     done
w_mobile:
        lea     rax, ed_mobile
        mov     r8d, LENGTHOF ed_mobile
        jmp     done
w_mobile_ent:
        lea     rax, ed_mobile_ent
        mov     r8d, LENGTHOF ed_mobile_ent
        jmp     done
w_mp_prem:
        lea     rax, ed_mp_prem
        mov     r8d, LENGTHOF ed_mp_prem
        jmp     done
w_mp_std:
        lea     rax, ed_mp_std
        mov     r8d, LENGTHOF ed_mp_std
        jmp     done
w_team:
        lea     rax, ed_team
        mov     r8d, LENGTHOF ed_team
        jmp     done
w_pro_edu:
        lea     rax, ed_pro_edu
        mov     r8d, LENGTHOF ed_pro_edu
        jmp     done
w_pro_ws:
        lea     rax, ed_pro_ws
        mov     r8d, LENGTHOF ed_pro_ws
        jmp     done
w_pro:
        lea     rax, ed_pro
        mov     r8d, LENGTHOF ed_pro
        jmp     done
w_pro_n:
        lea     rax, ed_pro_n
        mov     r8d, LENGTHOF ed_pro_n
        jmp     done
w_pro_wmc:
        lea     rax, ed_pro_wmc
        mov     r8d, LENGTHOF ed_pro_wmc
        jmp     done
w_sbs_ess:
        lea     rax, ed_sbs_ess
        mov     r8d, LENGTHOF ed_sbs_ess
        jmp     done
w_sbs_em:
        lea     rax, ed_sbs_em
        mov     r8d, LENGTHOF ed_sbs_em
        jmp     done
w_srv_sbs:
        lea     rax, ed_srv_sbs
        mov     r8d, LENGTHOF ed_srv_sbs
        jmp     done
w_srv_sbs_em:
        lea     rax, ed_srv_sbs_em
        mov     r8d, LENGTHOF ed_srv_sbs_em
        jmp     done
w_srv_ess:
        lea     rax, ed_srv_ess
        mov     r8d, LENGTHOF ed_srv_ess
        jmp     done
w_srv_ess_v:
        lea     rax, ed_srv_ess_v
        mov     r8d, LENGTHOF ed_srv_ess_v
        jmp     done
w_srv_foundation:
        lea     rax, ed_srv_foundation
        mov     r8d, LENGTHOF ed_srv_foundation
        jmp     done
w_ent_vdesktop:
        lea     rax, ed_ent_vdesktop
        mov     r8d, LENGTHOF ed_ent_vdesktop
        jmp     done
w_sbs:
        lea     rax, ed_sbs
        mov     r8d, LENGTHOF ed_sbs
        jmp     done
w_sbs_prem:
        lea     rax, ed_sbs_prem
        mov     r8d, LENGTHOF ed_sbs_prem
        jmp     done
w_sbs_prem_core:
        lea     rax, ed_sbs_prem_core
        mov     r8d, LENGTHOF ed_sbs_prem_core
        jmp     done
w_mp_srv:
        lea     rax, ed_mp_srv
        mov     r8d, LENGTHOF ed_mp_srv
        jmp     done
w_std_eval:
        lea     rax, ed_std_eval
        mov     r8d, LENGTHOF ed_std_eval
        jmp     done
w_std_srv:
        lea     rax, ed_std_srv
        mov     r8d, LENGTHOF ed_std_srv
        jmp     done
w_std_srv_core:
        lea     rax, ed_std_srv_core
        mov     r8d, LENGTHOF ed_std_srv_core
        jmp     done
w_std_srv_core_v:
        lea     rax, ed_std_srv_core_v
        mov     r8d, LENGTHOF ed_std_srv_core_v
        jmp     done
w_std_srv_v:
        lea     rax, ed_std_srv_v
        mov     r8d, LENGTHOF ed_std_srv_v
        jmp     done
w_std_srv_sol:
        lea     rax, ed_std_srv_sol
        mov     r8d, LENGTHOF ed_std_srv_sol
        jmp     done
w_std_srv_sol_core:
        lea     rax, ed_std_srv_sol_core
        mov     r8d, LENGTHOF ed_std_srv_sol_core
        jmp     done
w_starter:
        lea     rax, ed_starter
        mov     r8d, LENGTHOF ed_starter
        jmp     done
w_starter_n:
        lea     rax, ed_starter_n
        mov     r8d, LENGTHOF ed_starter_n
        jmp     done
w_stor_ent:
        lea     rax, ed_stor_ent
        mov     r8d, LENGTHOF ed_stor_ent
        jmp     done
w_stor_ent_core:
        lea     rax, ed_stor_ent_core
        mov     r8d, LENGTHOF ed_stor_ent_core
        jmp     done
w_stor_exp:
        lea     rax, ed_stor_exp
        mov     r8d, LENGTHOF ed_stor_exp
        jmp     done
w_stor_exp_core:
        lea     rax, ed_stor_exp_core
        mov     r8d, LENGTHOF ed_stor_exp_core
        jmp     done
w_stor_std_eval:
        lea     rax, ed_stor_std_eval
        mov     r8d, LENGTHOF ed_stor_std_eval
        jmp     done
w_stor_std:
        lea     rax, ed_stor_std
        mov     r8d, LENGTHOF ed_stor_std
        jmp     done
w_stor_std_core:
        lea     rax, ed_stor_std_core
        mov     r8d, LENGTHOF ed_stor_std_core
        jmp     done
w_stor_wg_eval:
        lea     rax, ed_stor_wg_eval
        mov     r8d, LENGTHOF ed_stor_wg_eval
        jmp     done
w_stor_wg:
        lea     rax, ed_stor_wg
        mov     r8d, LENGTHOF ed_stor_wg
        jmp     done
w_stor_wg_core:
        lea     rax, ed_stor_wg_core
        mov     r8d, LENGTHOF ed_stor_wg_core
        jmp     done
w_ultimate:
        lea     rax, ed_ultimate
        mov     r8d, LENGTHOF ed_ultimate
        jmp     done
w_ultimate_n:
        lea     rax, ed_ultimate_n
        mov     r8d, LENGTHOF ed_ultimate_n
        jmp     done
w_web:
        lea     rax, ed_web
        mov     r8d, LENGTHOF ed_web
        jmp     done
w_web_core:
        lea     rax, ed_web_core
        mov     r8d, LENGTHOF ed_web_core
        jmp     done
w_unknown:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
done:
        add     rsp, 40
        ret
GetWinEdition ENDP

; Return Windows build number in EAX.
GetWinBuild PROC
        sub     rsp, 40                     ; Shadow space

        mov     osEx.dwOSVersionInfoSize, SIZEOF RTL_OSVERSIONINFOEXW
        lea     rcx, osEx
        call    RtlGetVersion

        test    eax, eax                    ; 0 = success; nz = failure
        jnz     fail

        mov     eax, osEx.dwBuildNumber
        add     rsp, 40
        ret

fail:
        xor     eax, eax                    ; Return build number: 0
        add     rsp, 40
        ret
GetWinBuild ENDP

; Return Windows Update Build Revision (UBR) from registry in EAX.
GetWinUBR PROC
        push    rbx
        push    rdi
        sub     rsp, 56                     ; Shadow space + 3 stack args

        lea     rdi, ubrBuffer
        lea     rbx, ubrLength

        mov     rcx, HKEY_LOCAL_MACHINE     ; hkey
        lea     rdx, ubrSubKey              ; lpSubKey
        lea     r8, ubrValName              ; lpValue
        mov     r9, RRF_RT_REG_DWORD        ; dwFlags
        mov     QWORD PTR [rsp+32], 0       ; pdwType
        mov     QWORD PTR [rsp+40], rdi     ; pvData
        mov     QWORD PTR [rsp+48], rbx     ; pcbData
        call    RegGetValueA

        test    eax, eax                    ; 0 = success; nz = failure (system error code)
        jnz     fail

        mov     eax, DWORD PTR [ubrBuffer]  ; Return UBR (DWORD) in EAX

        add     rsp, 56
        pop     rdi
        pop     rbx
        ret

fail:
        xor     eax, eax                    ; Return UBR as 0 in EAX
        add     rsp, 56
        pop     rdi
        pop     rbx
        ret
GetWinUBR ENDP

; Return pointer to computer name string in RAX; byte length in R8D.
GetComputerNameStr PROC
        sub     rsp, 40                     ; Shadow space
        mov     compNameSize, MaxBuf

        lea     rcx, compNameBuf            ; Buffer for GetComputerNameA to write to
        lea     rdx, compNameSize           ; Bytes written to buffer
        call    GetComputerNameA

        test    eax, eax                    ; nz = success; 0 = failure
        jz      fail

        lea     rax, compNameBuf
        mov     r8d, compNameSize
        add     rsp, 40
        ret

fail:
        lea     rax, unknown
        mov     r8d, LENGTHOF unknown
        add     rsp, 40
        ret
GetComputerNameStr ENDP

; Print a formatted uptime string directly to the console when called.
PrintFormatUptime PROC
        push    rdi
        sub     rsp, 32                     ; Shadow space

        call    GetTickCount64              ; RAX = uptime in milliseconds
        call    ConvertToDHMS               ; Convert milliseconds and store in 'days', 'hours', 'minutes', 'seconds'

        xor     r10d, r10d                  ; Comma flag: 0 = first unit, 1 = comma before next unit

        mov     rax, [days]
        cmp     rax, 0                      ; Days = 0?
        je      hours_out                   ; Yes, jump to hours
        cmp     rax, 1                      ; Days = 1?
        je      single_day                  ; Yes, jump

        mov     rcx, rax                    ; No, continue with plural
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  days_label, LENGTHOF days_label
        jmp     days_done

single_day:
        mov     rcx, rax
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  day_label, LENGTHOF day_label

days_done:
        mov     r10d, 1                     ; Set comma flag

hours_out:
        mov     rax, [hours]
        cmp     rax, 0                      ; Hours = 0?
        je      minutes_out                 ; Yes, jump to minutes

        cmp     r10d, 0                     ; Already printed a previous value?
        je      hours_no_comma              ; No, do not print a comma
        push    rax                         ; Preserve RAX before StrOut macro call
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma
        pop     rax                         ; Restore RAX for next function call
hours_no_comma:

        cmp     rax, 1                      ; Hours = 1?
        je      single_hour                 ; Yes, jump

        mov     rcx, rax                    ; No, continue with plural
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  hours_label, LENGTHOF hours_label
        jmp     hours_done

single_hour:
        mov     rcx, rax
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  hour_label, LENGTHOF hour_label

hours_done:
        mov     r10d, 1                     ; Set comma flag

minutes_out:
        mov     rax, [minutes]
        cmp     rax, 0                      ; Minutes = 0?
        je      seconds_out                 ; Yes, jump to seconds

        cmp     r10d, 0                     ; Already printed a previous value?
        je      minutes_no_comma            ; No, do not print comma
        push    rax                         ; Preserve RAX before StrOut macro call
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma
        pop     rax                         ; Restore RAX for next function call
minutes_no_comma:

        cmp     rax, 1                      ; Minutes = 1?
        je      single_minute               ; Yes, jump

        mov     rcx, rax                    ; No, continue with plural
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  minutes_label, LENGTHOF minutes_label
        jmp     minutes_done

single_minute:
        mov     rcx, rax
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  minute_label, LENGTHOF minute_label

minutes_done:
        mov     r10d, 1                     ; Set comma flag

seconds_out:
        mov     rax, [seconds]
        cmp     rax, 0                      ; Seconds = 0?
        je      uptime_done

        cmp     r10d, 0                     ; Already printed a value?
        je      seconds_no_comma            ; No, do not print comma
        push    rax                         ; Preserve RAX before StrOut macro call
        StrOut  comma_sp, LENGTHOF comma_sp ; Yes, print a comma
        pop     rax                         ; Restore RAX for next function call
seconds_no_comma:

        cmp     rax, 1                      ; Seconds = 1?
        je      single_second               ; Yes, jump

        mov     rcx, rax                    ; No, continue with plural
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  seconds_label, LENGTHOF seconds_label
        jmp     uptime_done

single_second:
        mov     rcx, rax
        lea     rdx, timebuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  second_label, LENGTHOF second_label

uptime_done:
        add     rsp, 32
        pop     rdi
        ret
PrintFormatUptime ENDP

;=========================================
; Processor Functions
;=========================================

; Returns: RAX = pointer to CPU architecture string in RAX
;          R8D = length of string in R8D
GetCpuArch PROC
        sub     rsp, 40                     ; Shadow space

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
        jmp     done
is_x86:
        lea     rax, cpu_x86
        mov     r8d, LENGTHOF cpu_x86
        jmp     done
is_x64:
        lea     rax, cpu_x64
        mov     r8d, LENGTHOF cpu_x64
        jmp     done
is_arm:
        lea     rax, cpu_arm
        mov     r8d, LENGTHOF cpu_arm
        jmp     done
is_arm64:
        lea     rax, cpu_arm64
        mov     r8d, LENGTHOF cpu_arm64
        jmp     done
is_ia64:
        lea     rax, cpu_ia64
        mov     r8d, LENGTHOF cpu_ia64
done:
        add     rsp, 40
        ret
GetCpuArch ENDP

; Get CPU brand string and store it in a buffer.
; Returns: RAX = pointer to filled buffer
;          R8  = length of printable data in buffer
;
; Input:   RCX = pointer to buffer
GetCpuBrand PROC
        push    rbx

        mov     r10, rcx                    ; Pointer to buffer
        mov     eax, 80000002h              ; 80000002h - 80000004h = processor brand string
        cpuid
        mov     [r10], eax
        mov     [r10 + 4], ebx
        mov     [r10 + 8], ecx
        mov     [r10 + 12], edx

        mov     eax, 80000003h
        cpuid
        mov     [r10 + 16], eax
        mov     [r10 + 20], ebx
        mov     [r10 + 24], ecx
        mov     [r10 + 28], edx

        mov     eax, 80000004h
        cpuid
        mov     [r10 + 32], eax
        mov     [r10 + 36], ebx
        mov     [r10 + 40], ecx
        mov     [r10 + 44], edx

        xor     r9, r9                      ; R9 = whitespace counter
skipspace:
        cmp     BYTE PTR [r10 + r9], ' '    ; Check for leading whitespaces
        jne     startfound
        inc     r9
        cmp     r9, 48                      ; Maximum length of cpuid brand string
        jae     startfound
        jmp     skipspace
startfound:
        mov     r8, r9                      ; R8 = string start position
findnull:
        cmp     BYTE PTR [r10 + r8], 0      ; Check for null terminator
        je      done
        inc     r8
        cmp     r8, 48                      ; Maximum length of cpuid brand string
        jae     done
        jmp     findnull
done:
        add     r10, r9                     ; Advance buffer pointer past whitespaces counted
        mov     rax, r10                    ; RAX = point to buffer address after whitespace (if present)
        sub     r8, r9                      ; R8 = buffer length minus skipped whitespace length

        pop     rbx
        ret
GetCpuBrand ENDP

; Return CPU core count as an integer in EAX.
GetCpuCores PROC
        push    rbx

        mov     eax, 0                      ; Load vendor string
        cpuid
        cmp     ebx, 'Auth'                 ; Check for the first part of "AuthenticAMD" in vendor string
        je      amd_proc

        ; Intel processor
        mov     eax, 4
        xor     ecx, ecx                    ; Sub-leaf: 0
        cpuid
        shr     eax, 26                     ; Shift bits 31:26 to bottom
        inc     eax                         ; Core count in EAX
        jmp     cores_done

        ; AMD Processor
amd_proc:
        mov     eax, 80000008h
        cpuid
        and     ecx, 0FFh                   ; Mask bits 7:0
        inc     ecx                         ; Core count in ECX
        mov     eax, ecx                    ; Normalize: core count in EAX

cores_done:
        pop     rbx
        ret
GetCpuCores ENDP

; Get CPU vendor string and store it in a buffer.
; Returns: RAX = pointer to filled buffer
;          R8D = length of data in buffer
;
; Input:   RCX = pointer to buffer
GetCpuVend PROC
        push    rbx

        mov     r9, rcx                     ; Pointer to buffer
        mov     eax, 0                      ; CPUID leaf 0 = vendor
        cpuid                               ; CPUID instruction
        mov     [r9], ebx
        mov     [r9 + 4], edx
        mov     [r9 + 8], ecx

        mov     rax, r9                     ; RAX = point to buffer address
        mov     r8d, 12                     ; Return length in R8D

        pop     rbx
        ret
GetCpuVend ENDP

;=========================================
; Memory Functions
;=========================================

; Returns: RAX = size of total physical memory in bytes (QWORD)
;          RDX = size of available physical memory in bytes (QWORD)
;          R8D = memory load percentage (DWORD)
GetMemory PROC
        sub     rsp, 40                     ; Shadow space

        mov     msEx.dwLength, SIZEOF MEMORYSTATUSEX
        lea     rcx, msEx
        call    GlobalMemoryStatusEx        ; Fills MEMORYSTATUSEX struct (after dwLength is set and RCX = pointer)

        test    rax, rax                    ; nz = success; 0 = failure
        jz      fail

        mov     rax, msEx.ullTotalPhys      ; Load QWORD from struct (total RAM)
        mov     rdx, msEx.ullAvailPhys      ; Load QWORD from struct (available RAM)
        mov     r8d, msEx.dwMemoryLoad      ; Load DWORD from struct (memory load percentage)
        jmp     done

fail:
        xor     rax, rax                    ; Fail = return zeros
        xor     rdx, rdx
        xor     r8, r8
done:
        add     rsp, 40
        ret
GetMemory ENDP

;=========================================
; Disk / Storage Functions
;=========================================

; Print logical drives size and usage data when called.
PrintDisks PROC
        push    rbx
        push    rsi
        push    rdi
        sub     rsp, 32                     ; Shadow space

        mov     rcx, LENGTHOF logicaldrives
        lea     rdx, logicaldrives
        call    GetLogicalDriveStringsA     ; Write drive letters to buffer; RAX = chars written

        test    eax, eax
        jz      done

        cmp     rax, LENGTHOF logicaldrives ; Check if logical drives string is larger than the buffer
        ja      done                        ; The string wont fit, jump to done

        mov     rbx, rax                    ; RBX = number of characters written by GetLocalDriveStringA
        lea     rsi, logicaldrives
drive_loop:
        xor     r8d, r8d                    ; R8D = track length of drive path
        test    rbx, rbx
        jz      done
        lea     rdi, currentdrive
@@:
        mov     al, [rsi]
        cmp     al, 0
        jz      @f
        mov     [rdi], al
        inc     rsi
        inc     rdi
        inc     r8d
        dec     rbx
        jmp     @b
@@:
        StrOut  currentdrive, r8d
        StrOut  newln, LENGTHOF newln

        lea     rcx, currentdrive
        mov     rdx, 0
        lea     r8, disktotalbytes
        lea     r9, diskfreebytes
        call    GetDiskFreeSpaceExA         ; Write total and free bytes for current drive into buffers

        test    eax, eax
        jz      fail

        StrOut  disk_total, LENGTHOF disk_total

        mov     rcx, [disktotalbytes]
        mov     r10, GIBIBYTE
        cmp     rcx, r10
        jae     gib_t
        mov     r10, MEBIBYTE
        cmp     rcx, r10
        jae     mib_t
        mov     r10, KIBIBYTE
        cmp     rcx, r10
        jae     kib_t
        jmp     bytes_t

gib_t:
        shr     rcx, 30
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        jmp     available
mib_t:
        shr     rcx, 20
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  mib_label, LENGTHOF mib_label
        jmp     available
kib_t:
        shr     rcx, 10
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  kib_label, LENGTHOF kib_label
        jmp     available
bytes_t:
        mov     rcx, [disktotalbytes]
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d

available:
        StrOut  newln, LENGTHOF newln
        StrOut  disk_avail, LENGTHOF disk_avail

        mov     rcx, [diskfreebytes]
        mov     r10, GIBIBYTE
        cmp     rcx, r10
        jae     gib_f
        mov     r10, MEBIBYTE
        cmp     rcx, r10
        jae     mib_f
        mov     r10, KIBIBYTE
        cmp     rcx, r10
        jae     kib_f
        jmp     bytes_f

gib_f:
        shr     rcx, 30
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        jmp     continue
mib_f:
        shr     rcx, 20
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  mib_label, LENGTHOF mib_label
        jmp     continue
kib_f:
        shr     rcx, 10
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  kib_label, LENGTHOF kib_label
        jmp     continue
bytes_f:
        mov     rcx, [diskfreebytes]
        lea     rdx, tmpbuf
        mov     r8, MaxBuf
        call    Int2Str
        StrOut  rax, r8d

continue:
        StrOut  newln, LENGTHOF newln

        ; Defensive clear: currentdrive printed via r8d length, but guard against future code using LENGTHOF
        mov     rcx, LENGTHOF currentdrive
        lea     rdi, currentdrive
        xor     al, al                      ; AL = 0
        rep     stosb                       ; Write byte AL into tmpbuf RCX times

        inc     rsi
        dec     rbx
        jmp     drive_loop

fail:                                       ; This may occur for unformatted disks where no size is available
        StrOut  not_avail, LENGTHOF not_avail
        jmp     continue
done:
        add     rsp, 32
        pop     rdi
        pop     rsi
        pop     rbx
        ret
PrintDisks ENDP

;=========================================
; Network Functions
;=========================================

; Populates an IP_ADAPTER_INFO list via the two-call GetAdaptersInfo pattern
; (size unknown up front, so we ask Windows for the required buffer size first).
; Returns 1 on success, 0 on failure
; On success, caller owns *pAdapterMemory and must HeapFree it using hHeap
GetNetworkAdapters PROC
        sub     rsp, 40                     ; Shadow space

        call    GetProcessHeap
        mov     [hHeap], rax                ; Store handle for current process heap

        xor     rcx, rcx                    ; Null buffer pointer for initial call
        lea     rdx, pAdapterSize           ; Initial call will fail and return ERROR_BUFFER_OVERFLOW
        call    GetAdaptersInfo             ; pAdapterSize will contain the required buffer size to pass to HeapAlloc
        cmp     eax, ERROR_BUFFER_OVERFLOW  ; Ensure we received the expected error code
        jne     fail

        mov     rcx, [hHeap]
        mov     rdx, 0
        mov     r8, [pAdapterSize]
        call    HeapAlloc                   ; Allocate memory on heap for GetAdaptersInfo; must be freed by caller
        test    rax, rax                    ; Ensure memory was allocated successfully
        jz      fail
        mov     [pAdapterMemory], rax       ; Store pointer to the allocated memory block

        mov     rcx, [pAdapterMemory]
        lea     rdx, pAdapterSize
        call    GetAdaptersInfo
        test    eax, eax
        jnz     fail
        mov     eax, 1                      ; Signal success
        jmp     done

fail:
        xor     eax, eax
done:
        add     rsp, 40
        ret
GetNetworkAdapters ENDP

; Prints description and IP address for each adapter in the *pAdapterMemory linked list.
; Adapters with no IP assigned (0.0.0.0) are skipped.
; Note: only the first address in each adapter's IpAddressList is printed;
; additional addresses (IP_ADDR_STRING.Next) are not traversed.
PrintNetworkAdapters PROC
        push    rbx
        sub     rsp, 32                     ; Shadow space

        mov     rax, [pAdapterMemory]       ; RAX = address of the IP_ADAPTER_INFO structure
        test    rax, rax                    ; Ensure pAdapterMemory is not null
        jz      done
        mov     rbx, rax                    ; RBX = first node
print_loop:
        mov     rax, rbx
        lea     rax, [rax].IP_ADAPTER_INFO.IpAddressList ; RAX += offset of IP_ADAPTER_INFO.IpAddressList
        lea     rax, [rax].IP_ADDR_STRING.IpAddress      ; RAX += offset of IP_ADDR_STRING.IpAddress

        mov     cl, [rax]
        cmp     cl, '0'                     ; Check if IP starts with 0; if yes, skip adapter
        je      next_adapter

        mov     rax, rbx
        lea     rax, [rax].IP_ADAPTER_INFO.Description
        StrOut  rax, MAX_ADAPTER_DESCRIPTION_LENGTH + 4
        StrOut  newln, LENGTHOF newln

        mov     rax, rbx
        lea     rax, [rax].IP_ADAPTER_INFO.IpAddressList
        lea     rax, [rax].IP_ADDR_STRING.IpAddress
        StrOut  rax, IP_STRING_LENGTH - 1   ; Subtract 1 to avoid printing the null terminator
        StrOut  newln, LENGTHOF newln

next_adapter:
        mov     rax, [rbx].IP_ADAPTER_INFO.Next
        test    rax, rax                    ; Is there is another adapter to print?
        jz      done
        mov     rbx, rax                    ; RBX = next node
        jmp     print_loop

done:
        add     rsp, 32
        pop     rbx
        ret
PrintNetworkAdapters ENDP

        END
