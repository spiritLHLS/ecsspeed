#!/usr/bin/env bash
# by spiritlhl
# from https://github.com/spiritLHLS/ecsspeed


ecsspeednetver="2023/04/19"
SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main"
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

global_exit(){
    rm -rf /root/speedtest.tgz*
    rm -rf /root/speedtest.tar.gz*
    rm -rf /root/speedtest-cli*
    rm -rf /root/speedtest-cli/speedtest* 
    rm -rf /root/speedtest-cli/LICENSE* 
    rm -rf /root/speedtest-cli/README.md*
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

checknslookup() {
    _yellow "checking nslookup"
	if ! command -v nslookup &> /dev/null; then
        _yellow "Installing dnsutils"
	    ${PACKAGE_INSTALL[int]} dnsutils
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
	    ${PACKAGE_INSTALL[int]} iputils-ping > /dev/null 2>&1
	    ${PACKAGE_INSTALL[int]} ping > /dev/null 2>&1
	fi
}

check_china(){
    if [[ -z "${CN}" ]]; then
        if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
            _yellow "根据ipapi.co提供的信息，当前IP可能在中国"
            read -e -r -p "是否选用中国镜像完成测速工具安装? [Y/n] " input
            case $input in
                [yY][eE][sS] | [yY])
                    echo "使用中国镜像"
                    CN=true
                ;;
                [nN][oO] | [nN])
                    echo "不使用中国镜像"
                ;;
                *)
                    echo "使用中国镜像"
                    CN=true
                ;;
            esac
        fi
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

