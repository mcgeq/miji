@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Miji 一键构建脚本 (Batch 版本)
:: 支持 Windows 桌面端和 Android/iOS 移动端构建

:: 解析命令行参数
set "TARGET="
set "CLEAN_BUILD=0"
set "DEV_MODE=0"
set "HAS_ARGS=0"

:parse_args
if "%~1"=="" goto end_parse
set "HAS_ARGS=1"
if /i "%~1"=="-t" (
    set "TARGET=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--target" (
    set "TARGET=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-c" (
    set "CLEAN_BUILD=1"
    shift
    goto parse_args
)
if /i "%~1"=="--clean" (
    set "CLEAN_BUILD=1"
    shift
    goto parse_args
)
if /i "%~1"=="-d" (
    set "DEV_MODE=1"
    shift
    goto parse_args
)
if /i "%~1"=="--dev" (
    set "DEV_MODE=1"
    shift
    goto parse_args
)
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
shift
goto parse_args
:end_parse

:: 验证目标平台
if /i not "%TARGET%"=="windows" (
    if /i not "%TARGET%"=="android" (
        if /i not "%TARGET%"=="ios" (
            if /i not "%TARGET%"=="all" (
                echo [91m错误: 无效的目标平台 "%TARGET%"[0m
                echo 有效选项: windows, android, ios, all
                exit /b 1
            )
        )
    )
)

:: 如果没有指定目标，显示菜单
if "%HAS_ARGS%"=="0" goto show_menu
if "%TARGET%"=="" goto show_menu

:start_build
cls
echo.
echo [96m========================================[0m
echo [96m       Miji 构建脚本 v1.0.0[0m
echo [96m========================================[0m
echo.
echo 目标平台: %TARGET%
if "%DEV_MODE%"=="1" (
    echo 构建模式: [93m开发模式[0m
) else (
    echo 构建模式: [92m生产模式[0m
)
echo.

:: 清理构建产物
if "%CLEAN_BUILD%"=="1" (
    call :clean_artifacts
    if errorlevel 1 exit /b 1
)

:: 检查环境
call :check_environment
if errorlevel 1 exit /b 1

:: 记录开始时间
set "START_TIME=%time%"

:: 执行构建
if /i "%TARGET%"=="windows" (
    call :build_windows
    if errorlevel 1 exit /b 1
) else if /i "%TARGET%"=="android" (
    call :build_android
    if errorlevel 1 exit /b 1
) else if /i "%TARGET%"=="ios" (
    call :build_ios
    if errorlevel 1 exit /b 1
) else if /i "%TARGET%"=="all" (
    call :build_windows
    if errorlevel 1 exit /b 1
    call :build_android
    if errorlevel 1 exit /b 1
    echo [93m注意: iOS 构建需要 macOS 系统[0m
)

:: 计算耗时
set "END_TIME=%time%"

:: 显示成功信息
echo.
echo [92m========================================[0m
echo [92m           构建成功完成！[0m
echo [92m========================================[0m
echo.
goto :eof

:: ========================================
:: 功能函数
:: ========================================

:show_menu
cls
echo.
echo [96m========================================[0m
echo [96m       Miji 构建脚本 v1.0.0[0m
echo [96m========================================[0m
echo.
echo   1. Windows 桌面端 (默认)
echo   2. Android 移动端
echo   3. iOS 移动端 (需要 macOS)
echo   4. 全平台构建
echo   0. 退出
echo.
set /p "MENU_CHOICE=请选择构建目标 (默认: 1): "

if "%MENU_CHOICE%"=="" set "MENU_CHOICE=1"

if "%MENU_CHOICE%"=="1" set "TARGET=windows" & goto start_build
if "%MENU_CHOICE%"=="2" set "TARGET=android" & goto start_build
if "%MENU_CHOICE%"=="3" set "TARGET=ios" & goto start_build
if "%MENU_CHOICE%"=="4" set "TARGET=all" & goto start_build
if "%MENU_CHOICE%"=="0" (
    echo 已取消构建
    exit /b 0
)

echo [91m无效的选择[0m
timeout /t 2 >nul
goto show_menu

:clean_artifacts
echo.
echo [96m==^> 清理构建产物...[0m
echo.

if exist "dist" (
    rmdir /s /q "dist" 2>nul
    echo [92m✓ 已清理 dist 目录[0m
)

if exist "src-tauri\target" (
    rmdir /s /q "src-tauri\target" 2>nul
    echo [92m✓ 已清理 src-tauri\target 目录[0m
)

if exist "src-tauri\gen" (
    rmdir /s /q "src-tauri\gen" 2>nul
    echo [92m✓ 已清理 src-tauri\gen 目录[0m
)

echo [92m✓ 清理完成[0m
goto :eof

:check_environment
echo.
echo [96m==^> 检查构建环境...[0m
echo.

:: 检查 Bun
where bun >nul 2>&1
if errorlevel 1 (
    echo [91m✗ 未找到 bun，请先安装: https://bun.sh[0m
    exit /b 1
)
echo [92m✓ Bun 已安装[0m

:: 检查 Rust
where cargo >nul 2>&1
if errorlevel 1 (
    echo [91m✗ 未找到 Rust，请先安装: https://rustup.rs[0m
    exit /b 1
)
echo [92m✓ Rust 已安装[0m

:: 检查 Android 环境
if /i "%TARGET%"=="android" goto check_android
if /i "%TARGET%"=="all" goto check_android
goto end_check_env

:check_android
where rustup >nul 2>&1
if errorlevel 1 (
    echo [91m✗ 未找到 rustup[0m
    exit /b 1
)

:: 检查 Android 目标
rustup target list --installed | findstr /C:"aarch64-linux-android" >nul 2>&1
if errorlevel 1 (
    echo [93m⚠ Android 构建目标未安装[0m
    echo 正在安装 Android 构建目标...
    rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
    if errorlevel 1 (
        echo [91m✗ Android 目标安装失败[0m
        exit /b 1
    )
)
echo [92m✓ Android 环境已就绪[0m

:end_check_env
goto :eof

:build_windows
echo.
echo [96m==^> 构建 Windows 桌面端...[0m
echo.

if "%DEV_MODE%"=="1" (
    call bun run tauri dev
) else (
    call bun run tauri build
)

if errorlevel 1 (
    echo [91m✗ Windows 桌面端构建失败[0m
    exit /b 1
)

echo.
echo [92m✓ Windows 桌面端构建成功！[0m
echo.
echo [93m安装包位置:[0m
echo   • NSIS 安装程序: src-tauri\target\release\bundle\nsis\
echo   • MSI 安装包: src-tauri\target\release\bundle\msi\
goto :eof

:build_android
echo.
echo [96m==^> 构建 Android 移动端...[0m
echo.

:: 初始化 Android 项目（首次构建）
if not exist "src-tauri\gen\android" (
    echo 首次构建，正在初始化 Android 项目...
    call bun run tauri android init
    if errorlevel 1 (
        echo [91m✗ Android 项目初始化失败[0m
        exit /b 1
    )
)

if "%DEV_MODE%"=="1" (
    call bun run tauri android dev
) else (
    call bun run tauri android build
)

if errorlevel 1 (
    echo [91m✗ Android 移动端构建失败[0m
    exit /b 1
)

echo.
echo [92m✓ Android 移动端构建成功！[0m
echo.
echo [93mAPK 位置:[0m
echo   • Debug: src-tauri\gen\android\app\build\outputs\apk\debug\
echo   • Release: src-tauri\gen\android\app\build\outputs\apk\release\
goto :eof

:build_ios
echo.
echo [91m✗ iOS 构建仅支持 macOS 系统[0m
exit /b 1

:show_help
echo.
echo Miji 构建脚本
echo.
echo 用法:
echo   build.bat [选项]
echo.
echo 选项:
echo   -t, --target ^<platform^>   指定构建目标 (windows/android/ios/all)
echo   -c, --clean              清理构建产物
echo   -d, --dev                开发模式
echo   -h, --help               显示此帮助信息
echo.
echo 示例:
echo   build.bat                      # 交互式菜单
echo   build.bat -t windows           # 构建 Windows 版本
echo   build.bat -t android -c        # 清理并构建 Android 版本
echo   build.bat -t windows -d        # Windows 开发模式
echo.
exit /b 0
