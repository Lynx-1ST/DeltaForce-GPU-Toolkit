@echo off
setlocal
title GPU Tool - Revert
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0GpuTool.i18n.ps1" -Language vi -QuickAction revert
