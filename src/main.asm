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

INCLUDE const.inc
INCLUDE globals.inc
INCLUDE macros.inc
INCLUDE proto.inc
INCLUDE winapi.inc

        .DATA
buffer          DWORD   MaxBuf DUP (?)      ; Output buffer.
; Header strings:
header_line     BYTE    "----------------------------------------", 0Dh, 0Ah
header_proc     BYTE    "Processor", 0Dh, 0Ah
header_mem      BYTE    "Memory", 0Dh, 0Ah
header_os       BYTE    "Operating System", 0Dh, 0Ah
; Processor strings:
cpu_vendor      BYTE    "Vendor       : "
cpu_name        BYTE    "Model        : "
cpu_cores       BYTE    "Threads      : "
cpu_arch        BYTE    "Architecture : "
; Memory strings:
mem_total       BYTE    "Total        : "
mem_avail       BYTE    "Available    : "
mem_load        BYTE    "Load         : "
gib_label       BYTE    " GiB"
decimal_pt      BYTE    "."
percent_sn      BYTE    "%"
; Operating system strings:
os_version      BYTE    "Version      : "
os_edition      BYTE    "Edition      : "
os_build        BYTE    "Build        : "
comp_name       BYTE    "Hostname     : "
; Uptime strings:
uptime          BYTE    "Uptime       : "
; Formatting and utility:
unknown         BYTE    "unknown"
newln           BYTE    0Dh, 0Ah            ; CRLF
stdout          QWORD   ?                   ; Handle to standard output device.
nbwr            DWORD   ?                   ; Number of bytes (characters) actually written.
nbrd            DWORD   ?                   ; Number of bytes (characters) actually read.

        .CODE
main    PROC
        sub     rsp, 40                     ; Reserve "shadow space" on stack for 4 args (32 shadow + 8 alignment).

        ; Obtain handle for standard output.
        mov     rcx, STD_OUTPUT_HANDLE      ; Standard output device code for GetStdHandle.
        call    GetStdHandle                ; Return handle to standard output.
        mov     [stdout], rax               ; Store the handle for console output.

        ; Processor section:
        StrOut  newln, LENGTHOF newln
        StrOut  header_proc, LENGTHOF header_proc
        StrOut  header_line, LENGTHOF header_line

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
        lea     rdi, buffer + MaxBuf
        call    Int2Str
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        StrOut  cpu_arch, LENGTHOF cpu_arch
        call    GetCpuArch
        StrOut  rax, r8d
        StrOut  newln, LENGTHOF newln

        ; Memory section:
        StrOut  newln, LENGTHOF newln
        StrOut  header_mem, LENGTHOF header_mem
        StrOut  header_line, LENGTHOF header_line

        StrOut  mem_total, LENGTHOF mem_total
        call    GetMemory
        mov     r12, rdx                    ; Save free memory QWORD for later use.
        mov     r13d, r8d                   ; Save memory load DWORD for later use.
        call    Byte2GiB
        mov     r14, rdx                    ; Save fractional part of GiB for later use.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, r14                    ; Load fractional part of GiB.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  gib_label, LENGTHOF gib_label
        StrOut  newln, LENGTHOF newln

        StrOut  mem_avail, LENGTHOF mem_avail
        mov     rax, r12                    ; Load free memory QWORD.
        call    Byte2GiB
        mov     r14, rdx                    ; Save fractional part of GiB for later use.
        call    Int2Str
        StrOut  rax, r8d
        StrOut  decimal_pt, LENGTHOF decimal_pt
        mov     rax, r14                    ; Load fractional part of GiB.
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

        ; Operating System:
        StrOut  newln, LENGTHOF newln
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
        lea     rdi, buffer + MaxBuf
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
        StrOut  newln, LENGTHOF newln

        xor     rcx, rcx
        call    ExitProcess
main    ENDP
        END
