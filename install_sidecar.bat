@echo off
chcp 65001
setlocal

set PROGRAM=%~n0
set VERSION=1.0
set EXITCODE=0
set INSTALL_PATH=C:\gse\sidecar

:main
if "%~1" == "-h" goto :usage_and_exit
if "%~1" == "--help" goto :usage_and_exit
set NODE_ID=%~1
set API_TOKEN=%~2
set SERVER_URL=%~3
call :gengerate_config
call :register_service
goto :eof


:usage
echo 用法:
echo     %PROGRAM% node-id api-token server-url
echo              [ -h   --help         [可选] "查看帮助" ]
echo              [ node-id             [必填] "sidecar配置文件的节点信息,一般为 '云区域-ip' 如 0-10.10.10.10" ]
echo              [ api-token           [必填] "sidecar获取配置的token" ]
echo              [ server-url          [必填] "datainsight的访问ip,sidecar从此url获取配置" ]
goto :eof

:usage_and_exit
call :usage
exit /b %1

:error
call :echo %*
call :usage_and_exit 1

:warning
call :echo %*
set /a EXITCODE+=1
goto :eof

:gengerate_config
set CONFIG_PATH=sidecar.conf
echo. > %CONFIG_PATH%
1>> "%CONFIG_PATH%" (
   echo # The URL to the Graylog server API.
   echo server_url: "%SERVER_URL%/api"
   echo # The API token to use to authenticate against the Graylog server API.
   echo # This field is mandatory
   echo server_api_token: "%API_TOKEN%"
   echo # The node ID of the sidecar. This can be a path to a file or an ID string.
   echo # If set to a file and the file doesn't exist, the sidecar will generate an
   echo # unique ID and writes it to the configured path.
   echo # ATTENTION: Every sidecar instance needs a unique ID!
   echo #
   echo node_id: "%NODE_ID%"
   echo # The node name of the sidecar. If this is empty, the sidecar will use the
   echo # hostname of the host it is running on.
   echo node_name: "%NODE_ID%"
   echo # 配置更新时间，单位为秒
   echo update_interval: 10
   echo # tls校验
   echo tls_skip_verify: false
   echo # sidecar采集基础信息，需开启
   echo send_status: true
   echo # graylog页面展示日志文件清单，无需开启
   echo list_log_files: []
   echo # Directory where the sidecar stores internal data.
   echo cache_path: "C:\\gse\\sidecar\\cache"
   echo # Directory where the sidecar stores logs for collectors and the sidecar itself.
   echo log_path: "C:\\gse\\sidecar\\logs"
   echo # 日志文件最大大小
   echo log_rotate_max_file_size: "10MiB"
   echo # 日志保存个数
   echo log_rotate_keep_files: 5
   echo # How long to wait for the config validation command.
   echo collector_validation_timeout: "1m"
   echo # How long to wait for the collector to gracefully shutdown.
   echo # After this timeout the sidecar tries to terminate the collector with SIGKILL
   echo collector_shutdown_timeout: "10s"
   echo # 生成子插件配置文件的目录
   echo collector_configuration_directory: "C:\\gse\\sidecar\\generated"
   echo # windows磁盘占用扫描的盘符，无需开启
   echo windows_drive_range: ""
   echo # A list of tags to assign to this sidecar. Collector configuration matching any of these tags will automatically be
   echo # applied to the sidecar.
   echo # Default: []
   echo tags: []
   echo # 托管的可执行文件路径，分发时应与此目录匹配
   echo collector_binaries_accesslist:
   echo - "C:\\gse\\sidecar\\bin\\filebeat.exe"
   echo - "C:\\gse\\sidecar\\bin\\packetbeat.exe"
   echo - "C:\\gse\\sidecar\\bin\\winlogbeat.exe" >> %CONFIG_PATH%
)
echo "配置文件生成成功"
goto :eof

:register_service
rem 注册服务到windows service,使用最简参数创建服务
sc create sidecar binPath= "%INSTALL_PATH%\sidecar.exe -c %INSTALL_PATH%\sidecar.conf" start= auto
echo "服务注册成功"
sc start sidecar
rem 等待十秒服务启动
timeout /t 10
rem 判断服务是否启动成功
sc query sidecar | findstr "RUNNING"
if %errorlevel% == 0 (
    echo "服务启动成功"
) else (
    echo "服务启动失败"
)
goto :eof

:init_directory
if not exist "%INSTALL_PATH%" mkdir "%INSTALL_PATH%"
if not exist "%INSTALL_PATH%\cache" mkdir "%INSTALL_PATH%\cache"
if not exist "%INSTALL_PATH%\logs" mkdir "%INSTALL_PATH%\logs"
if not exist "%INSTALL_PATH%\bin" mkdir "%INSTALL_PATH%\bin"
if not exist "%INSTALL_PATH%\generated" mkdir "%INSTALL_PATH%\generated"
if not exist "%LOG_PATH%" mkdir "%LOG_PATH%"
goto :eof