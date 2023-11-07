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

    # 检测端口是否占用
    if [[ $(ss -atunlp | grep ":9100" | wc -l) -ne 0 ]];then
        echo -e "${green}端口已经被占用了 $(ss -atunlp | grep ":9100" | awk '{ print $NF }')${plain}"
        echo -e "${green}如果需要更新请使用默认路径: /usr/local/node_exporter,并且添加参数 update${plain}"
    fi

    # 检测本地是否存在exporter
    if [[ $(ps x | grep -i "node_exporter" | grep -v grep | wc -l) -ne 0 ]];then
        echo -e "${green}系统已经存在exporter $(ps x | grep -i "node_exporter" | grep -v grep | awk '{ print $NF }')${plain}"
        echo -e "${green}如果需要更新请使用默认路径: /usr/local/node_exporter,并且添加参数 update${plain}"
    fi
    
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

get_releases(){
    version=$(curl -m 10 -sL "https://api.github.com/repos/prometheus/node_exporter/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    version_notv=$(echo "${version}"| sed 's/v//g')
    # if [ ! -n "$version" ]; then
    #     version=$(curl -m 10 -sL "https://fastly.jsdelivr.net/gh/nezhahq/agent/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/agent@/v/g')
    # fi

    if [ ! -n "$version" ]; then
        echo -e "获取版本号失败，请检查本机能否链接 https://api.github.com/repos/prometheus/node_exporter/releases"
        return 0
    # else
    #     echo -e "当前最新版本为: ${version}"
    fi
}

# get_releases
version="v1.6.1"
version_notv="1.6.1"

download_file(){
    # https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    wget -t 2 -T 10 -O /tmp/node_exporter-${version_notv}.linux-${os_arch}.tar.gz https://${GITHUB_URL}/prometheus/node_exporter/releases/download/${version}/node_exporter-${version_notv}.linux-${os_arch}.tar.gz >/dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo -e "${red}Release 下载失败,请检查本机能否连接 ${GITHUB_URL}${plain}"
    else
        echo -e "${green}Release 下载成功,MD5:$(md5sum /tmp/node_exporter-${version_notv}.linux-${os_arch}.tar.gz)${plain}" 
    fi
}

add_systemd(){
if [ ! -f /usr/lib/systemd/system/node_exporter.service ];then
cat >> /usr/lib/systemd/system/node_exporter.service << EOF
[Unit]
Description=node_export
Documentation=https://github.com/prometheus/node_exporter
After=network.target
[Service]
Type=simple
User=root
ExecStart= /usr/local/node_exporter/node_exporter
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart node_exporter.service && systemctl enable node_exporter.service
else
    echo -e "${green}/usr/lib/systemd/system/node_exporter.service 文件存在退出${plain}" && return 0
fi
}

sys_systemd(){
    add_systemd
    [[ $? -eq 0 ]] && echo -e "${green}自启动添加完成${plain}" || echo -e "${green}自启动添加失败${plain}"
}

install(){
    if [[ ${local_version} == ${version_notv} ]];then
        echo -e "${green}目前已经是最新版了,无须更新${plain}" && return 0
    fi

    download_file

    if [ ! -d /usr/local/node_exporter ];then
        mkdir -p /usr/local/node_exporter
        echo -e "${green}/usr/local/node_exporter文件夹已创建${plain}"
    fi
    
    if [ -f /tmp/node_exporter-${version_notv}.linux-${os_arch}.tar.gz ];then
        tar -zxvf /tmp/node_exporter-${version_notv}.linux-${os_arch}.tar.gz -C /usr/local/node_exporter --overwrite
        [[ $? -eq 0 ]] && echo -e "${green}文件解压完成${plain}"
    else
        echo -e "${red}获取文件失败${plain}" && exit 1;
    fi

    if [ -d /usr/local/node_exporter/node_exporter-${version_notv}.linux-amd64 ];then
        mv -f /usr/local/node_exporter/node_exporter-${version_notv}.linux-amd64/* /usr/local/node_exporter/
        [[ $? -eq 0 ]] && echo -e "${green}文件覆盖完成${plain}"
        if [ -d /usr/local/node_exporter/node_exporter-${version_notv}.linux-amd64 ];then
            rm -rf /usr/local/node_exporter/node_exporter-${version_notv}.linux-amd64
            [[ $? -eq 0 ]] && echo -e "${green}清理多余文件完成${plain}"
            add_systemd
            [[ $? -eq 0 ]] && echo -e "${green}自启动添加完成${plain}" || echo -e "${green}自启动添加失败${plain}"
        fi
    else
        echo -e "${red}覆盖文件失败${plain}" && exit 1;
    fi
}

update(){
    if [ -f /usr/local/node_exporter/node_exporter ];then
        local_version="$(/usr/local/node_exporter/node_exporter --version | grep -Eiow "version [0-9]+\.[0-9]+\.[0-9]+" | grep -Eiow "[0-9]+\.[0-9]+\.[0-9]+")"
        local_exits=$(echo -e "${green}已安装${plain}")
    else
        local_version="未安装,或者并非/usr/local/node_exporter"
        local_exits=$(echo -e "${green}未安装${plain}")
    fi
    
    if [[ ${local_version} == ${version_notv} ]];then
        echo -e "${green}目前已经是最新版了,无须更新${plain}" && exit 1
    fi
    download_file
    install
}
# 菜单界面
while true :
do
    if [[ $1 == "" ]];then
        echo "未接收到相关参数"
    elif [[ $1 == "update" ]];then
        update
    fi

    if [ -f /usr/local/node_exporter/node_exporter ];then
        local_version="$(/usr/local/node_exporter/node_exporter --version | grep -Eiow "version [0-9]+\.[0-9]+\.[0-9]+" | grep -Eiow "[0-9]+\.[0-9]+\.[0-9]+")"
        local_exits=$(echo -e "${green}已安装${plain}")
    else
        local_version="未安装,或者并非/usr/local/node_exporter"
        local_exits=$(echo -e "${green}未安装${plain}")
    fi

    if [ ${local_version} == ${version_notv} ];then
        update_status=$(echo -e "${green}无更新${plain}")
    else
        update_status=$(echo -e "${red}可更新${plain}")
    fi

    if [ -f /usr/lib/systemd/system/node_exporter.service ];then
        systemd_status=$(echo -e "${green}自启动存在${plain}")
    else
        systemd_status=$(echo -e "${green}自启动不存在${plain}")
    fi
    read -p "1.安装 ${local_exits}[默认路径:/usr/local/node_exporter,请注意会默认清空路径下的所有文件]
2.更新 - 本地版本: v${local_version} , 最新版本：${version} , ${update_status}
3.添加自启动 ${systemd_status},需要覆盖请手动删除
99.卸载[无计划\未实现]
任意键退出...
选择功能:" node_option
    case $node_option in
    1)  install;;
    2)  update;;
    3)  sys_systemd;;
    *)  exit;;
    esac
done