@echo off
chcp 936 >nul
rem ============================================================
rem  Proteus 汉化 - 一键安装
rem  双击本文件即可。脚本会自动请求管理员权限（UAC）。
rem  想还原英文，请双击同目录的「一键还原英文.bat」。
rem ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0工具\安装汉化.ps1"
if errorlevel 1 pause
