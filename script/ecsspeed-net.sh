#!/usr/bin/env bash
# by spiritlhl
# from https://github.com/spiritLHLS/ecsspeed


ecsspeednetver="2023/04/01"
spver="1.2.0"
SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
cd /root >/dev/null 2>&1
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"
_red() { echo -e "\033[31m\033[01m$@\033[0m"; }
_green() { echo -e "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }
reading(){ read -rp "$(_green "$1")" "$2"; }
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "arch")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Arch")
PACKAGE_UPDATE=("! apt-get update && apt-get --fix-broken install -y && apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "pacman -Sy")
PACKAGE_INSTALL=("apt-get -y install" "apt-get -y install" "yum -y install" "yum -y install" "yum -y install" "pacman -Sy --noconfirm --needed")
PACKAGE_REMOVE=("apt-get -y remove" "apt-get -y remove" "yum -y remove" "yum -y remove" "yum -y remove" "pacman -Rsc --noconfirm")
PACKAGE_UNINSTALL=("apt-get -y autoremove" "apt-get -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')" "$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)") 
SYS="${CMD[0]}"
[[ -n $SYS ]] || exit 1
for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        [[ -n $SYSTEM ]] && break
    fi
done
apt-get --fix-broken install -y > /dev/null 2>&1

checkroot(){
    _yellow "checking root"
	[[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 用户运行本脚本！${PLAIN}" && exit 1
}

checksystem() {
	if [ -f /etc/redhat-release ]; then
	    release="centos"
	elif cat /etc/issue | grep -Eqi "debian"; then
	    release="debian"
	elif cat /etc/issue | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	elif cat /proc/version | grep -Eqi "debian"; then
	    release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
    elif cat /etc/os-release | grep -Eqi "almalinux"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "arch"; then
        release="arch"
	fi
}

checkupdate(){
	    _yellow "Updating package management sources"
		${PACKAGE_UPDATE[int]} > /dev/null 2>&1
        ${PACKAGE_INSTALL[int]} dmidecode > /dev/null 2>&1
        apt-key update > /dev/null 2>&1
}

checkcurl() {
    _yellow "checking curl"
	if  [ ! -e '/usr/bin/curl' ]; then
            _yellow "Installing curl"
	        ${PACKAGE_INSTALL[int]} curl
	fi
    if [ $? -ne 0 ]; then
        apt-get -f install > /dev/null 2>&1
        ${PACKAGE_INSTALL[int]} curl
    fi
}

checkwget() {
    _yellow "checking wget"
	if  [ ! -e '/usr/bin/wget' ]; then
            _yellow "Installing wget"
	        ${PACKAGE_INSTALL[int]} wget
	fi
}

checktar() {
    _yellow "checking tar"
	if  [ ! -e '/usr/bin/tar' ]; then
            _yellow "Installing tar"
	        ${PACKAGE_INSTALL[int]} tar 
	fi
    if [ $? -ne 0 ]; then
        apt-get -f install > /dev/null 2>&1
        ${PACKAGE_INSTALL[int]} tar > /dev/null 2>&1
    fi
}

checkping() {
    _yellow "checking ping"
	if  [ ! -e '/usr/bin/ping' ]; then
            _yellow "Installing ping"
	        ! ${PACKAGE_INSTALL[int]} iputils-ping || ${PACKAGE_INSTALL[int]} ping > /dev/null 2>&1
	fi
}

SystemInfo_GetOSRelease() {
    _yellow "checking OS"
    if [ -f "/etc/centos-release" ]; then # CentOS
        Var_OSRelease="centos"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_CentOSELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_CentOSELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_CentOSELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        else
            local Var_CentOSELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/fedora-release" ]; then # Fedora
        Var_OSRelease="fedora"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseVersion="$(cat /etc/fedora-release | awk '{print $3,$4,$5,$6,$7}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/redhat-release" ]; then # RedHat
        Var_OSRelease="rhel"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_RedHatELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_RedHatELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_RedHatELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        else
            local Var_RedHatELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/lsb-release" ]; then # Ubuntu
        Var_OSRelease="ubuntu"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/os-release | awk -F '[= "]' '/VERSION/{print $3,$4,$5,$6,$7}' | head -n1)"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
        Var_OSReleaseVersion_Short="$(cat /etc/lsb-release | awk -F '[= "]' '/DISTRIB_RELEASE/{print $2}')"
    elif [ -f "/etc/debian_version" ]; then # Debian
        Var_OSRelease="debian"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        local Var_OSReleaseVersion="$(cat /etc/debian_version | awk '{print $1}')"
        local Var_OSReleaseVersionShort="$(cat /etc/debian_version | awk '{printf "%d\n",$1}')"
        if [ "${Var_OSReleaseVersionShort}" = "7" ]; then
            Var_OSReleaseVersion_Short="7"
            Var_OSReleaseVersion_Codename="wheezy"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Wheezy\""
        elif [ "${Var_OSReleaseVersionShort}" = "8" ]; then
            Var_OSReleaseVersion_Short="8"
            Var_OSReleaseVersion_Codename="jessie"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Jessie\""
        elif [ "${Var_OSReleaseVersionShort}" = "9" ]; then
            Var_OSReleaseVersion_Short="9"
            Var_OSReleaseVersion_Codename="stretch"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Stretch\""
        elif [ "${Var_OSReleaseVersionShort}" = "10" ]; then
            Var_OSReleaseVersion_Short="10"
            Var_OSReleaseVersion_Codename="buster"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Buster\""
        else
            Var_OSReleaseVersion_Short="sid"
            Var_OSReleaseVersion_Codename="sid"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Sid (Testing)\""
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/alpine-release" ]; then # Alpine Linux
        Var_OSRelease="alpinelinux"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3,$4}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/alpine-release | awk '{print $1}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/almalinux-release" ]; then # almalinux
        Var_OSRelease="almalinux"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseVersion="$(cat /etc/almalinux-release | awk '{print $3,$4,$5,$6,$7}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/arch-release" ]; then # archlinux
        Var_OSRelease="arch"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseArch="$(uname -m)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName ($Var_OSReleaseArch)" # 滚动发行版 不存在版本号
    else
        Var_OSRelease="unknown" # 未知系统分支
        LBench_Result_OSReleaseFullName="[Error: Unknown Linux Branch !]"
    fi
}


