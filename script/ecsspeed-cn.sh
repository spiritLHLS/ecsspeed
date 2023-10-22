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
ecsspeednetver="2023/05/20"
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

checknslookup() {
    _yellow "checking nslookup"
    if ! command -v nslookup &>/dev/null; then
        _yellow "Installing dnsutils"
        ${PACKAGE_INSTALL[int]} dnsutils
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

statistics_of_run-times() {
    COUNT=$(
        curl -4 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FspiritLHLS%2Fecsspeed&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1 ||
            curl -6 -ksm1 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FspiritLHLS%2Fecsspeed&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=&edge_flat=true" 2>&1
    ) &&
        TODAY=$(expr "$COUNT" : '.*\s\([0-9]\{1,\}\)\s/.*') && TOTAL=$(expr "$COUNT" : '.*/\s\([0-9]\{1,\}\)\s.*')
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
            ./speedtest-cli/speedtest-go >./speedtest-cli/speedtest.log 2>&1
        else
            ./speedtest-cli/speedtest-go --custom-url=http://"$1"/upload.php >./speedtest-cli/speedtest.log 2>&1
        fi
        if [ $? -eq 0 ]; then
            local dl_speed=$(grep -oP 'Download: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            local up_speed=$(grep -oP 'Upload: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            local latency=$(grep -oP 'Latency: \K[\d\.]+' ./speedtest-cli/speedtest.log)
            if [[ -n "${latency}" && "${latency}" == *.* ]]; then
                latency=$(awk '{printf "%.2f", $1}' <<<"${latency}")
            fi
            if [[ -n "${dl_speed}" || -n "${up_speed}" || -n "${latency}" ]]; then
                if [[ $selection =~ ^[1-5]$ ]]; then
                    echo -e "${nodeName}\t ${up_speed} Mbps\t ${dl_speed} Mbps\t ${latency} ms\t"
                else
                    length=$(get_string_length "$nodeName")
                    if [ $length -ge 8 ]; then
                        echo -e "${nodeName}\t ${up_speed} Mbps\t ${dl_speed} Mbps\t ${latency} ms\t"
                    else
                        echo -e "${nodeName}\t\t ${up_speed} Mbps\t ${dl_speed} Mbps\t ${latency} ms\t"
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
        host=$(echo "${list[i]}" | cut -d',' -f1)
        name=$(echo "${list[i]}" | cut -d',' -f2)
        # echo "$host $name"
        speed_test "$host" "$name"
    done
}

temp_head() {
    echo "——————————————————————————————————————————————————————————————————————————————"
    if [[ $selection =~ ^[1-5]$ ]]; then
        echo -e "位置\t         上传速度\t 下载速度\t 延迟"
    else
        echo -e "位置\t\t 上传速度\t 下载速度\t 延迟"
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

get_ip_from_url() {
    nslookup -querytype=A $1 | awk '/^Name:/ {next;} /^Address: / { print $2 }'
}

is_ipv4() {
    local ip=$1
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ $ip =~ $regex ]]; then
        return 0 # 符合IPv4格式
    else
        return 1 # 不符合IPv4格式
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
    ip_list=()
    city_list=()
    while read line; do
        if [[ -n "$line" ]]; then
            # local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $9}')
            city=${city/市/}
            city=${city/中国/}
            local host=$(echo "$line" | awk -F ',' '{print $6}')
            local host_url=$(echo $host | sed 's/:.*//')
            if [[ "$host,$city" == "host,city" ]]; then
                continue
            fi
            if is_ipv4 "$host_url"; then
                local ip="$host_url"
            else
                local ip=$(get_ip_from_url ${host_url})
            fi
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
    ip_list=()
    city_list=()
    while read line; do
        if [[ -n "$line" ]]; then
            # local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $9}')
            city=${city/市/}
            city=${city/中国/}
            local host=$(echo "$line" | awk -F ',' '{print $6}')
            local host_url=$(echo $host | sed 's/:.*//')
            if [[ "$host,$city" == "host,city" || "$city" == *"香港"* || "$city" == *"台湾"* ]]; then
                continue
            fi
            if is_ipv4 "$host_url"; then
                local ip="$host_url"
            else
                local ip=$(get_ip_from_url ${host_url})
            fi
            if [[ $url == *"mobile"* ]]; then
                city="移动${city}"
            elif [[ $url == *"telecom"* ]]; then
                city="电信${city}"
            elif [[ $url == *"unicom"* ]]; then
                city="联通${city}"
            fi
            if [[ ! " ${ip_list[@]} " =~ " ${ip} " ]] && [[ ! " ${city_list[@]} " =~ " ${city} " ]]; then
                data+=("$host,$city,$ip")
                ip_list+=("$ip")
                city_list+=("$city")
            fi
        fi
    done <<<"$response"

    rm -f /tmp/pingtest
    for ((i = 0; i < ${#data[@]}; i++)); do
        {
            ip=$(echo "${ip_list[$i]}")
            ping_test "$ip" >>/tmp/pingtest
        } &
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
            if [[ "$(echo "$item" | cut -d ',' -f 3)" == "$result" ]]; then
                # 	      if [[ "$item" == *"$result"* ]]; then
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

checkver() {
    csv_date=$(curl -sL --max-time 6 https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
    if [ $? -ne 0 ]; then
        csv_date=$(curl -sL --max-time 6 ${cdn_success_url}https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main/README.md | grep -oP '(?<=数据更新时间: ).*')
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
check_cdn_file
check_china
install_speedtest
checkver
statistics_of_run-times
main
print_end_time
global_exit
