#!/usr/bin/env bash
# by spiritlhl
# from https://github.com/spiritLHLS/ecsspeed

utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
if [[ -z "$utf8_locale" ]]; then
    echo "No UTF-8 locale found"
else
    export LC_ALL="$utf8_locale"
    export LANG="$utf8_locale"
    export LANGUAGE="$utf8_locale"
    echo "Locale set to $utf8_locale"
fi
export DEBIAN_FRONTEND=noninteractive
ecsspeednetver="2024/05/06"
SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
Speedtest_Go_version="1.6.12"
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"
cd /root >/dev/null 2>&1
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"
_red() { echo -e "\033[31m\033[01m$@\033[0m"; }
_green() { echo -e "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }
reading() { read -rp "$(_green "$1")" "$2"; }
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
apt-get --fix-broken install -y >/dev/null 2>&1

checkroot() {
    _yellow "checking root"
    [[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 用户运行本脚本！${PLAIN}" && exit 1
}

global_exit() {
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

checkupdate() {
    _yellow "Updating package management sources"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} dmidecode >/dev/null 2>&1
    apt-key update >/dev/null 2>&1
}

checkcurl() {
    _yellow "checking curl"
    if [ ! -e '/usr/bin/curl' ]; then
        _yellow "Installing curl"
        ${PACKAGE_INSTALL[int]} curl
    fi
    if [ $? -ne 0 ]; then
        apt-get -f install >/dev/null 2>&1
        ${PACKAGE_INSTALL[int]} curl
    fi
}

checkwget() {
    _yellow "checking wget"
    if [ ! -e '/usr/bin/wget' ]; then
        _yellow "Installing wget"
        ${PACKAGE_INSTALL[int]} wget
    fi
}

checktar() {
    _yellow "checking tar"
    if [ ! -e '/usr/bin/tar' ]; then
        _yellow "Installing tar"
        ${PACKAGE_INSTALL[int]} tar
    fi
    if [ $? -ne 0 ]; then
        apt-get -f install >/dev/null 2>&1
        ${PACKAGE_INSTALL[int]} tar >/dev/null 2>&1
    fi
}

checkping() {
    _yellow "checking ping"
    if [ ! -e '/usr/bin/ping' ]; then
        _yellow "Installing ping"
        ${PACKAGE_INSTALL[int]} iputils-ping >/dev/null 2>&1
        ${PACKAGE_INSTALL[int]} ping >/dev/null 2>&1
    fi
}

check_china() {
    if [[ -z "${CN}" ]]; then
        if [[ $(curl -m 10 -sL https://ipapi.co/json | grep 'China') != "" ]]; then
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

download_speedtest_file() {
    file="/root/speedtest-cli/speedtest"
    if [[ -e "$file" ]]; then
        _green "speedtest found"
        return
    fi
    file="/root/speedtest-cli/speedtest-go"
    if [[ -e "$file" ]]; then
        _green "speedtest-go found"
        return
    fi
    local sys_bit="$1"
    if [[ -z "${CN}" || "${CN}" != true ]]; then
        if [ "$speedtest_ver" = "1.2.0" ]; then
            local url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
            local url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        else
            local url1="https://filedown.me/Linux/Tool/speedtest_cli/ookla-speedtest-1.0.0-${sys_bit}-linux.tgz"
            local url2="https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-${sys_bit}-linux.tgz"
        fi
        curl --fail -sL -m 10 -o speedtest.tgz "${url1}" || curl --fail -sL -m 10 -o speedtest.tgz "${url2}"
        if [[ $? -ne 0 ]]; then
            _red "Error: Failed to download official speedtest-cli."
            rm -rf speedtest.tgz*
            _yellow "Try using the unofficial speedtest-go"
        fi
        if [ "$sys_bit" = "aarch64" ]; then
            sys_bit="arm64"
        fi
        local url3="https://github.com/showwin/speedtest-go/releases/download/v${Speedtest_Go_version}/speedtest-go_${Speedtest_Go_version}_Linux_${sys_bit}.tar.gz"
        curl --fail -sL -m 10 -o speedtest.tar.gz "${url3}" || curl --fail -sL -m 15 -o speedtest.tar.gz "${cdn_success_url}${url3}"
    else
        if [ "$sys_bit" = "aarch64" ]; then
            sys_bit="arm64"
        fi
        local url3="https://github.com/showwin/speedtest-go/releases/download/v${Speedtest_Go_version}/speedtest-go_${Speedtest_Go_version}_Linux_${sys_bit}.tar.gz"
        curl -o speedtest.tar.gz "${cdn_success_url}${url3}"
        if [ $? -eq 0 ]; then
            _green "Used unofficial speedtest-go"
        fi
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
    "x86_64" | "x86" | "amd64" | "x64") sys_bit="x86_64" ;;
    "i386" | "i686") sys_bit="i386" ;;
    "aarch64" | "armv7l" | "armv8" | "armv8l") sys_bit="aarch64" ;;
    "s390x") sys_bit="s390x" ;;
    "riscv64") sys_bit="riscv64" ;;
    "ppc64le") sys_bit="ppc64le" ;;
    "ppc64") sys_bit="ppc64" ;;
    *) sys_bit="x86_64" ;;
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
            ./speedtest-cli/speedtest-go --ua="${BrowserUA}" >./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest-go --ua="${BrowserUA}" --server=$1 >./speedtest-cli/speedtest.log 2>&1
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
    else
        if [ -z "$1" ]; then
            ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest --progress=no --server-id=$1 --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
        fi
        if [ $? -eq 0 ]; then
            local dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
            local up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
            if [ "$speedtest_ver" = "1.2.0" ]; then
                local latency=$(grep -oP 'Idle Latency:\s+\K[\d\.]+' ./speedtest-cli/speedtest.log)
            else
                local latency=$(grep -oP 'Latency:\s+\K[\d\.]+' ./speedtest-cli/speedtest.log)
            fi
            local packet_loss=$(awk -F': +' '/Packet Loss/{if($2=="Not available."){print "NULL"}else{print $2}}' ./speedtest-cli/speedtest.log)
            if [[ -n "${dl_speed}" || -n "${up_speed}" || -n "${latency}" ]]; then
                if [[ $selection =~ ^[1-5]$ ]]; then
                    echo -e "${nodeName}\t ${up_speed}\t ${dl_speed}\t ${latency}\t  $packet_loss"
                else
                    length=$(get_string_length "$nodeName")
                    if [ $length -ge 8 ]; then
                        echo -e "${nodeName}\t ${up_speed}\t ${dl_speed}\t ${latency}\t  $packet_loss"
                    else
                        echo -e "${nodeName}\t\t ${up_speed}\t ${dl_speed}\t ${latency}\t  $packet_loss"
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
    for ((i = 0; i < ${#list[@]}; i += 1)); do
        id=$(echo "${list[i]}" | cut -d',' -f1)
        name=$(echo "${list[i]}" | cut -d',' -f2)
        # echo "$id $name"
        speed_test "$id" "$name"
    done
}

temp_head() {
    echo "——————————————————————————————————————————————————————————————————————————————"
    if [[ $selection =~ ^[1-5]$ ]]; then
        if [ -f "/root/speedtest-cli/speedtest" ]; then
            echo -e "位置\t         上传速度\t 下载速度\t 延迟\t  丢包率"
        else
            echo -e "位置\t         上传速度\t 下载速度\t 延迟"
        fi
    else
        if [ -f "/root/speedtest-cli/speedtest" ]; then
            echo -e "位置\t\t 上传速度\t 下载速度\t 延迟\t  丢包率"
        else

            echo -e "位置\t\t 上传速度\t 下载速度\t 延迟"
        fi
    fi
}

print_end_time() {
    end_time=$(date +%s)
    time=$((${end_time} - ${start_time}))
    echo "——————————————————————————————————————————————————————————————————————————————"
    if [ ${time} -lt 30 ]; then
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

cdn_urls=("https://cdn0.spiritlhl.top/" "http://cdn3.spiritlhl.net/" "http://cdn1.spiritlhl.net/" "https://ghproxy.com/" "http://cdn2.spiritlhl.net/")

check_cdn() {
    _yellow "checking CDN"
    local o_url=$1
    for cdn_url in "${cdn_urls[@]}"; do
        if curl -sL -k "$cdn_url$o_url" --max-time 6 | grep -q "success" >/dev/null 2>&1; then
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

get_data() {
    local url="$1"
    local data=()
    local response
    if [[ -z "${CN}" || "${CN}" != true ]]; then
        local retries=0
        while [[ $retries -lt 3 ]]; do
            response=$(curl -sL --max-time 3 "$url")
            if [[ $? -eq 0 ]]; then
                break
            else
                retries=$((retries + 1))
                sleep 1
            fi
        done
        if [[ $retries -eq 3 ]]; then
            url="${cdn_success_url}${url}"
            response=$(curl -sL --max-time 6 "$url")
        fi
    else
        url="${cdn_success_url}${url}"
        response=$(curl -sL --max-time 10 "$url")
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
    done <<<"$response"
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
            response=$(curl -sL --max-time 2 "$url")
            if [[ $? -eq 0 ]]; then
                break
            else
                retries=$((retries + 1))
                sleep 1
            fi
        done
        if [[ $retries -eq 2 ]]; then
            url="${cdn_success_url}${url}"
            response=$(curl -sL --max-time 6 "$url")
        fi
    else
        url="${cdn_success_url}${url}"
        response=$(curl -sL --max-time 10 "$url")
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
    done <<<"$response"

    rm -f /tmp/pingtest
    # 并行ping测试所有IP
    for ((i = 0; i < ${#data[@]}; i++)); do
        {
            ip=$(echo "${data[$i]}" | awk -F ',' '{print $3}')
            ping_test "$ip" >>/tmp/pingtest
        } &
    done
    wait

    # 取IP顺序列表results
    output=$(cat /tmp/pingtest)
    rm -f /tmp/pingtest
    IFS=$'\n' read -rd '' -a lines <<<"$output"
    results=()
    for line in "${lines[@]}"; do
        field=$(echo "$line" | cut -d',' -f1)
        results+=("$field")
    done

    # 比对data取IP对应的数组
    sorted_data=()
    for result in "${results[@]}"; do
        for item in "${data[@]}"; do
            if [[ "$item" == *"$result"* ]]; then
                id=$(echo "$item" | cut -d',' -f1)
                name=$(echo "$item" | cut -d',' -f2)
                sorted_data+=("$id,$name")
            fi
        done
    done
    sorted_data=("${sorted_data[@]:0:2}")

    # 返回结果
    echo "${sorted_data[@]}"
}

statistics_of_run-times() {
    COUNT=$(
        curl -4 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FspiritLHLS%2Fecsspeed&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1 ||
            curl -6 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FspiritLHLS%2Fecsspeed&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1
    ) &&
        TODAY=$(expr "$COUNT" : '.*\s\([0-9]\{1,\}\)\s/.*') && TOTAL=$(expr "$COUNT" : '.*/\s\([0-9]\{1,\}\)\s.*')
}

preinfo() {
    echo "——————————————————————————————— ecsspeed-net —————————————————————————————————"
    echo "             bash <(wget -qO- bash.spiritlhl.net/ecs-net)"
    echo "             Repo：https://github.com/spiritLHLS/ecsspeed "
    echo "             节点更新: $csv_date  | 脚本更新: $ecsspeednetver "
    echo "——————————————————————————————————————————————————————————————————————————————"
    _green "脚本当天运行次数:${TODAY}，累计运行次数:${TOTAL}"
}

selecttest() {
    echo -e "测速类型:"
    echo -e "\t${GREEN}1.${PLAIN}三网测速(就近节点)\t${GREEN}3.${PLAIN}联通\t\t${GREEN}6.${PLAIN}香港\t\t${GREEN}8.${PLAIN}退出测速"
    echo -e "\t${GREEN}2.${PLAIN}三网测速(所有节点)\t${GREEN}4.${PLAIN}电信\t\t${GREEN}7.${PLAIN}台湾"
    echo -e "\t\t\t\t${GREEN}5.${PLAIN}移动"
    echo "——————————————————————————————————————————————————————————————————————————————"
    while :; do
        echo
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
        _yellow "checking speedtest server ID"
        slist=($(get_data "${SERVER_BASE_URL}/TW.csv"))
        temp_head
        test_list "${slist[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    6)
        _yellow "checking speedtest server ID"
        slist=($(get_data "${SERVER_BASE_URL}/HK.csv"))
        temp_head
        test_list "${slist[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    5)
        _yellow "checking speedtest server ID"
        slist=($(get_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
        temp_head
        test_list "${slist[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    4)
        _yellow "checking speedtest server ID"
        slist=($(get_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
        temp_head
        test_list "${slist[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    3)
        _yellow "checking speedtest server ID"
        slist=($(get_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
        temp_head
        test_list "${slist[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    2)
        _yellow "checking speedtest server ID"
        CN_Unicom=($(get_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
        CN_Telecom=($(get_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
        CN_Mobile=($(get_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
        temp_head
        test_list "${CN_Unicom[@]}" | tee ./speedtest-cli/speedlog.txt
        test_list "${CN_Telecom[@]}" | tee ./speedtest-cli/speedlog.txt
        test_list "${CN_Mobile[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    1)
        checkping
        _yellow "checking speedtest server ID and find nearest server"
        CN_Unicom=($(get_nearest_data "${SERVER_BASE_URL}/CN_Unicom.csv"))
        CN_Telecom=($(get_nearest_data "${SERVER_BASE_URL}/CN_Telecom.csv"))
        CN_Mobile=($(get_nearest_data "${SERVER_BASE_URL}/CN_Mobile.csv"))
        _blue "就近节点若缺少某运营商，那么该运营商连通性很差，建议使用对应运营商选项全测看看"
        temp_head
        test_list "${CN_Unicom[@]}" | tee ./speedtest-cli/speedlog.txt
        test_list "${CN_Telecom[@]}" | tee ./speedtest-cli/speedlog.txt
        test_list "${CN_Mobile[@]}" | tee ./speedtest-cli/speedlog.txt
        ;;
    *)
        echo "Exit"
        global_exit
        exit 1
        ;;
    esac
}

checkver() {
    csv_date=$(curl -sL --max-time 6 https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
    if [ $? -ne 0 ]; then
        csv_date=$(curl -sL --max-time 6 ${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
    fi
    export csv_date
}

checkerror() {
    end_time=$(date +%s)
    time=$((${end_time} - ${start_time}))
    if ! grep -qE "(台湾|香港|联通|电信|移动|Hong|Kong|Taiwan|Taipei)" ./speedtest-cli/speedlog.txt; then
        _yellow "Unable to use the 1.2.0, back to 1.0.0"
        speedtest_ver="1.0.0"
        global_exit
        (install_speedtest >/dev/null 2>&1)
        runtest
    fi
}

main() {
    rm -rf ./speedtest-cli/speedlog.txt
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
checktar
check_cdn_file
check_china
speedtest_ver="1.2.0"
install_speedtest
checkver
statistics_of_run-times
main
checkerror
print_end_time
global_exit
