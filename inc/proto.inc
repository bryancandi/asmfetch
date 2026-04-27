;=========================================
; proto.inc - Module Prototypes
;=========================================

; Processor
GetCpuArch          PROTO
GetCpuBrand         PROTO
GetCpuCores         PROTO
GetCpuVend          PROTO

; Memory
GetMemory           PROTO

; Operating System
GetWinBuild         PROTO
GetWinEdition       PROTO
GetWinVer           PROTO
GetComputerNameStr  PROTO

; Uptime
PrintFormatUptime   PROTO

; Utility
Int2Str             PROTO
Byte2GiB            PROTO
