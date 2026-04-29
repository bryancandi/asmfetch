@echo off

if not exist build mkdir build

ml64.exe /c /I inc\ /Fo build\ ^
    src\main.asm ^
    src\cpu.asm ^
    src\memory.asm ^
    src\os.asm ^
    src\uptime.asm ^
    src\utility.asm

link.exe /OUT:asmfetch.exe build\*.obj /SUBSYSTEM:console /ENTRY:main
