@REM 部署脚本：将本项目部署到 Dota2 的 Bot 脚本目录（本地测试用 bots 文件夹）
@REM 开发完成后，上传创意工坊时使用 Agent2026 名称
@echo off
chcp 65001 >nul

set STEAM_PATH=D:\SteamLibrary
set DEST_DIR=%STEAM_PATH%\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots
set SRC_DIR=%~dp0..\src

echo ========================================
echo  部署 Bot AI 到 Dota2（本地测试）
echo ========================================
echo.
echo 源码目录: %SRC_DIR%
echo 目标目录: %DEST_DIR%
echo.

:: 检查 Steam 路径是否存在
if not exist "%STEAM_PATH%" (
    echo [警告] 默认 Steam 路径不存在: %STEAM_PATH%
    echo 请在下面输入你的 Steam 安装路径:
    set /p STEAM_PATH="Steam 路径: "
    set DEST_DIR=%STEAM_PATH%\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots
)

:: 创建目标目录
if not exist "%DEST_DIR%" (
    mkdir "%DEST_DIR%"
    echo [OK] 已创建目录
) else (
    echo [信息] 目录已存在，将创建备份...
    for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value ^| find "="') do set datetime=%%I
    set BACKUP_DIR=%DEST_DIR%_backup_%datetime:~0,8%_%datetime:~8,6%
    xcopy /E /Y /I "%DEST_DIR%" "%BACKUP_DIR%" >nul
    echo [OK] 备份已保存
)

:: 统计源码文件数
set FILE_COUNT=0
for /r "%SRC_DIR%" %%F in (*) do set /a FILE_COUNT+=1
set LUA_COUNT=0
for /r "%SRC_DIR%" %%F in (*.lua) do set /a LUA_COUNT+=1

:: 复制 src/ 下的所有文件到 Dota2 目录
xcopy /E /Y /I "%SRC_DIR%\*" "%DEST_DIR%"

echo.
echo ========================================
echo  部署完成! 共 %FILE_COUNT% 个文件（含 %LUA_COUNT% 个 Lua）
echo ========================================
echo.
echo  下一步:
echo   1. 启动 Dota2
echo   2. 创建私人房间 (Practice Lobby)
echo   3. 在 Bot 选择菜单中选中 "本地开发脚本"
echo   4. 开始游戏!
echo.
echo  [提示] 游戏内可用 dota_bot_reload_scripts 重新加载脚本
echo  [提示] 开发完成后，上传创意工坊时再用 Agent2026 名称
echo.
pause
