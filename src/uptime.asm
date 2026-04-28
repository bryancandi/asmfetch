;=========================================
; uptime.asm - Format / Print System Uptime
;=========================================

INCLUDE const.inc
INCLUDE globals.inc
INCLUDE macros.inc
INCLUDE proto.inc
INCLUDE winapi.inc

        .DATA
timebuf         DWORD   MaxBuf DUP (?)      ; Uptime string buffer.
days            QWORD   ?                   ; Uptime days value.
hours           QWORD   ?                   ; Uptime hours value.
minutes         QWORD   ?                   ; Uptime minutes value.
seconds         QWORD   ?                   ; Uptime seconds value.
comma_sp        BYTE    ", "
days_label      BYTE    " days"
day_label       BYTE    " day"
hours_label     BYTE    " hours"
hour_label      BYTE    " hour"
minutes_label   BYTE    " minutes"
minute_label    BYTE    " minute"
seconds_label   BYTE    " seconds"
second_label    BYTE    " second"
        
        .CODE
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
        pop     rdi
        ret
PrintFormatUptime ENDP
        END
