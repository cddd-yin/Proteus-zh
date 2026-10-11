@echo off
chcp 936 >nul
rem ============================================================
rem  Proteus 汉化 - 一键还原英文
rem  双击本文件即可。脚本会自动请求管理员权限（UAC）。
rem ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0工具\还原英文.ps1"
if errorlevel 1 pause
