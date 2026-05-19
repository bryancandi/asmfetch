@echo off

ml64.exe /c asmfetch.asm
link.exe asmfetch.obj /SUBSYSTEM:console /ENTRY:main /OUT:asmfetch.exe
