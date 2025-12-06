@echo off
REM Jujutsu format and commit script
setlocal enabledelayedexpansion

REM Check if help requested
if "%1"=="/?" goto help
if "%1"=="-h" goto help
if "%1"=="--help" goto help

REM Check if arguments provided (allow no args to open editor)
if "%1"=="" (
    set USE_EDITOR=1
) else (
    set USE_EDITOR=0
)

REM Check if jj-fmt.ps1 exists (using positive logic)
if exist "jj-fmt.ps1" goto check_jj
echo Error: jj-fmt.ps1 file missing
echo Please run this script from project root
exit /b 1

:check_jj
REM Check if jj is available
where jj >nul 2>&1
if errorlevel 1 (
    echo Error: Jujutsu command missing
    echo Please install Jujutsu: https://github.com/martinvonz/jj
    exit /b 1
)

echo --------------------------------------------------------------------------------
echo Jujutsu Format and Commit
echo --------------------------------------------------------------------------------
echo.

REM Run formatting script
echo [1/3] Formatting changed files...
powershell -ExecutionPolicy Bypass -File .\jj-fmt.ps1

if errorlevel 1 (
    echo.
    echo --------------------------------------------------------------------------------
    echo Error: Formatting failed
    echo --------------------------------------------------------------------------------
    echo Please fix the errors above and try again
    exit /b 1
)

echo.
echo [2/3] Committing changes...
echo.

if "%USE_EDITOR%"=="1" (
    echo Opening editor for commit message...
    echo.
    jj commit
) else (
    jj commit %*
)

if errorlevel 1 (
    echo.
    echo --------------------------------------------------------------------------------
    echo Error: Commit failed
    echo --------------------------------------------------------------------------------
    echo Please check the error message above
    exit /b 1
)

REM Only set bookmark if commit succeeded
echo Commit successful
echo.
echo [3/3] Setting bookmark...
jj bookmark set main -r "@-"

if errorlevel 1 (
    echo Warning: Failed to set bookmark (you may need to set it manually)
    echo You can manually run: jj bookmark set main -r "@-"
) else (
    echo Bookmark 'main' set to parent commit successfully
)

echo.
echo --------------------------------------------------------------------------------
echo Success: Changes committed
echo --------------------------------------------------------------------------------
goto end

:help
echo.
echo Jujutsu Format and Commit Script
echo.
echo Usage:
echo   jjc.bat -m "commit message"    (single-line commit)
echo   jjc.bat                         (open editor for multi-line)
echo   jjc.bat --help
echo.
echo Description:
echo   Automatically formats changed files and commits them
echo.
echo Steps:
echo   1. Detects changed files using jj status
echo   2. Formats files by language:
echo      - Frontend: Biome (JS/TS/Vue/JSON)
echo      - Rust: cargo fmt / rustfmt
echo      - Zig: zig fmt
echo      - Python: ruff / black / autopep8
echo      - C/C++: clang-format
echo   3. Commits if formatting succeeds
echo   4. Sets bookmark 'main' to parent commit
echo.
echo Examples:
echo   Single-line commit:
echo     jjc.bat -m ":sparkles: feat: add new feature"
echo     jjc.bat -m ":bug: fix: fix issue"
echo.
echo   Multi-line commit (opens editor):
echo     jjc.bat
echo     (then write multi-line message in editor)
echo.

:end
