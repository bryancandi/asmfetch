@echo off

if not exist build mkdir build

ml64.exe /c /Fo build\ src\main.asm
link.exe /OUT:build\asmfetch.exe build\*.obj /SUBSYSTEM:console /ENTRY:main
