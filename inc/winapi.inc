;=========================================
; winapi.inc - WinAPI Libraries and Protos
;=========================================

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