download_speedtest_file() {
    file="/root/speedtest-cli/speedtest-go"
    if [[ -e "$file" ]]; then
        _green "speedtest-go found"
        return
    fi
    local sys_bit="$1"
    if [ "$sys_bit" = "aarch64" ]; then
        sys_bit="arm64"
    fi
    local url3="https://github.com/showwin/speedtest-go/releases/download/v1.6.0/speedtest-go_1.6.0_Linux_${sys_bit}.tar.gz"
    curl -o speedtest.tar.gz "${cdn_success_url}${url3}"
    if [ $? -eq 0 ]; then
        _green "Used speedtest-go"
    fi
    if [ ! -d "/root/speedtest-cli" ]; then
        mkdir -p "/root/speedtest-cli"
    fi
    if [ -f "./speedtest.tgz" ]; then
        tar -zxf speedtest.tgz -C ./speedtest-cli
        chmod 777 ./speedtest-cli/speedtest
        rm -f speedtest.tgz
    elif [ -f "./speedtest.tar.gz" ]; then
        tar -zxf speedtest.tar.gz -C ./speedtest-cli
        chmod 777 ./speedtest-cli/speedtest-go
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

get_string_length() {
  local nodeName="$1"
  local length
  local converted
  converted=$(echo -n "$nodeName" | iconv -f utf8 -t gb2312 2>/dev/null)
  if [[ $? -eq 0 && -n "$converted" ]]; then
    length=$(echo -n "$converted" | wc -c)
    echo $length
    return
  fi
  converted=$(echo -n "$nodeName" | iconv -f utf8 -t big5 2>/dev/null)
  if [[ $? -eq 0 && -n "$converted" ]]; then
    length=$(echo -n "$converted" | wc -c)
    echo $length
    return
  fi
  length=$(echo -n "$nodeName" | awk '{len=0; for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c~/[^\x00-\x7F]/){len+=2}else{len++}}; print len}')
  echo $length
}

speed_test() {
    local nodeName="$2"
    if [ ! -f "./speedtest-cli/speedtest" ]; then
        if [ -z "$1" ]; then
            ./speedtest-cli/speedtest-go > ./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest-go --custom-url=http://"$1"/upload.php > ./speedtest-cli/speedtest.log 2>&1
        fi
        if [ $? -eq 0 ]; then
            local dl_speed=$(grep -oP 'Download: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            local up_speed=$(grep -oP 'Upload: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            local latency=$(grep -oP 'Latency: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            if [[ -n "${dl_speed}" || -n "${up_speed}" || -n "${latency}" ]]; then
                if [[ $selection =~ ^[1-5]$ ]]; then
                    echo -e "${nodeName}\t ${up_speed}Mbps\t ${dl_speed}Mbps\t ${latency}ms\t"
                else
                    length=$(get_string_length "$nodeName")
                    if [ $length -ge 8 ]; then
		    	echo -e "${nodeName}\t ${up_speed}Mbps\t ${dl_speed}Mbps\t ${latency}ms\t"
                    else
		    	echo -e "${nodeName}\t\t ${up_speed}Mbps\t ${dl_speed}Mbps\t ${latency}ms\t"
                    fi
                fi
            fi
        fi
    fi
}

test_list() {
    local list=("$@")
    if [ ${#list[@]} -eq 0 ]; then
        echo "列表为空，程序退出"
        exit 1
    fi
    for ((i=0; i<${#list[@]}; i+=1))
    do
        host=$(echo "${list[i]}" | cut -d',' -f1)
        name=$(echo "${list[i]}" | cut -d',' -f2)
        # echo "$host $name"
        speed_test "$host" "$name"
    done
}

temp_head(){
    echo "——————————————————————————————————————————————————————————————————————————————"
    if [[ $selection =~ ^[1-5]$ ]]; then
	    echo -e "位置\t         上传速度\t 下载速度\t 延迟"
    else
	    echo -e "位置\t\t 上传速度\t 下载速度\t 延迟"
    fi
}

print_end_time() {
    end_time=$(date +%s)
    time=$(( ${end_time} - ${start_time} ))
    echo "——————————————————————————————————————————————————————————————————————————————"
    if [ ${time} -lt 30 ]
    then
        echo " 本机连通性较差，可能导致测速失败"
    fi
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

check_cdn_file() {
    check_cdn "https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
    if [ -n "$cdn_success_url" ]; then
        _yellow "CDN available, using CDN"
    else
        _yellow "No CDN available, no use CDN"
    fi
}

get_ip_from_url() {
    nslookup -querytype=A $1 | awk '/^Name:/ {next;} /^Address: / { print $2 }'
}

get_data() {
    local url="$1"
    local data=()
    local response
    if [[ -z "${CN}" || "${CN}" != true ]]; then
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
    else
        url="${cdn_success_url}${url}"
        response=$(curl -s --max-time 10 "$url")
    fi
    ip_list=()
    city_list=()
    while read line; do
        if [[ -n "$line" ]]; then
            # local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $9}')
            city=${city/市/}; city=${city/中国/}
            local host=$(echo "$line" | awk -F ',' '{print $6}')
            local host_url=$(echo $host | sed 's/:.*//')
            if [[ "$host,$city" == "host,city" ]]; then
                continue
            fi
            local ip=$(get_ip_from_url ${host_url})
            if [[ $url == *"mobile"* ]]; then
                city="移动${city}"
            elif [[ $url == *"telecom"* ]]; then
                city="电信${city}"
            elif [[ $url == *"unicom"* ]]; then
                city="联通${city}" 
            fi
            if [[ ! " ${ip_list[@]} " =~ " ${ip} " ]] && [[ ! " ${city_list[@]} " =~ " ${city} " ]]; then
                data+=("$host,$city")
                ip_list+=("$ip")
                city_list+=("$city")
            fi
        fi
    done <<< "$response"
    echo "${data[@]}"
}

ping_test() {
    local ip="$1"
    local result="$(ping -c1 -W3 "$ip" 2>/dev/null | awk -F '/' 'END {print $5}')"
    echo "$ip,$result"
}

get_nearest_data() {
    local url="$1"
    local data=()
    local response
    if [[ -z "${CN}" || "${CN}" != true ]]; then
        local retries=0
        while [[ $retries -lt 2 ]]; do
            response=$(curl -s --max-time 2 "$url")
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
    else
        url="${cdn_success_url}${url}"
        response=$(curl -s --max-time 10 "$url")
    fi
    ip_list=()
    city_list=()
    while read line; do
        if [[ -n "$line" ]]; then
            # local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $9}')
            city=${city/市/}; city=${city/中国/}
            local host=$(echo "$line" | awk -F ',' '{print $6}')
            local host_url=$(echo $host | sed 's/:.*//')
            if [[ "$host,$city" == "host,city" ]]; then
                continue
            fi
            local ip=$(get_ip_from_url ${host_url})
            if [[ $url == *"mobile"* ]]; then
                city="移动${city}"
            elif [[ $url == *"telecom"* ]]; then
                city="电信${city}"
            elif [[ $url == *"unicom"* ]]; then
                city="联通${city}" 
            fi
            if [[ ! " ${ip_list[@]} " =~ " ${ip} " ]] && [[ ! " ${city_list[@]} " =~ " ${city} " ]]; then
                data+=("$host,$city")
                ip_list+=("$ip")
                city_list+=("$city")
            fi
        fi
    done <<< "$response"
 
    rm -f /tmp/pingtest
    for (( i=0; i<${#data[@]}; i++ )); do
        { ip=$(echo "${data[$i]}" | awk -F ',' '{print $3}')
        ping_test "$ip" >> /tmp/pingtest; }&
    done
    wait
    
    output=$(cat /tmp/pingtest)
    rm -f /tmp/pingtest
    IFS=$'\n' read -rd '' -a lines <<<"$output"
    results=()
    for line in "${lines[@]}"; do
        field=$(echo "$line" | cut -d',' -f1)
        results+=("$field")
    done

    sorted_data=()
    for result in "${results[@]}"; do
        for item in "${data[@]}"; do
            if [[ "$item" == *"$result"* ]]; then
                host=$(echo "$item" | cut -d',' -f1)
                name=$(echo "$item" | cut -d',' -f2)
                sorted_data+=("$host,$name")
            fi
        done
    done
    sorted_data=("${sorted_data[@]:0:2}")

    echo "${sorted_data[@]}"
}


preinfo() {
	echo "———————————————————————————————— ecsspeed-cn —————————————————————————————————"
	echo "             bash <(wget -qO- bash.spiritlhl.net/ecs-cn)"
	echo "             Repo：https://github.com/spiritLHLS/ecsspeed "
	echo "             节点更新: $csv_date  | 脚本更新: $ecsspeednetver "
	echo "——————————————————————————————————————————————————————————————————————————————"
}

selecttest() {
	echo -e "测速类型:"
	echo -e "\t${GREEN}1.${PLAIN}三网测速(就近节点)\t${GREEN}3.${PLAIN}联通\t\t${GREEN}6.${PLAIN}香港\t\t${GREEN}8.${PLAIN}退出测速"
	echo -e "\t${GREEN}2.${PLAIN}三网测速(所有节点)\t${GREEN}4.${PLAIN}电信\t\t${GREEN}7.${PLAIN}台湾"
	echo -e "\t\t\t\t${GREEN}5.${PLAIN}移动"
    echo "——————————————————————————————————————————————————————————————————————————————"
	while :; do echo
			reading "请输入数字选择测速类型: " selection
			if [[ ! $selection =~ ^[1-8]$ ]]; then
					echo -ne "  ${RED}输入错误${PLAIN}, 请输入正确的数字!"
			else
					break   
			fi
	done
}

runtest() {
    case ${selection} in
        7)
            _yellow "checking speedtest servers"
            slist=($(get_data "${SERVER_BASE_URL}/TW.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        6)
            _yellow "checking speedtest servers"
            slist=($(get_data "${SERVER_BASE_URL}/HK.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        5)
            _yellow "checking speedtest servers"
            slist=($(get_data "${SERVER_BASE_URL}/mobile.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        4)
            _yellow "checking speedtest servers"
            slist=($(get_data "${SERVER_BASE_URL}/telecom.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
        3)
            _yellow "checking speedtest servers"
            slist=($(get_data "${SERVER_BASE_URL}/unicom.csv"))
            temp_head
            test_list "${slist[@]}"
            ;;
	    2)
            _yellow "checking speedtest servers"
            CN_Unicom=($(get_data "${SERVER_BASE_URL}/unicom.csv"))
            CN_Telecom=($(get_data "${SERVER_BASE_URL}/telecom.csv"))
            CN_Mobile=($(get_data "${SERVER_BASE_URL}/mobile.csv"))
            temp_head
            test_list "${CN_Unicom[@]}"
            test_list "${CN_Telecom[@]}"
            test_list "${CN_Mobile[@]}"
            ;;
	    1)
            checkping
            _yellow "checking speedtest servers and find nearest server"
            CN_Unicom=($(get_nearest_data "${SERVER_BASE_URL}/unicom.csv"))
            CN_Telecom=($(get_nearest_data "${SERVER_BASE_URL}/telecom.csv"))
            CN_Mobile=($(get_nearest_data "${SERVER_BASE_URL}/mobile.csv"))
	        _blue "就近节点若缺少某运营商，那么该运营商连通性很差，建议使用对应运营商选项全测看看"
            temp_head
            test_list "${CN_Unicom[@]}"
            test_list "${CN_Telecom[@]}"
            test_list "${CN_Mobile[@]}"
            ;;
        *)
            echo "Exit"
	    global_exit
            exit 1
            ;;
    esac
}

checkver(){
    csv_date=$(curl -s --max-time 6 https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
    if [ $? -ne 0 ]; then
        csv_date=$(curl -s --max-time 6 ${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
    fi
    export csv_date
}

main() {
    preinfo
    selecttest
    start_time=$(date +%s)
    runtest
}

checkroot
checksystem
# checkupdate
checkcurl
checkwget
checknslookup
checktar
SystemInfo_GetOSRelease
SystemInfo_GetSystemBit
check_cdn_file
check_china
install_speedtest
checkver
main
print_end_time
global_exit