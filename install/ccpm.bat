@echo off
setlocal EnableDelayedExpansion

set REPO=tegmentum/ccpm
set BRANCH=main
set DOWNLOAD_URL=https://github.com/%REPO%/archive/refs/heads/%BRANCH%.zip

echo Installing Claude Code PM...
echo.

REM Create temp directory
set TEMP_DIR=%TEMP%\ccpm-%RANDOM%
mkdir "%TEMP_DIR%"

echo Downloading CCPM snapshot...
curl -sL "%DOWNLOAD_URL%" -o "%TEMP_DIR%\ccpm.zip"

echo Extracting files...
powershell -Command "Expand-Archive -Path '%TEMP_DIR%\ccpm.zip' -DestinationPath '%TEMP_DIR%' -Force"

REM Locate extracted directory
set EXTRACTED_DIR=%TEMP_DIR%\ccpm-%BRANCH%
if not exist "%EXTRACTED_DIR%\.claude" (
    echo Error: Downloaded archive doesn't contain .claude directory
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

echo Installing CCPM files...
REM Create .claude directory if it doesn't exist
if not exist ".claude" mkdir .claude

REM Copy CCPM plugin files into .claude (overlay method)
xcopy "%EXTRACTED_DIR%\.claude\*" ".claude\" /E /I /Y /Q

REM Verify critical files were copied
if not exist ".claude\ccpm\scripts\integrate.sh" (
    echo Error: Integration script not found after installation
    echo Expected at: .claude\ccpm\scripts\integrate.sh
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

REM Create workspace directories
if not exist "prds" mkdir prds
if not exist "epics" mkdir epics

REM Cleanup
rmdir /s /q "%TEMP_DIR%"

echo.
echo CCPM installed successfully!
echo.
echo Installed files:
echo   - Plugin: .claude\ccpm\
echo   - Workspaces: prds\ and epics\
echo.
echo Next steps:
echo   1. Run initialization: /ccpm:init
echo      (This will create CLAUDE.md and integrate settings)
echo   2. Create your first PRD: /ccpm:prd-new
echo   3. Get help: /ccpm:help
echo.
