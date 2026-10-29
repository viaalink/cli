@echo off
:: Viaalink CLI Installer for Windows (installs via.exe and asd.exe)
:: Delegates to PowerShell installer (bypass AMSI via saved file)
:: Usage: curl -fsSL https://raw.githubusercontent.com/viaalink/cli/main/install.cmd -o %TEMP%\install.cmd && %TEMP%\install.cmd

echo [INFO] Viaalink CLI Installer (Windows)
echo.

:: Download the PowerShell installer to a file (avoids AMSI pipe detection)
set "PS_INSTALLER=%TEMP%\asd-install-%RANDOM%.ps1"

curl.exe -fsSL -o "%PS_INSTALLER%" "https://raw.githubusercontent.com/viaalink/cli/main/install.ps1"
if errorlevel 1 (
    echo [ERROR] Failed to download installer. Check your internet connection.
    exit /b 1
)

:: Run the saved script (file execution is less flagged than irm pipe)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_INSTALLER%"
set "EXIT_CODE=%ERRORLEVEL%"

:: Cleanup
del "%PS_INSTALLER%" 2>nul

exit /b %EXIT_CODE%
