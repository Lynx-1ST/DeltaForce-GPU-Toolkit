@echo off
setlocal
title GPU Tool - Tieng Viet khong dau
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GpuTool.i18n.ps1" -Language vi
echo.
echo Da ket thuc chuong trinh. Nhan phim bat ky de dong...
pause >nul
