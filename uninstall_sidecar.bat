@echo off
chcp 65001
setlocal

rem 接收用户确认
echo "此操作会删除sidecar服务及其配置文件，但不会删除日志文件"
echo "确认卸载sidecar服务吗？[y/n]"
set /p confirm=输入y或n并回车:
if "%confirm%" == "y" goto :uninstall
if "%confirm%" == "n" goto :cancel
goto :error

rem 停止sidecar服务
echo "停止sidecar服务"
net stop sidecar

rem 删除sidecar服务
echo "删除sidecar服务"
sc delete sidecar

rem 删除sidecar文件夹
echo "清空C:\gse\sidecar文件夹"
rmdir /s /q C:\gse\sidecar

echo "卸载完成"