SystemInfo_GetSystemBit() {
    _yellow "checking SystemBit"
    local sysarch="$(uname -m)"
    if [ "${sysarch}" = "unknown" ] || [ "${sysarch}" = "" ]; then
        local sysarch="$(arch)"
    fi
    # 根据架构信息设置系统位数并下载文件,其余 * 包括了 x86_64
    case "${sysarch}" in
        "i386" | "i686")
            LBench_Result_SystemBit_Short="32"
            LBench_Result_SystemBit_Full="i386"
            BESTTRACE_FILE=besttracemac
            ;;
        "armv7l" | "armv8" | "armv8l" | "aarch64")
            LBench_Result_SystemBit_Short="arm"
            LBench_Result_SystemBit_Full="arm"
            BESTTRACE_FILE=besttracearm
            BACKTRACE_FILE=backtrace-linux-arm64.tar.gz
            ;;
        *)
            LBench_Result_SystemBit_Short="64"
            LBench_Result_SystemBit_Full="amd64"
            BESTTRACE_FILE=besttrace
            BACKTRACE_FILE=backtrace-linux-amd64.tar.gz
            ;;
    esac
}


Check_JSONQuery() {
    _yellow "checking jq"
    # 判断 jq 命令是否存在
    if ! command -v jq > /dev/null; then
        # 获取系统位数
        SystemInfo_GetSystemBit
        # 获取操作系统版本
        SystemInfo_GetOSRelease
        # 根据系统位数设置下载地址
        local DownloadSrc
        if [ -z "${LBench_Result_SystemBit_Short}" ] || [ "${LBench_Result_SystemBit_Short}" != "amd64" ] || [ "${LBench_Result_SystemBit_Short}" != "i386" ]; then
            DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/JSONQuery/jq-i386.tar.gz"
        else
            DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/JSONQuery/jq-${LBench_Result_SystemBit_Short}.tar.gz"
            # local DownloadSrc="https://raw.githubusercontent.com/LemonBench/LemonBench/master/Resources/JSONQuery/jq-amd64.tar.gz"
            # local DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/jq/1.6/amd64/jq.tar.gz"
            # local DownloadSrc="https://raw.githubusercontent.com/LemonBench/LemonBench/master/Resources/JSONQuery/jq-i386.tar.gz"
            # local DownloadSrc="https://raindrop.ilemonrain.com/LemonBench/include/jq/1.6/i386/jq.tar.gz"
        fi
        mkdir -p ${WorkDir}/
        echo -e "${Msg_Warning}JSON Query Module not found, Installing ..."
        echo -e "${Msg_Info}Installing Dependency ..."
        if [[ "${Var_OSRelease}" =~ ^(centos|rhel|almalinux)$ ]]; then
            yum install -y epel-release
            if [ $? -ne 0 ]; then
                if [ "$(grep -Ei 'centos|almalinux' /etc/os-release | awk -F'=' '{print $2}')" == "AlmaLinux" ]; then
                    cd /etc/yum.repos.d/
                    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/AlmaLinux-*
                    sed -i 's|#baseurl=https://repo.almalinux.org/|baseurl=https://vault.almalinux.org/|g' /etc/yum.repos.d/AlmaLinux-*
                    yum makecache
                else
                    cd /etc/yum.repos.d/
                    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
                    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
                    yum makecache
                fi
                if [ $? -ne 0 ]; then
                    yum -y update && yum install -y epel-release
                fi
            fi
            yum install -y tar
            yum install -y jq
        elif [[ "${Var_OSRelease}" =~ ^debian$ ]]; then
            ! apt-get update && apt-get --fix-broken install -y && apt-get update
            ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install jq -y
            if [ $? -ne 0 ]; then
                ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install jq -y --force-yes
            fi
            if [ $? -ne 0 ]; then
                ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install jq -y --allow
            fi
        elif [[ "${Var_OSRelease}" =~ ^ubuntu$ ]]; then
            ! apt-get update && apt-get --fix-broken install -y && apt-get update
            ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install jq -y
            if [ $? -ne 0 ]; then
                ! apt-get install -y jq && apt-get --fix-broken install -y && apt-get install jq -y --allow-unauthenticated
            fi
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            dnf install -y jq
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            apk update
            apk add jq
        elif [ "${Var_OSRelease}" = "arch" ]; then
            pacman -Sy --needed --noconfirm jq
        else
            apk update
            apk add wget unzip curl
            echo -e "${Msg_Info}Downloading Json Query Module ..."
            curl --user-agent "${UA_LemonBench}" ${DownloadSrc} -o ${WorkDir}/jq.tar.gz
            echo -e "${Msg_Info}Installing JSON Query Module ..."
            tar xvf ${WorkDir}/jq.tar.gz
            mv ${WorkDir}/jq /usr/bin/jq
            chmod +x /usr/bin/jq
            echo -e "${Msg_Info}Cleaning up ..."
            rm -rf ${WorkDir}/jq.tar.gz
        fi
    fi
    # 二次检测
    if [ ! -f "/usr/bin/jq" ]; then
        echo -e "JSON Query Moudle install Failure! Try Restart Bench or Manually install it! (/usr/bin/jq)"
        exit 1
    fi
}

