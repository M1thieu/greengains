@echo off
echo Building GreenGains React Dashboard...
echo.
call npm install
call npm run build
echo.
echo Copying to business folder...
xcopy /E /I /Y out\* ..\business\
echo.
echo DONE! Upload the 'business' folder to Hostinger!
echo.
pause
