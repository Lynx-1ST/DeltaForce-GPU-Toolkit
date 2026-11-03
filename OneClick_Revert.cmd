@echo off
setlocal
title GPU Tool - Revert from installed INF
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-FromDriverINF.ps1"
pause
