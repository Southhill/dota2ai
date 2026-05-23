@REM 部署脚本：将本项目部署到 Dota2 的 Bot 脚本目录（本地测试用 bots 文件夹）
@REM 开发完成后，上传创意工坊时使用 Agent2026 名称
@echo off
chcp 65001 >nul

set STEAM_PATH=D:\SteamLibrary
set DEST_DIR=%STEAM_PATH%\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots

echo ========================================
echo  部署 Bot AI 到 Dota2（本地测试）
echo ========================================
echo.
echo 目标目录: %DEST_DIR%
echo 提示: Dota2 中将显示为"本地开发脚本"
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
    echo [信息] 目录已存在，将覆盖文件
)

:: 复制 src/ 下的所有 Lua 源码到 Dota2 目录
xcopy /E /Y /I "%~dp0..\src\*" "%DEST_DIR%"

echo.
echo ========================================
echo  部署完成!
echo ========================================
echo.
echo  下一步:
echo   1. 启动 Dota2
echo   2. 创建私人房间 (Practice Lobby)
echo   3. 在 Bot 选择菜单中选中 "本地开发脚本"
echo   4. 开始游戏!
echo.
echo  [提示] 开发完成后，上传创意工坊时再用 Agent2026 名称
echo.
pause
