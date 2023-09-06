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
此脚本用于卸载sidecar服务
会删除以下目录: 
  $INSTALL_PATH
  /usr/lib/systemd/system/sidecar.service
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
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help|-\?)
            usage_and_exit 0
            ;;
        *)
            error "未知参数 '$1'"
            ;;
    esac
    shift
done

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    error "请使用root用户执行此脚本"
fi

# 检查是否为Linux系统
if [ "$(uname)" != "Linux" ]; then
    error "此脚本仅支持Linux系统"
fi

# 检查是否为systemd进程管理
if [ ! -d "/run/systemd/system" ]; then
    error "此脚本仅支持systemd进程管理"
fi

# 检查是否已安装
if [ ! -d "$INSTALL_PATH" ]; then
    error "未安装sidecar"
fi

# 检查是否已注册服务
if [ ! -f "/usr/lib/systemd/system/sidecar.service" ]; then
    error "未注册sidecar服务"
fi

# 用户手动确认
red_echo "此操作将卸载sidecar服务，是否继续？[y/n]"
read -r -p "" input
if [ "$input" != "y" ]; then
    exit 0
fi

# 停止服务
systemctl stop sidecar.service
green_echo "停止服务成功"

# 删除服务
rm -vf /usr/lib/systemd/system/sidecar.service
green_echo "删除服务成功"

# 删除安装目录
rm -rvf "$INSTALL_PATH"
green_echo "删除安装目录成功"

green_echo "卸载成功"