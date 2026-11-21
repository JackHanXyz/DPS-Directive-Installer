@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
:menu
cls
echo =========================================
echo  DPS 桌面版破甲插件 管理菜单
echo =========================================
echo  1. 查看状态
echo  2. 安装 / 修复安装
echo  3. 更新插件
echo  4. 卸载插件
echo  0. 退出
echo.
set /p choice=请选择 [0-4]:
if "%choice%"=="1" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dsh-dps.ps1" -Action status
if "%choice%"=="2" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dsh-dps.ps1" -Action install
if "%choice%"=="3" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dsh-dps.ps1" -Action update
if "%choice%"=="4" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dsh-dps.ps1" -Action uninstall
if "%choice%"=="0" exit /b
pause
goto menu
