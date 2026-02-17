@echo off
echo ========================================
echo  Building GreenGains Dashboard
echo  to Eremat hosting folder
echo ========================================
echo.

echo Installing dependencies...
call npm install
echo.

echo Building dashboard...
call npm run build
echo.

echo Copying to Eremat hosting...
xcopy /E /I /Y out\* "C:\Users\mathi\Documents\Eremat\public_html\greengains\dashboard\"
echo.

echo ========================================
echo  BUILD COMPLETE!
echo ========================================
echo.
echo Dashboard built to:
echo   C:\Users\mathi\Documents\Eremat\public_html\greengains\dashboard\
echo.
echo Now upload the entire 'greengains' folder to Hostinger!
echo.
echo It will be live at:
echo   https://yourdomain.com/greengains/dashboard/
echo.
pause