download_speedtest_file() {
    file="/root/speedtest-cli/speedtest"
    if [[ -e "$file" && "$($file -h >/dev/null 2>&1)" ]]; then
        _green "speedtest found"
        return
    fi
    file="/root/speedtest-cli/speedtest-go"
    if [[ -e "$file" && "$($file -h >/dev/null 2>&1)" ]]; then
        _green "speedtest-go found"
        return
    fi
    local sys_bit="$1"
    local url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
    local url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
    curl --fail -s -m 10 -o speedtest.tgz "${url1}" || curl --fail -s -m 10 -o speedtest.tgz "${url2}"
    if [[ $? -ne 0 ]]; then
        _red "Error: Failed to download official speedtest-cli."
        _yellow "Try using the unofficial speedtest-go"
    fi
    if [ "$sys_bit" = "aarch64" ]; then
        sys_bit="arm64"
    fi
    local url3="https://github.com/showwin/speedtest-go/releases/download/v1.6.0/speedtest-go_1.6.0_${sys_bit}.tar.gz"
    curl --fail -s -m 15 -o speedtest.tar.gz "${cdn_success_url}${url3}" || curl --fail -s -m 10 -o speedtest.tar.gz "${url3}" 
    if [ $? -eq 0 ]; then
        _green "Used unofficial speedtest-go"
    fi
    if [ ! -d "/root/speedtest-cli" ]; then
        mkdir -p "/root/speedtest-cli"
    fi
    if [ -f "./speedtest.tgz" ]; then
        tar -zxf speedtest.tgz -C ./speedtest-cli 2> /dev/null
        rm -f speedtest.tgz
    elif [ -f "./speedtest.tar.gz" ]; then
        tar -zxf speedtest.tar.gz -C ./speedtest-cli 2> /dev/null
        rm -f speedtest.tar.gz
    else
        _red "Error: Failed to download speedtest tool."
        exit 1
    fi
}

