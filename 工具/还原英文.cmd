@echo off
chcp 936 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0»¹Ô­Ó¢ÎÄ.ps1"
if errorlevel 1 pause
