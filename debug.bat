@echo off

ml64.exe /c /Zi asmfetch.asm
if errorlevel 1 goto :eof

rc.exe asmfetch.rc
if errorlevel 1 goto :eof

link.exe asmfetch.obj asmfetch.res /DEBUG /SUBSYSTEM:console /ENTRY:start /OUT:asmfetch.exe
if errorlevel 1 goto :eof
