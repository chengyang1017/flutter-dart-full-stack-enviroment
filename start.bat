@echo off
REM Flutter Playground - Windows 快速启动脚本

setlocal enabledelayedexpansion

echo.
echo ===============================================================
echo  Flutter Playground - Docker Compose 快速启动
echo ===============================================================
echo.

REM 检查 Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker 未安装或未在 PATH 中
    pause
    exit /b 1
)

echo [OK] Docker 已安装

REM 检查 Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Compose 未安装或未在 PATH 中
    pause
    exit /b 1
)

echo [OK] Docker Compose 已安装

REM 环境配置
if not exist .env (
    echo [WARN] .env 文件不存在，复制 .env.example
    copy .env.example .env
)

echo.
echo 启动服务...
echo.

REM 启动服务
docker-compose up -d

echo.
echo [OK] 服务启动成功！
echo.

REM 等待服务就绪
echo 等待服务就绪 (5 秒)...
timeout /t 5 /nobreak

echo.
echo ===============================================================
echo  启动完成！
echo ===============================================================
echo.
echo  Web 应用: http://localhost:8080
echo  Runner:   http://localhost:8787
echo.
echo  常用命令:
echo   查看日志:     docker-compose logs -f
echo   停止服务:     docker-compose down
echo   查看状态:     docker-compose ps
echo.
echo ===============================================================
echo.

REM 尝试打开浏览器
start http://localhost:8080 2>nul

pause
