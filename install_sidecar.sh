#!/bin/bash
# author: ericchen
# email: ericchen@canway.net
# date: 2023-09-05
# version: 1.0
# 此脚本用于sidecar进程的注册
# 仅适用于Linux系统
# 仅支持systemd进程管理
# 运行需要root权限

# 全局变量
PROGRAM=$(basename "$0")
VERSION=1.0
EXITCODE=0
INSTALL_PATH=/usr/local/gse/sidecar
PACKAGE_NAME=sidecar_linux.tar.gz
LOG_PATH=/var/log/gse/sidecar

# 通用函数
red_echo ()      { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[031;1m$@\033[0m"; }
green_echo ()    { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[032;1m$@\033[0m"; }
yellow_echo ()   { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[033;1m$@\033[0m"; }
blue_echo ()     { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[034;1m$@\033[0m"; }
purple_echo ()   { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[035;1m$@\033[0m"; }
bred_echo ()     { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[041;1m$@\033[0m"; }
bgreen_echo ()   { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[042;1m$@\033[0m"; }
byellow_echo ()  { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[043;1m$@\033[0m"; }
bblue_echo ()    { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[044;1m$@\033[0m"; }
bpurple_echo ()  { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[045;1m$@\033[0m"; }
bgreen_echo ()   { [ "$HASTTY" == 0 ] && echo "$@" || echo -e "\033[042;34;1m$@\033[0m"; }

usage () {
    cat <<EOF
用法:
    $PROGRAM 
             [ -h --help -?              [可选] "查看帮助" ]
             [ -n, --node-id             [必填] "sidecar配置文件的节点信息,一般为 'ip-云区域id' 如 10.10.10.10-0" ]
             [ -t, --api-token           [必填] "sidecar获取配置的token" ]
             [ -s, --server-url          [必填] "datainsight的访问ip,sidecar从此url获取配置" ]
             [ -d, --download-url        [必填] "下载sidecar二进制的url" ]
EOF
}

usage_and_exit () {
    usage
    exit "$1"
}

error () {
    red_echo "$@" 1>&2
    usage_and_exit 1
}

warning () {
    yellow_echo "$@" 1>&2
    EXITCODE=$((EXITCODE + 1))
}


# 解析命令行参数，长短混合模式
(( $# == 0 )) && usage_and_exit 1
while (( $# > 0 )); do
    case "$1" in
        -s | --server-url )
            shift
            SERVER_URL=$1
            ;;
        -n | --node-id )
            shift
            NODE_ID=$1
            ;;
        -t | --api-token )
            shift
            API_TOKEN=$1
            ;;
        -d | --download-url )
            shift
            DOWNLOAD_URL=$1
            ;;
        --help | -h | '-?' )
            usage_and_exit 0
            ;;
        -*)
            error "不可识别的参数: $1"
            ;;
        *)
            break
            ;;
    esac
    shift
done

# 参数合法性有效性校验

if [[ -z $SERVER_URL ]]; then
    error "server-url参数不合法"
fi

if [[ -z $NODE_ID ]]; then
    error "node-id参数不合法"
fi

if [[ -z $API_TOKEN ]]; then
    error "api-token参数不合法"
fi

if [[ -z $DOWNLOAD_URL ]]; then
    error "download-url参数不合法"
fi

# 检查当前用户是否拥有root权限
if [[ $EUID -ne 0 ]]; then
    error "请使用root用户执行此脚本"
fi

# 判断当前操作系统是不是systemd托管
if [[ ! -d /usr/lib/systemd/system ]]; then
    error "当前操作系统不支持systemd"
fi

# 初始化安装目录
install -m 755 -d ${INSTALL_PATH} \
                  ${INSTALL_PATH}/bin \
                  ${INSTALL_PATH}/etc \
                  ${INSTALL_PATH}/generated \
                  ${INSTALL_PATH}/cache \
                  ${INSTALL_PATH}/log

chmod 0644 -R ${INSTALL_PATH}

# 从目标服务器获取安装包
green_echo "step.1 开始下载安装包"
curl -o /tmp/${PACKAGE_NAME} ${DOWNLOAD_URL}
green_echo "安装包下载完成"

# 解压安装包
green_echo "step.2 开始解压安装包"
tar -zxvf /tmp/${PACKAGE_NAME} -C /tmp
cp -av /tmp/x86/sidecar ${INSTALL_PATH}/
cp -av /tmp/x86/bin/* ${INSTALL_PATH}/bin/
chmod +x ${INSTALL_PATH}/sidecar ${INSTALL_PATH}/bin/*
green_echo "安装包解压完成"

# 编写systemd配置文件
green_echo "step.3 生成systemd配置文件 /usr/lib/systemd/system/sidecar.service"
cat > /usr/lib/systemd/system/sidecar.service << EOF
[Unit]
Description=sidecar
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_PATH}/sidecar -c ${INSTALL_PATH}/sidecar.conf
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 生成sidecar的配置文件
green_echo "step.3 生成sidecar配置文件 ${INSTALL_PATH}/sidecar.conf"
cat > ${INSTALL_PATH}/sidecar.conf << EOF
# The URL to the Graylog server API.
server_url: "${SERVER_URL}"

# The API token to use to authenticate against the Graylog server API.
# This field is mandatory
server_api_token: "${API_TOKEN}"

# The node ID of the sidecar. This can be a path to a file or an ID string.
# If set to a file and the file doesn't exist, the sidecar will generate an
# unique ID and writes it to the configured path.
#
# Example file path: "file:/etc/graylog/sidecar/node-id"
# Example ID string: "6033137e-d56b-47fc-9762-cd699c11a5a9"
#
# ATTENTION: Every sidecar instance needs a unique ID!
#
node_id: "${NODE_ID}"

# The node name of the sidecar. If this is empty, the sidecar will use the
# hostname of the host it is running on.
node_name: "${NODE_ID}"

# 配置更新时间，单位为秒
update_interval: 10

# tls校验
tls_skip_verify: false

# sidecar采集基础信息,需开启
send_status: true

# graylog页面展示日志文件清单,无需开启
list_log_files: []

# Directory where the sidecar stores internal data.
cache_path: "${INSTALL_PATH}/cache"

# 日志目录
log_path: "${LOG_PATH}"

# 日志文件最大大小
log_rotate_max_file_size: "10MiB"

# 日志保存个数
log_rotate_keep_files: 5

# How long to wait for the config validation command.
collector_validation_timeout: "1m"

# How long to wait for the collector to gracefully shutdown.
# After this timeout the sidecar tries to terminate the collector with SIGKILL
collector_shutdown_timeout: "10s"

# A list of tags to assign to this sidecar. Collector configuration matching any of these tags will automatically be
# applied to the sidecar.
# Default: []
tags: []

# 生成子插件配置文件的目录
collector_configuration_directory: "${INSTALL_PATH}/generated"

# 托管的可执行文件路径，分发时应匹配
collector_binaries_accesslist:
- "${INSTALL_PATH}/bin/filebeat"
- "${INSTALL_PATH}/bin/packetbeat"
- "${INSTALL_PATH}/bin/auditbeat"
- "${INSTALL_PATH}/bin/uniprobe"
EOF

# 激活sidecar服务
green_echo "step.5 激活sidecar服务"
systemctl daemon-reload
systemctl enable sidecar --now

# 检查sidecar服务是否正常运行
green_echo "step.6 检查sidecar服务是否正常运行"
systemctl status sidecar

# 删除临时文件
green_echo "step.7 删除临时文件"
rm -rvf /tmp/${PACKAGE_NAME} /tmp/x86

# 安装完成
green_echo "安装完成"