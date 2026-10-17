@echo off
setlocal EnableExtensions
REM Pack a clean yxt-hos-sdkdemo source zip for external users.
REM Excludes build artifacts, .git, oh_modules, *.bat/*.sh/*.ps1 and scripts/, etc.
REM Sanitize (in pack_release.ps1): surgically clear signingConfigs to []; keep product signingConfig; preserve json5 layout (no JSON re-serialize).
REM Output: <repo>/dist/yxt-hos-sdkdemo-<yxtsdk-version or YYYYMMDD>.zip
REM Usage:
REM   scripts\pack_release.bat
REM   scripts\pack_release.bat 1.0.25
REM Run from anywhere; repo root is resolved from this script location.

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT=%%~fI"
set "VERSION=%~1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pack_release.ps1" -Root "%ROOT%" -Version "%VERSION%"
exit /b %ERRORLEVEL%