install_speedtest() {
    _yellow "checking speedtest"
    sys_bit=""
    local sysarch="$(uname -m)"
    case "${sysarch}" in
        "x86_64"|"x86"|"amd64"|"x64") sys_bit="x86_64";;
        "i386"|"i686") sys_bit="i386";;
        "aarch64"|"armv7l"|"armv8"|"armv8l") sys_bit="aarch64";;
        "s390x") sys_bit="s390x";;
        "riscv64") sys_bit="riscv64";;
        "ppc64le") sys_bit="ppc64le";;
        "ppc64") sys_bit="ppc64";;
        *) sys_bit="x86_64";;
    esac
    download_speedtest_file "${sys_bit}"
}

speed_test() {
    local nodeName="$2"
    if [ ! -f "./speedtest-cli/speedtest" ]; then
        if [ -z "$1" ]; then
            ./speedtest-cli/speedtest-go > ./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest-go --server=$1 > ./speedtest-cli/speedtest.log 2>&1
        fi
    else
        if [ -z "$1" ]; then
            ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest --progress=no --server-id=$1 --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1
        fi
    fi
    if [ $? -ne 0 ]; then
        _red "Error: Segmentation fault"
        _yellow "Please manually install speedtest-go into /root/speedtest-cli"
        rm -rf /root/speedtest-cli/speedtest*
        _yellow "Please check https://github.com/showwin/speedtest-go"
        exit 1
    fi
    if [[ -e "/root/speedtest-cli/speedtest.log" ]] && grep -q "Segmentation fault" "/root/speedtest-cli/speedtest.log"; then
        _red "Error: Segmentation fault"
        _yellow "Please manually install speedtest or speedtest-go into /root/speedtest-cli"
        exit 1
    fi
    if [ $? -eq 0 ]; then
        local dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        local up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        local latency=$(grep -oP 'Idle Latency:\s+\K[\d\.]+' ./speedtest-cli/speedtest.log)
        local packet_loss=$(awk -F': +' '/Packet Loss/{if($2=="Not available."){print "NULL"}else{print $2}}' ./speedtest-cli/speedtest.log)
        if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
            echo -e "${nodeName}\t ${up_speed}\t ${dl_speed}\t ${latency}\t  $packet_loss"
        fi
    fi
    wait
}

