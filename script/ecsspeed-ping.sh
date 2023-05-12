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
ecsspeednetver="2023/05/12"
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

checkping() {
    _yellow "checking ping"
	if  [ ! -e '/usr/bin/ping' ]; then
            _yellow "Installing ping"
	    ${PACKAGE_INSTALL[int]} iputils-ping > /dev/null 2>&1
	    ${PACKAGE_INSTALL[int]} ping > /dev/null 2>&1
	fi
}

checknslookup() {
    _yellow "checking nslookup"
	if ! command -v nslookup &> /dev/null; then
        _yellow "Installing dnsutils"
	    ${PACKAGE_INSTALL[int]} dnsutils
	fi
}

check_china(){
    if [[ -z "${CN}" ]]; then
        if [[ $(curl -m 6 -sL https://ipapi.co/json | grep 'China') != "" ]]; then
            _yellow "根据ipapi.co提供的信息，当前IP可能在中国"
            echo "使用中国镜像"
            CN=true
        else
            if [[ $? -ne 0 ]]; then
	    	if [[ $(curl -m 6 -sL cip.cc) =~ "中国" ]]; then
		    _yellow "根据ipapi.co提供的信息，当前IP可能在中国"
            	    echo "使用中国镜像"
            	    CN=true
		fi
	    fi
	fi
    fi
}

ping_test() {
    local ip="$1"
    local result="$(ping -c1 -W3 "$ip" 2>/dev/null | awk -F '/' 'END {print $5}')"
    echo "$ip,$result"
}

get_nearest_data_net() {
    local url="$1"
    local last_part=$(echo "$url" | rev | cut -d'/' -f1 | rev)
    local pingname=$(echo "$last_part" | cut -d'.' -f1)
    rm -f "/tmp/pingtest${pingname}"
    local data=()
    local response
    if [[ -z "${CN}" || "${CN}" != true ]]; then
        local retries=0
        while [[ $retries -lt 2 ]]; do
            response=$(curl -sL --max-time 2 "$url")
            if [[ $? -eq 0 ]]; then
                break
            else
                retries=$((retries+1))
                sleep 1
            fi
        done
        if [[ $retries -eq 2 ]]; then
            local url="${cdn_success_url}${url}"
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
    done <<< "$response"
    
    # 并行ping测试所有IP
    for (( i=0; i<${#data[@]}; i++ )); do
        { local ip=$(echo "${data[$i]}" | awk -F ',' '{print $3}')
        ping_test "$ip" >> "/tmp/pingtest${pingname}"; }&
    done
    wait
    sleep 0.5
    # 取IP顺序列表results
    if [ ! -f "/tmp/pingtest${pingname}" ]; then
	echo "" > "/tmp/pinglog${pingname}"
	return
    fi
    local output=$(cat "/tmp/pingtest${pingname}")
    local lines ; local IFS ; local line ; local field ;
    IFS=$'\n' read -rd '' -a lines <<<"$output"
    local results=()
    local pings=()
    for line in "${lines[@]}"; do
        field=$(echo "$line" | cut -d',' -f1)
        if [ ! -z "$(echo "$line" | cut -d',' -f2)" ]; then
            results+=("$field")
            pings+=("$(echo "$line" | cut -d',' -f2 | cut -d'.' -f1)")
        fi
    done
    
    # 比对data取IP对应的数组
    local sorted_data=()
    local item ; local index ; local name ; local result ; local ping_ip ;
    for index in "${!results[@]}"; do
        result="${results[$index]}"
        ping_ip="${pings[$index]}"
        for item in "${data[@]}"; do
            if [[ "$item" == *"$result"* ]]; then
                name=$(echo "$item" | cut -d',' -f2)
                sorted_data+=("$name,$ping_ip,$result")
            fi
        done
    done

    echo "${sorted_data[@]}" > "/tmp/pinglog${pingname}"
}

get_ip_from_url() {
    nslookup -querytype=A $1 | awk '/^Name:/ {next;} /^Address: / { print $2 }'
}

is_ipv4() {
    local ip=$1
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ $ip =~ $regex ]]; then
        return 0  # 符合IPv4格式
    else
        return 1  # 不符合IPv4格式
    fi
}

get_nearest_data_cn() {
    local url="$1"
    local last_part=$(echo "$url" | rev | cut -d'/' -f1 | rev)
    local pingname=$(echo "$last_part" | cut -d'.' -f1)
    rm -f "/tmp/pingtest${pingname}"
    local data=()
    local response
    if [[ -z "${CN}" || "${CN}" != true ]]; then
        local retries=0
        while [[ $retries -lt 2 ]]; do
            response=$(curl -sL --max-time 2 "$url")
            if [[ $? -eq 0 ]]; then
                break
            else
                retries=$((retries+1))
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
    local ip_list=()
    local city_list=()
    while read line; do
        if [[ -n "$line" ]]; then
            # local id=$(echo "$line" | awk -F ',' '{print $1}')
            local city=$(echo "$line" | sed 's/ //g' | awk -F ',' '{print $9}')
            city=${city/市/}; city=${city/中国/}
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
    done <<< "$response"

    for (( i=0; i<${#data[@]}; i++ )); do
        { local ip=$(echo "${ip_list[$i]}")
        ping_test "$ip" >> "/tmp/pingtest${pingname}"; }&
    done
    wait
    sleep 0.5
    if [ ! -f "/tmp/pingtest${pingname}" ]; then
	echo "" > "/tmp/pinglog${pingname}"
	return
    fi
    local output=$(cat "/tmp/pingtest${pingname}")
    local lines ; local IFS ; local line ; local field ;
    IFS=$'\n' read -rd '' -a lines <<<"$output"
    local results=()
    local pings=()
    for line in "${lines[@]}"; do
        field=$(echo "$line" | cut -d',' -f1)
        if [ ! -z "$(echo "$line" | cut -d',' -f2)" ]; then
            results+=("$field")
            pings+=("$(echo "$line" | cut -d',' -f2 | cut -d'.' -f1)")
        fi
    done

    # 比对data取IP对应的数组
    local sorted_data=()
    local item ; local index ; local name ; local result ; local ping_ip ;
    for index in "${!results[@]}"; do
        result="${results[$index]}"
        ping_ip="${pings[$index]}"
        for item in "${data[@]}"; do
            if [[ "$(echo "$item" | cut -d',' -f3)" == "$result" ]]; then
                name=$(echo "$item" | cut -d',' -f2)
                sorted_data+=("$name,$ping_ip,$result")
            fi
        done
    done

    echo "${sorted_data[@]}" > "/tmp/pinglog${pingname}"
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

preinfo() {
	echo "—————————————————————————————— ecsspeed-ping —————————————————————————————————"
	echo "             bash <(wget -qO- bash.spiritlhl.net/ecs-ping)"
	echo "             Repo：https://github.com/spiritLHLS/ecsspeed "
	echo "             脚本更新: $ecsspeednetver "
	echo "——————————————————————————————————————————————————————————————————————————————"
}

print_end_time() {
    end_time=$(date +%s)
    time=$(( ${end_time} - ${start_time} ))
    echo "——————————————————————————————————————————————————————————————————————————————"
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

checkroot
# checkupdate
checkcurl
checkwget
check_cdn_file
checknslookup
checkping
check_china
PINGS_LIST=()
preinfo
start_time=$(date +%s)
# 获取数据
SERVER_BASE_URL_cn="https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main"
SERVER_BASE_URL_net="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
(get_nearest_data_cn "${SERVER_BASE_URL_cn}/unicom.csv") &
(get_nearest_data_cn "${SERVER_BASE_URL_cn}/telecom.csv") &
(get_nearest_data_cn "${SERVER_BASE_URL_cn}/mobile.csv") &
(get_nearest_data_net "${SERVER_BASE_URL_net}/CN_Unicom.csv") &
(get_nearest_data_net "${SERVER_BASE_URL_net}/CN_Telecom.csv") &
(get_nearest_data_net "${SERVER_BASE_URL_net}/CN_Mobile.csv") &
wait
declare -A fileVarMap=(
    ["pinglogunicom"]="a"
    ["pinglogtelecom"]="b"
    ["pinglogmobile"]="c"
    ["pinglogCN_Unicom"]="d"
    ["pinglogCN_Telecom"]="e"
    ["pinglogCN_Mobile"]="f"
)
for filename in "${!fileVarMap[@]}"
do
    if [[ -f "/tmp/$filename" ]]; then
        variable="${fileVarMap[$filename]}"
        declare -a "$variable=($(cat "/tmp/$filename"))"
    else
        variable="${fileVarMap[$filename]}"
        declare -a "$variable=()"
    fi
done
# 组合
array_names=("a" "d" "b" "e" "c" "f")
for i in "${array_names[@]}"; do
  array_name="${i}[@]"
  PINGS_LIST+=("${!array_name}")
done
# 去重
used_elements=()
filtered_pings=()
for ping in "${PINGS_LIST[@]}"; do
    element=$(echo "$ping" | cut -d',' -f3)
    if [[ ! " ${used_elements[@]} " =~ " ${element} " ]]; then
        filtered_pings+=("$ping")
        used_elements+=("$element")
    fi
done
PINGS_LIST=("${filtered_pings[@]}")
# 去除IP部分
processed_list=()
for item in "${PINGS_LIST[@]}"
do
    IFS=',' read -ra parts <<< "$item"
    processed_item="${parts[0]},${parts[1]}"
    processed_list+=("$processed_item")
done
PINGS_LIST=("${processed_list[@]}")
# echo "${PINGS_LIST[@]}"
# echo "${PINGS_LIST[@]}" | tr ' ' '\n' | sort -t',' -k2 -n | awk '{ORS=(NR%3==0?RS:FS)}1'
# 打印
counter=0
for ping in "${PINGS_LIST[@]}"; do
    line=$(echo "$ping" | sed 's/,/ /g')
    value=$(echo "$line" | awk '{print $2}')
    if (( value <= 50 )); then
        color='\033[0;32m'  # 中绿色
    elif (( value <= 100 )); then
        color='\033[1;32m'  # 浅绿色 
    elif (( value <= 200 )); then
        color='\033[1;34m'  # 蓝色
    elif (( value <= 300 )); then
        color='\033[1;33m'  # 黄色 
    elif (( value <= 500 )); then
        color='\033[1;31m'  # 浅红色 
    else
        color='\033[0;31m'  # 中红色
    fi
    line=$(echo "$line" | cut -d ' ' -f 1 | sed 's/5G//g')
    length1=$(get_string_length " ${line}")
    length2=${#value}
    if [ $length1 -gt 8 ]; then
        tabs="\t   "
    elif [ $length1 -gt 16 ]; then
        tabs="\t\t   "
    else
        tabs="\t\t\t   "
    fi
    if [ $length2 -eq 1 ]; then
        echo -ne " ${line}${tabs}${color}${value}   "
    elif [ $length2 -eq 2 ]; then
        echo -ne " ${line}${tabs}${color}${value}  "
    else
        echo -ne " ${line}${tabs}${color}${value} "
    fi
    color='\033[0m'  # 重置为默认颜色
    echo -ne "${color}|"
    ((counter++))
    if ((counter % 3 == 0)); then
        echo
    fi
done
if ((counter % 3 != 0)); then
    echo
fi
print_end_time
rm -rf /tmp/ping*
