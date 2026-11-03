@echo off
setlocal
title GPU Tool - RTX 2050 Laptop GPU
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0GpuTool.i18n.ps1" -Language vi -QuickAction 2050