test_list() {
    local list=("$@")
    if [ ${#list[@]} -eq 0 ]; then
        echo "列表为空，程序退出"
        exit 1
    fi
    for ((i=0; i<${#list[@]}; i+=1))
    do
        id=$(echo "${list[i]}" | cut -d',' -f1)
        name=$(echo "${list[i]}" | cut -d',' -f2)
        # echo "$id $name"
        speed_test "$id" "$name"
    done
}

temp_head(){
    if [[ $selection =~ ^[1-6]$ ]]; then
        echo "——————————————————————————————————————————————————————————————————————————————"
	    echo -e "位置\t         上传速度\t 下载速度\t 延迟\t  丢包率"
    else
        echo "——————————————————————————————————————————————————————————————————————————————"
	    echo -e "位置\t 上传速度\t下载速度\t 延迟\t 丢包率"
    fi
}

print_end_time() {
    echo "——————————————————————————————————————————————————————————————————————————————"
    end_time=$(date +%s)
    time=$(( ${end_time} - ${start_time} ))
    if [ ${time} -gt 60 ]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo " 总共花费      : ${min} 分 ${sec} 秒"
    else
        echo " 总共花费      : ${time} 秒"
    fi
    date_time=$(date)
    # date_time=$(date +%Y-%m-%d" "%H:%M:%S)
    echo " 时间          : $date_time"
    echo "——————————————————————————————————————————————————————————————————————————————"
}

cdn_urls=("https://cdn.spiritlhl.workers.dev/" "https://shrill-pond-3e81.hunsh.workers.dev/" "https://ghproxy.com/" "http://104.168.128.181:7823/" "https://gh.api.99988866.xyz/")

check_cdn() {
    _yellow "checking CDN"
    local o_url=$1
    for cdn_url in "${cdn_urls[@]}"; do
        if curl -sL -k "$cdn_url$o_url" --max-time 6 | grep -q "success" > /dev/null 2>&1; then
        export cdn_success_url="$cdn_url"
        return
        fi
        sleep 0.5
    done
    export cdn_success_url=""
}

get_data() {
    local url="$1"
    local data=()
    local response
    local retries=0
    while [[ $retries -lt 3 ]]; do
        response=$(curl -s --max-time 3 "$url")
        if [[ $? -eq 0 ]]; then
            break
        else
            retries=$((retries+1))
            sleep 1
        fi
    done
    if [[ $retries -eq 3 ]]; then
        url="${cdn_success_url}${url}"
        response=$(curl -s --max-time 6 "$url")
    fi
    while read line; do
        if [[ -n "$line" ]]; then
            local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $4}')
            if [[ "$id,$city" == "id,city" ]]; then
                continue
            fi
            if [[ $url == *"Mobile"* ]]; then
                city="移动${city}"
            elif [[ $url == *"Telecom"* ]]; then
                city="电信${city}"
            elif [[ $url == *"Unicom"* ]]; then
                city="联通${city}" 
            fi
            data+=("$id,$city")
        fi
    done <<< "$response"
    echo "${data[@]}"
}

ping_test() {
    local ip="$1"
    local result="$(ping -c1 -t6 "$ip" 2>/dev/null | awk -F '/' 'END {print $5}')"
    echo "$ip,$result"
}

get_nearest_data() {
    local url="$1"
    local data=()
    local response
    local retries=0
    while [[ $retries -lt 2 ]]; do
        response=$(curl -s --max-time 6 "$url")
        if [[ $? -eq 0 ]]; then
            break
        else
            retries=$((retries+1))
            sleep 1
        fi
    done
    if [[ $retries -eq 2 ]]; then
        url="${cdn_success_url}${url}"
        response=$(curl -s --max-time 6 "$url")
    fi
    while read line; do
        if [[ -n "$line" ]]; then
            local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $4}')
            local ip=$(echo "$line" | awk -F ',' '{print $5}')
            if [[ "$id,$city,$ip" == "id,city,ip" ]]; then
                continue
            fi
            if [[ $url == *"Mobile"* ]]; then
                city="移动${city}"
            elif [[ $url == *"Telecom"* ]]; then
                city="电信${city}"
            elif [[ $url == *"Unicom"* ]]; then
                city="联通${city}" 
            fi
            data+=("$id,$city,$ip")
        fi
    done <<< "$response"
    
    # 并行ping测试所有IP
    for (( i=0; i<${#data[@]}; i++ )); do
        ip=$(echo "${data[$i]}" | awk -F ',' '{print $3}')
        results[$i]=$(ping_test "$ip" &)
    done
    wait # 等待所有并行ping测试完成
    
    # 将测试结果和data数组合并
    for (( i=0; i<${#data[@]}; i++ )); do
        ping_result=$(echo "${results[$i]}" | awk -F ',' '{print $2}')
        data[$i]="${data[$i]},$ping_result"
    done
    
    # 检查data数组中是否有足够的元素可供排序并提取前两个元素
    if [[ ${#data[@]} -lt 2 ]]; then
        sorted_data=("${data[@]}")
    else
        # 排序并提取前两个元素
        sorted_data=($(echo "${data[@]}" | tr ' ' '\n' | sort -t',' -k4 -n | head -n 2))
    fi
    
    # 去除IP信息
    for (( i=0; i<${#sorted_data[@]}; i++ )); do
        sorted_data[$i]=$(echo "${sorted_data[$i]}" | awk -F ',' '{print $1","$2}')
    done
    
    # 返回结果
    echo "${sorted_data[@]}"
}


preinfo() {
	echo "———————————————————————————————— ecsspeed-net ————————————————————————————————"
	echo "       bash <(wget -qO- bash.spiritlhl.net/ecs-net)"
	echo "       仓库：https://github.com/spiritLHLS/ecsspeed"
	echo "       节点更新: $csv_date  | 脚本更新: $ecsspeednetver | speedtest版本: $spver"
	echo "——————————————————————————————————————————————————————————————————————————————"
}

selecttest() {
	echo -e "  测速类型:    ${GREEN}1.${PLAIN} 三网测速    ${GREEN}2.${PLAIN} 取消测速"
	echo -e "               ${GREEN}3.${PLAIN} 联通节点    ${GREEN}4.${PLAIN} 电信节点    ${GREEN}5.${PLAIN} 移动节点"
    echo -e "               ${GREEN}6.${PLAIN} 详细三网测速 "
	echo -ne "               ${GREEN}7.${PLAIN} 香港节点    ${GREEN}8.${PLAIN} 台湾节点"
	while :; do echo
			read -p "  请输入数字选择测速类型: " selection
			if [[ ! $selection =~ ^[1-8]$ ]]; then
					echo -ne "  ${RED}输入错误${PLAIN}, 请输入正确的数字!"
			else
					break   
			fi
	done
}

runtest() {
    case ${selection} in
        8)
            _yellow "checking speedtest server ID"
            slist=($(get_data "${SERVER_BASE_URL}/TW.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        7)
            _yellow "checking speedtest server ID"
            slist=($(get_data "${SERVER_BASE_URL}/HK.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        6)
            _yellow "checking speedtest server ID"
            CN_Unicom=($(get_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
            CN_Telecom=($(get_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
            CN_Mobile=($(get_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
            temp_head
            test_list "${CN_Unicom[@]}"
            test_list "${CN_Telecom[@]}"
            test_list "${CN_Mobile[@]}"
            ;;
        5)
            _yellow "checking speedtest server ID"
            slist=($(get_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        4)
            _yellow "checking speedtest server ID"
            slist=($(get_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        3)
            _yellow "checking speedtest server ID"
            slist=($(get_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        1)
            checkping
            _yellow "checking speedtest server ID and find nearest server"
            CN_Unicom=($(get_nearest_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
            CN_Telecom=($(get_nearest_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
            CN_Mobile=($(get_nearest_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
            temp_head
            # echo "${CN_Unicom[@]}"
            # echo "${CN_Telecom[@]}"
            # echo "${CN_Mobile[@]}"
            test_list "${CN_Unicom[@]}"
            test_list "${CN_Telecom[@]}"
            test_list "${CN_Mobile[@]}"
            ;;
        *)
            echo "Invalid selection"
            exit 1
            ;;
    esac
}


main() {
    preinfo
    selecttest
    start_time=$(date +%s)
    runtest
}

checkroot
checksystem
checkupdate
checkcurl
checkwget
checktar
SystemInfo_GetOSRelease
SystemInfo_GetSystemBit
Check_JSONQuery
check_cdn
install_speedtest
csv_date=$(curl -s --max-time 6 https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
main
print_end_time
