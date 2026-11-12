;============================================================================
;                                 ____         __            __
;   ____ _   _____   ____ ___    / __/  ___   / /_  _____   / /_
;  / __ `/  / ___/  / __ `__ \  / /_   / _ \ / __/ / ___/  / __ \
; / /_/ /  (__  )  / / / / / / / __/  /  __// /_  / /__   / / / /
; \__,_/  /____/  /_/ /_/ /_/ /_/     \___/ \__/  \___/  /_/ /_/
; ---------------------------------------------------------------------------
; asmfetch.inc - Header file containing external function definitions and
;                constants for asmfetch.asm.
;============================================================================

IFNDEF ASMFETCH_INC                         ; Filename: asmfetch.inc
ASMFETCH_INC EQU 0

INCLUDELIB  advapi32.lib                    ; Advanced Windows Base API
INCLUDELIB  iphlpapi.lib                    ; Windows Networking API
INCLUDELIB  kernel32.lib                    ; User-mode Windows Kernel API
INCLUDELIB  ntdll.lib                       ; Windows Native API

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
RRF_RT_REG_SZ                   EQU 2h
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

ENDIF                                       ; ASMFETCH_INC
