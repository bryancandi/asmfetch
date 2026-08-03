@echo off

ml64.exe /c asmfetch.asm
if errorlevel 1 goto :eof

rc.exe asmfetch.rc
if errorlevel 1 goto :eof

link.exe asmfetch.obj asmfetch.res /SUBSYSTEM:console /ENTRY:start /OUT:asmfetch.exe
if errorlevel 1 goto :eof
