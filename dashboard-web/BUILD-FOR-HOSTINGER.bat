@echo off
echo ========================================
echo  Building GreenGains Dashboard
echo  for Hostinger Upload
echo ========================================
echo.

echo Installing dependencies...
call npm install
echo.

echo Building static files...
call npm run build
echo.

echo ========================================
echo  BUILD COMPLETE!
echo ========================================
echo.
echo The 'out' folder is ready to upload!
echo.
echo Upload everything in 'out/' folder to:
echo   - Hostinger File Manager
echo   - FTP to public_html/dashboard/
echo.
echo Then access at: yourdomain.com/dashboard
echo.
pause
