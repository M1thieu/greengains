@echo off
echo.
echo  Name Finder
echo  -----------

where node >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo  Node.js is required but not installed.
  echo  Opening the download page now...
  echo.
  start https://nodejs.org/en/download
  echo  1. Download the Windows Installer ^(.msi^)
  echo  2. Run it, click Next until done
  echo  3. Re-open this file
  echo.
  pause
  exit /b 1
)

start /b node "%~dp0server.js"
timeout /t 2 /nobreak >nul
start http://localhost:3738

echo  Running at http://localhost:3738
echo  Close this window to stop the server.
echo.
pause
