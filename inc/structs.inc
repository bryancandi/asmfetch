;=========================================
; structs.inc - Structure Definitions
;=========================================

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
