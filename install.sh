#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin

GITHUB_URL="github.com"
os_arch=""
[ -e /etc/os-release ] && cat /etc/os-release | grep -i "PRETTY_NAME" | grep -qi "alpine" && os_alpine='1'

pre_check() {
    [ "$os_alpine" != 1 ] && ! command -v systemctl >/dev/null 2>&1 && echo "不支持此系统：未找到 systemctl 命令" && exit 1
    
    # check root
    [[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1
    
    ## os_arch
    if [[ $(uname -m | grep 'x86_64') != "" ]]; then
        os_arch="amd64"
        elif [[ $(uname -m | grep 'i386\|i686') != "" ]]; then
        os_arch="386"
        elif [[ $(uname -m | grep 'aarch64\|armv8b\|armv8l') != "" ]]; then
        os_arch="arm64"
        elif [[ $(uname -m | grep 'arm') != "" ]]; then
        os_arch="arm"
        elif [[ $(uname -m | grep 's390x') != "" ]]; then
        os_arch="s390x"
        elif [[ $(uname -m | grep 'riscv64') != "" ]]; then
        os_arch="riscv64"
    fi
}

pre_check

version=$(curl -m 10 -sL "https://api.github.com/repos/prometheus/node_exporter/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
version_notv=$(echo "${version}"| sed 's/v//g')
# if [ ! -n "$version" ]; then
#     version=$(curl -m 10 -sL "https://fastly.jsdelivr.net/gh/nezhahq/agent/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/agent@/v/g')
# fi

if [ ! -n "$version" ]; then
    echo -e "获取版本号失败，请检查本机能否链接 https://api.github.com/repos/prometheus/node_exporter/releases"
    return 0
else
    echo -e "当前最新版本为: ${version}"
fi

# https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
wget -t 2 -T 10 -O node_exporter-${version_notv}.linux-${os_arch}.tar.gz https://${GITHUB_URL}/prometheus/node_exporter/releases/download/${version}/node_exporter-${version_notv}.linux-${os_arch}.tar.gz >/dev/null 2>&1
if [[ $? != 0 ]]; then
    echo -e "${red}Release 下载失败，请检查本机能否连接 ${GITHUB_URL}${plain}"
else
    echo -e "${green}Release 下载成功，MD5:$(md5sum node_exporter-${version_notv}.linux-${os_arch}.tar.gz)${plain}" 
fi
