@echo off
setlocal EnableDelayedExpansion

set REPO=tegmentum/ccpm
set BRANCH=main
set DOWNLOAD_URL=https://github.com/%REPO%/archive/refs/heads/%BRANCH%.zip

echo Installing Claude Code PM...
echo.

REM Check if .claude directory already exists
if exist ".claude" (
    echo Error: .claude directory already exists in this project
    echo.
    echo This project may already have CCPM or another Claude Code configuration.
    echo To avoid conflicts, CCPM will not overwrite existing .claude directories.
    echo.
    echo Options:
    echo   1. Remove .claude directory: rmdir /s /q .claude
    echo   2. Install in a new project directory
    echo.
    exit /b 1
)

REM Create temp directory
set TEMP_DIR=%TEMP%\ccpm-%RANDOM%
mkdir "%TEMP_DIR%"

echo Downloading CCPM snapshot...
curl -sL "%DOWNLOAD_URL%" -o "%TEMP_DIR%\ccpm.zip"

echo Extracting files...
powershell -Command "Expand-Archive -Path '%TEMP_DIR%\ccpm.zip' -DestinationPath '%TEMP_DIR%' -Force"

REM Move .claude directory to current directory
set EXTRACTED_DIR=%TEMP_DIR%\ccpm-%BRANCH%
if not exist "%EXTRACTED_DIR%\.claude" (
    echo Error: Downloaded archive doesn't contain .claude directory
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

echo Installing CCPM files...
move "%EXTRACTED_DIR%\.claude" .

REM Create workspace directories
if not exist "prds" mkdir prds
if not exist "epics" mkdir epics

REM Cleanup
rmdir /s /q "%TEMP_DIR%"

echo.
echo CCPM installed successfully!
echo.
echo Next steps:
echo   1. Run initialization: /ccpm:init
echo   2. Create your first PRD: /ccpm:prd-new
echo   3. Get help: /ccpm:help
echo.
