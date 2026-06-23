#!/usr/bin/env sh
# Shared POSIX sh runtime for ecsspeed entrypoint scripts.

ECSSPEED_SCRIPT_VERSION="2026/06/05"
ECSSPEED_DEFAULT_SPEEDTEST_GO_VERSION="latest"
ECSSPEED_FALLBACK_SPEEDTEST_GO_VERSION="1.7.10"
ECSSPEED_BROWSER_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"

RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[36m')"
BOLD="$(printf '\033[01m')"
PLAIN="$(printf '\033[0m')"

ecsspeed_main() {
    ECSSPEED_MODE=$1
    shift
    init_defaults
    find_config_arg "$@"
    [ -n "$CONFIG_FILE" ] && load_config "$CONFIG_FILE"
    parse_args "$@"
    init_runtime
    trap 'cleanup 130' INT
    trap 'cleanup 143' TERM
    trap 'cleanup 129' HUP
    trap 'cleanup 0' EXIT

    [ "$SHOW_HELP" = "1" ] && usage && exit 0
    [ "$SHOW_VERSION" = "1" ] && printf '%s\n' "$ECSSPEED_SCRIPT_VERSION" && exit 0

    set_utf8_locale
    ensure_downloader || die "curl or wget is required and could not be installed"
    [ "$ECSSPEED_MODE" = "ping" ] || ensure_command tar "tar"
    ensure_command awk "awk"
    ensure_command sed "sed"
    ensure_command sort "sort"
    ensure_command grep "grep"
    if [ "$PRECHECK_NODES" = "1" ]; then
        ensure_command ping "iputils-ping ping" || PRECHECK_NODES=0
    fi
    case "$ECSSPEED_MODE" in
        cn|ping) ensure_resolver ;;
    esac

    check_cdn_file
    check_china_auto

    case "$ECSSPEED_MODE" in
        net|cn)
            check_csv_version
            statistics_of_run_times
            run_speed_mode
            ;;
        ping)
            run_ping_mode
            ;;
        *)
            die "unknown ecsspeed mode: $ECSSPEED_MODE"
            ;;
    esac

    if [ "$JSON_MODE" = "1" ]; then
        print_json_results
    fi
    return 0
}

init_defaults() {
    export DEBIAN_FRONTEND=noninteractive
    SHOW_HELP=0
    SHOW_VERSION=0
    JSON_MODE=0
    JSON_FILE=
    LOG_ENABLED=0
    LOG_FILE=
    CLI_SELECTION=
    CONFIG_FILE=${ECSSPEED_CONFIG:-}
    CN=${CN:-}
    NO_INSTALL=${ECSSPEED_NO_INSTALL:-0}
    USE_CDN=${ECSSPEED_USE_CDN:-1}
    PRECHECK_NODES=${ECSSPEED_PRECHECK_NODES:-1}
    INCLUDE_IPV6=${ECSSPEED_INCLUDE_IPV6:-1}
    SPEEDTEST_GO_VERSION=${ECSSPEED_SPEEDTEST_GO_VERSION:-$ECSSPEED_DEFAULT_SPEEDTEST_GO_VERSION}
    SPEEDTEST_GO_AUTO_UPDATE=${ECSSPEED_SPEEDTEST_GO_AUTO_UPDATE:-1}
    RETRIES=${ECSSPEED_RETRIES:-3}
    TIMEOUT_SHORT=${ECSSPEED_TIMEOUT_SHORT:-3}
    TIMEOUT_NORMAL=${ECSSPEED_TIMEOUT:-8}
    TIMEOUT_LONG=${ECSSPEED_TIMEOUT_LONG:-30}
    PING_TIMEOUT=${ECSSPEED_PING_TIMEOUT:-3}
    PING_CONCURRENCY=${ECSSPEED_PING_CONCURRENCY:-16}
    CDN_URLS=${ECSSPEED_CDN_URLS:-"https://cdn0.spiritlhl.top/ https://cdn1.spiritlhl.net/ https://cdn2.spiritlhl.net/ https://cdn3.spiritlhl.net/ https://cdn4.spiritlhl.net/"}
    APT_UPDATED=0
    SERVER_BASE_URL_OVERRIDE=
    TODAY=0
    TOTAL=0
    CSV_DATE="unknown"
    SPEEDTEST_BIN=
    SPEEDTEST_VERSION_FILE=
    ECSSPEED_TEMP_DIR=
    RESULTS_FILE=
    START_TIME=

    case "$ECSSPEED_MODE" in
        net)
            MODE_TITLE="ecsspeed-net"
            SCRIPT_SHORTCUT="ecs-net"
            SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
            VERSION_README_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main/README.md"
            ;;
        cn)
            MODE_TITLE="ecsspeed-cn"
            SCRIPT_SHORTCUT="ecs-cn"
            SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main"
            VERSION_README_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main/README.md"
            ;;
        ping)
            MODE_TITLE="ecsspeed-ping"
            SCRIPT_SHORTCUT="ecs-ping"
            SERVER_BASE_URL_CN="https://raw.githubusercontent.com/spiritLHLS/speedtest.cn-CN-ID/main"
            SERVER_BASE_URL_NET="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
            ;;
    esac
}

find_config_arg() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--config)
                shift
                CONFIG_FILE=$1
                ;;
            --config=*)
                CONFIG_FILE=${1#*=}
                ;;
        esac
        shift || break
    done
    if [ -z "$CONFIG_FILE" ] && [ -n "$HOME" ] && [ -f "$HOME/.ecsspeed.conf" ]; then
        CONFIG_FILE="$HOME/.ecsspeed.conf"
    fi
}

load_config() {
    cfg=$1
    [ -f "$cfg" ] || return 0
    while IFS= read -r cfg_line || [ -n "$cfg_line" ]; do
        cfg_line=$(printf '%s\n' "$cfg_line" | sed 's/[[:space:]]*$//')
        case "$cfg_line" in
            ''|\#*) continue ;;
        esac
        cfg_key=${cfg_line%%=*}
        cfg_val=${cfg_line#*=}
        cfg_key=$(printf '%s' "$cfg_key" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_')
        cfg_val=$(printf '%s' "$cfg_val" | sed 's/^["'\'']//;s/["'\'']$//')
        case "$cfg_key" in
            TIMEOUT|ECSSPEED_TIMEOUT) TIMEOUT_NORMAL=$cfg_val ;;
            TIMEOUT_SHORT|ECSSPEED_TIMEOUT_SHORT) TIMEOUT_SHORT=$cfg_val ;;
            TIMEOUT_LONG|ECSSPEED_TIMEOUT_LONG) TIMEOUT_LONG=$cfg_val ;;
            PING_TIMEOUT|ECSSPEED_PING_TIMEOUT) PING_TIMEOUT=$cfg_val ;;
            RETRIES|ECSSPEED_RETRIES) RETRIES=$cfg_val ;;
            PING_CONCURRENCY|ECSSPEED_PING_CONCURRENCY) PING_CONCURRENCY=$cfg_val ;;
            CDN_URLS|ECSSPEED_CDN_URLS) CDN_URLS=$(printf '%s' "$cfg_val" | tr ',' ' ') ;;
            SPEEDTEST_GO_VERSION|ECSSPEED_SPEEDTEST_GO_VERSION) SPEEDTEST_GO_VERSION=$cfg_val ;;
            SPEEDTEST_GO_AUTO_UPDATE|ECSSPEED_SPEEDTEST_GO_AUTO_UPDATE) SPEEDTEST_GO_AUTO_UPDATE=$cfg_val ;;
            WORK_DIR|ECSSPEED_WORK_DIR) ECSSPEED_WORK_DIR=$cfg_val ;;
            LOG_FILE|ECSSPEED_LOG_FILE) LOG_FILE=$cfg_val; LOG_ENABLED=1 ;;
            JSON_FILE|ECSSPEED_JSON_FILE) JSON_FILE=$cfg_val; JSON_MODE=1 ;;
            TEST_TYPE|SELECTION|ECSSPEED_TEST_TYPE) CLI_SELECTION=$cfg_val ;;
            CN|ECSSPEED_CN) CN=$cfg_val ;;
            USE_CDN|ECSSPEED_USE_CDN) USE_CDN=$cfg_val ;;
            PRECHECK_NODES|ECSSPEED_PRECHECK_NODES) PRECHECK_NODES=$cfg_val ;;
            INCLUDE_IPV6|ECSSPEED_INCLUDE_IPV6) INCLUDE_IPV6=$cfg_val ;;
            SERVER_BASE_URL|ECSSPEED_SERVER_BASE_URL) SERVER_BASE_URL_OVERRIDE=$cfg_val ;;
        esac
    done < "$cfg"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) SHOW_HELP=1 ;;
            -v|--version) SHOW_VERSION=1 ;;
            -json|--json) JSON_MODE=1 ;;
            --json-file|--json-output)
                JSON_MODE=1
                shift
                JSON_FILE=$1
                ;;
            --json-file=*|--json-output=*)
                JSON_MODE=1
                JSON_FILE=${1#*=}
                ;;
            -log|--log)
                LOG_ENABLED=1
                case "${2:-}" in
                    ''|-*) ;;
                    *) shift; LOG_FILE=$1 ;;
                esac
                ;;
            --log=*)
                LOG_ENABLED=1
                LOG_FILE=${1#*=}
                ;;
            -c|--config)
                shift
                CONFIG_FILE=$1
                ;;
            --config=*) CONFIG_FILE=${1#*=} ;;
            -t|--type|--selection)
                shift
                CLI_SELECTION=$1
                ;;
            --type=*|--selection=*) CLI_SELECTION=${1#*=} ;;
            --china|--cn) CN=true ;;
            --no-china) CN=false ;;
            --no-cdn) USE_CDN=0 ;;
            --no-install) NO_INSTALL=1 ;;
            --no-precheck) PRECHECK_NODES=0 ;;
            --precheck) PRECHECK_NODES=1 ;;
            --ipv6) INCLUDE_IPV6=1 ;;
            --no-ipv6) INCLUDE_IPV6=0 ;;
            --work-dir)
                shift
                ECSSPEED_WORK_DIR=$1
                ;;
            --work-dir=*) ECSSPEED_WORK_DIR=${1#*=} ;;
            --speedtest-go-version)
                shift
                SPEEDTEST_GO_VERSION=$1
                ;;
            --speedtest-go-version=*) SPEEDTEST_GO_VERSION=${1#*=} ;;
            --update-speedtest-go) SPEEDTEST_GO_AUTO_UPDATE=1 ;;
            --no-update-speedtest-go) SPEEDTEST_GO_AUTO_UPDATE=0 ;;
            --max-ping-concurrency|--ping-concurrency)
                shift
                PING_CONCURRENCY=$1
                ;;
            --max-ping-concurrency=*|--ping-concurrency=*) PING_CONCURRENCY=${1#*=} ;;
            --timeout)
                shift
                TIMEOUT_NORMAL=$1
                ;;
            --timeout=*) TIMEOUT_NORMAL=${1#*=} ;;
            --retries)
                shift
                RETRIES=$1
                ;;
            --retries=*) RETRIES=${1#*=} ;;
            *)
                if [ -z "$CLI_SELECTION" ] && [ "$ECSSPEED_MODE" != "ping" ]; then
                    CLI_SELECTION=$1
                else
                    warn "ignored unknown argument: $1"
                fi
                ;;
        esac
        shift || break
    done
    [ -n "$SERVER_BASE_URL_OVERRIDE" ] && SERVER_BASE_URL=$SERVER_BASE_URL_OVERRIDE
}

init_runtime() {
    case "$PING_CONCURRENCY" in
        ''|*[!0-9]*) PING_CONCURRENCY=16 ;;
    esac
    [ "$PING_CONCURRENCY" -lt 1 ] && PING_CONCURRENCY=1
    case "$RETRIES" in
        ''|*[!0-9]*) RETRIES=3 ;;
    esac
    [ "$RETRIES" -lt 1 ] && RETRIES=1

    if [ -n "$ECSSPEED_WORK_DIR" ]; then
        WORK_DIR=$ECSSPEED_WORK_DIR
    elif [ "$(id -u 2>/dev/null || printf 1)" = "0" ] && [ -d /root ] && [ -w /root ]; then
        WORK_DIR=/root
    elif [ -n "$HOME" ] && [ -d "$HOME" ] && [ -w "$HOME" ]; then
        WORK_DIR="$HOME/.ecsspeed"
    else
        WORK_DIR="${TMPDIR:-/tmp}/ecsspeed"
    fi
    mkdir -p "$WORK_DIR" || die "cannot create work directory: $WORK_DIR"

    SPEEDTEST_DIR="$WORK_DIR/speedtest-cli"
    mkdir -p "$SPEEDTEST_DIR" || die "cannot create speedtest directory: $SPEEDTEST_DIR"
    SPEEDTEST_BIN="$SPEEDTEST_DIR/speedtest-go"
    SPEEDTEST_VERSION_FILE="$SPEEDTEST_DIR/.speedtest-go.version"

    ECSSPEED_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ecsspeed.XXXXXX" 2>/dev/null)
    if [ -z "$ECSSPEED_TEMP_DIR" ]; then
        ECSSPEED_TEMP_DIR="${TMPDIR:-/tmp}/ecsspeed.$$"
        mkdir -p "$ECSSPEED_TEMP_DIR" || die "cannot create temp directory"
    fi
    RESULTS_FILE="$ECSSPEED_TEMP_DIR/results.tsv"
    : > "$RESULTS_FILE"

    if [ "$LOG_ENABLED" = "1" ]; then
        if [ -z "$LOG_FILE" ]; then
            LOG_FILE="$WORK_DIR/${MODE_TITLE}-$(date +%Y%m%d-%H%M%S).log"
        fi
        : > "$LOG_FILE" || die "cannot write log file: $LOG_FILE"
        info "log file: $LOG_FILE"
    fi
}

cleanup() {
    code=$1
    [ -n "$ECSSPEED_TEMP_DIR" ] && rm -rf "$ECSSPEED_TEMP_DIR"
    trap - EXIT INT TERM HUP
    [ "$code" = "0" ] || exit "$code"
}

usage() {
    cat <<EOF
$MODE_TITLE $ECSSPEED_SCRIPT_VERSION

Usage:
  sh script/$MODE_TITLE.sh [options]

Options:
  -t, --type N                 Test type for net/cn mode: 1 nearest, 2 all, 3 unicom, 4 telecom, 5 mobile, 6 HK, 7 TW, 8 JP, 9 SG, 10 exit
  -json, --json                Print final result as JSON
      --json-file FILE         Also write JSON to FILE
  -log, --log [FILE]           Enable logging; default file is under the work directory
  -c, --config FILE            Load KEY=VALUE config file
      --work-dir DIR           Store downloaded tools and logs in DIR
      --timeout SECONDS        HTTP timeout, default $TIMEOUT_NORMAL
      --retries N              Retry count, default $RETRIES
      --ping-concurrency N     Ping worker limit, default $PING_CONCURRENCY
      --speedtest-go-version V Use V or "latest" for net mode; default $SPEEDTEST_GO_VERSION
      --no-update-speedtest-go Reuse cached speedtest-go when available in net mode
      --no-precheck            Skip ping reachability precheck before speed tests
      --no-cdn                 Do not use CDN fallback
      --no-install             Do not try package-manager installs
      --china, --no-china      Force or disable China mirror behavior
      --ipv6, --no-ipv6        Enable or disable IPv6 endpoint checks
  -h, --help                   Show help
  -v, --version                Show script version

Config keys mirror option names, for example:
  TIMEOUT=8
  RETRIES=3
  PING_CONCURRENCY=16
  CDN_URLS=https://cdn0.spiritlhl.top/,https://cdn1.spiritlhl.net/
EOF
}

set_utf8_locale() {
    utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E 'UTF-8|utf8')
    if [ -n "$utf8_locale" ]; then
        export LC_ALL="$utf8_locale"
        export LANG="$utf8_locale"
        export LANGUAGE="$utf8_locale"
    fi
}

log_plain() {
    if [ "$LOG_ENABLED" = "1" ]; then
        printf '%s\n' "$*" >> "$LOG_FILE"
    fi
    return 0
}

print_line() {
    msg=$1
    if [ "$JSON_MODE" = "1" ]; then
        printf '%s\n' "$msg" >&2
    else
        printf '%s\n' "$msg"
    fi
    log_plain "$msg"
    return 0
}

print_color() {
    color=$1
    shift
    msg=$*
    if [ -n "$NO_COLOR" ]; then
        print_line "$msg"
        return
    fi
    colored="${color}${BOLD}${msg}${PLAIN}"
    if [ "$JSON_MODE" = "1" ]; then
        printf '%b\n' "$colored" >&2
    else
        printf '%b\n' "$colored"
    fi
    log_plain "$msg"
    return 0
}

info() { print_color "$GREEN" "$*"; }
warn() { print_color "$YELLOW" "$*"; }
err() { print_color "$RED" "$*"; }
blue() { print_color "$BLUE" "$*"; }
die() { err "Error: $*"; exit 1; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_root() {
    [ "$(id -u 2>/dev/null || printf 1)" = "0" ]
}

install_packages() {
    pkgs=$1
    [ "$NO_INSTALL" = "1" ] && return 1
    is_root || return 1
    install_ok=1
    # Package candidates intentionally split into separate install attempts.
    # shellcheck disable=SC2086
    set -- $pkgs
    for pkg_name do
        install_one_package "$pkg_name" && install_ok=0
    done
    return "$install_ok"
}

install_one_package() {
    pkg_name=$1
    if command_exists apt-get; then
        [ "$APT_UPDATED" = "1" ] || { apt-get update >/dev/null 2>&1 && APT_UPDATED=1; }
        apt-get install -y "$pkg_name" >/dev/null 2>&1
    elif command_exists apk; then
        apk add --no-cache "$pkg_name" >/dev/null 2>&1
    elif command_exists dnf; then
        dnf install -y "$pkg_name" >/dev/null 2>&1
    elif command_exists yum; then
        yum install -y "$pkg_name" >/dev/null 2>&1
    elif command_exists pacman; then
        pacman -Sy --noconfirm --needed "$pkg_name" >/dev/null 2>&1
    elif command_exists zypper; then
        zypper --non-interactive install "$pkg_name" >/dev/null 2>&1
    elif command_exists pkg; then
        pkg install -y "$pkg_name" >/dev/null 2>&1
    else
        return 1
    fi
}

ensure_command() {
    cmd=$1
    pkgs=$2
    command_exists "$cmd" && return 0
    warn "checking $cmd: not found, trying package manager"
    install_packages "$pkgs" || true
    command_exists "$cmd" && return 0
    warn "$cmd is unavailable; continuing with degraded behavior when possible"
    return 1
}

ensure_resolver() {
    command_exists getent && return 0
    command_exists host && return 0
    command_exists dig && return 0
    command_exists drill && return 0
    command_exists nslookup && return 0
    ensure_command nslookup "dnsutils bind-tools bind-tools-extra bind9-host"
}

ensure_downloader() {
    command_exists curl && return 0
    command_exists wget && return 0
    warn "checking downloader: curl/wget not found, trying package manager"
    install_packages "curl wget ca-certificates" || true
    command_exists curl || command_exists wget
}

http_get() {
    url=$1
    timeout=${2:-$TIMEOUT_NORMAL}
    if command_exists curl; then
        curl -fsSL --connect-timeout "$timeout" --max-time "$timeout" "$url"
    elif command_exists wget; then
        wget -q -T "$timeout" -O - "$url"
    else
        return 127
    fi
}

http_get_retry() {
    url=$1
    timeout=${2:-$TIMEOUT_NORMAL}
    tries=1
    delay=1
    while [ "$tries" -le "$RETRIES" ]; do
        if http_get "$url" "$timeout"; then
            return 0
        fi
        tries=$((tries + 1))
        [ "$tries" -le "$RETRIES" ] && sleep "$delay"
        delay=$((delay * 2))
    done
    return 1
}

download_file_once() {
    url=$1
    dest=$2
    timeout=${3:-$TIMEOUT_LONG}
    if command_exists curl; then
        curl -fL --connect-timeout "$TIMEOUT_NORMAL" --max-time "$timeout" --progress-bar -o "$dest" "$url"
    elif command_exists wget; then
        wget -T "$timeout" -t 1 --progress=bar:force -O "$dest" "$url"
    else
        return 127
    fi
}

download_file_retry() {
    url=$1
    dest=$2
    timeout=${3:-$TIMEOUT_LONG}
    tries=1
    delay=1
    while [ "$tries" -le "$RETRIES" ]; do
        rm -f "$dest"
        if download_file_once "$url" "$dest" "$timeout"; then
            [ -s "$dest" ] && return 0
        fi
        tries=$((tries + 1))
        [ "$tries" -le "$RETRIES" ] && sleep "$delay"
        delay=$((delay * 2))
    done
    return 1
}

cdn_wrap_url() {
    raw_url=$1
    [ "$USE_CDN" = "1" ] || return 1
    [ -n "$cdn_success_url" ] || return 1
    case "$raw_url" in
        https://*) printf '%s%s\n' "$cdn_success_url" "$raw_url" ;;
        *) return 1 ;;
    esac
}

fetch_text() {
    url=$1
    timeout=${2:-$TIMEOUT_NORMAL}
    if http_get_retry "$url" "$timeout"; then
        return 0
    fi
    cdn_url=$(cdn_wrap_url "$url" 2>/dev/null) || return 1
    http_get_retry "$cdn_url" "$TIMEOUT_LONG"
}

download_with_fallback() {
    url=$1
    dest=$2
    timeout=${3:-$TIMEOUT_LONG}
    info "downloading $(basename "$dest")"
    if download_file_retry "$url" "$dest" "$timeout"; then
        return 0
    fi
    cdn_url=$(cdn_wrap_url "$url" 2>/dev/null) || return 1
    warn "direct download failed, trying CDN"
    download_file_retry "$cdn_url" "$dest" "$timeout"
}

check_cdn_file() {
    [ "$USE_CDN" = "1" ] || { cdn_success_url=; return 0; }
    test_url="https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
    for cdn in $CDN_URLS; do
        case "$cdn" in
            https://*) ;;
            *) warn "skip insecure CDN URL: $cdn"; continue ;;
        esac
        case "$cdn" in */) ;; *) cdn="$cdn/" ;; esac
        if http_get "$cdn$test_url" "$TIMEOUT_SHORT" 2>/dev/null | grep -q "success"; then
            cdn_success_url=$cdn
            warn "CDN available, using $cdn_success_url"
            return 0
        fi
    done
    cdn_success_url=
    warn "No CDN available, no use CDN"
}

check_china_auto() {
    case "$CN" in
        true|false) return 0 ;;
    esac
    ipapi_result=$(http_get "https://ipapi.co/json" 6 2>/dev/null || true)
    if printf '%s\n' "$ipapi_result" | grep -q "China"; then
        warn "根据ipapi.co提供的信息，当前IP可能在中国，自动启用中国镜像"
        CN=true
        return 0
    fi
    cip_result=$(http_get "https://cip.cc" 6 2>/dev/null || true)
    if printf '%s\n' "$cip_result" | grep -q "中国"; then
        warn "根据cip.cc提供的信息，当前IP可能在中国，自动启用中国镜像"
        CN=true
        return 0
    fi
    CN=false
}

detect_asset_os() {
    os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$os" in
        linux) printf 'Linux\n' ;;
        darwin) printf 'Darwin\n' ;;
        freebsd) printf 'Freebsd\n' ;;
        openbsd) printf 'OpenBSD\n' ;;
        *) return 1 ;;
    esac
}

detect_asset_arch() {
    arch=$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$arch" in
        x86_64|amd64|x64) printf 'x86_64\n' ;;
        i386|i486|i586|i686|x86) printf 'i386\n' ;;
        aarch64|arm64|armv8*) printf 'arm64\n' ;;
        armv7*|armhf) printf 'armv7\n' ;;
        armv6*) printf 'armv6\n' ;;
        armv5*) printf 'armv5\n' ;;
        s390x) printf 's390x\n' ;;
        riscv64) printf 'riscv64\n' ;;
        ppc64le) printf 'ppc64le\n' ;;
        ppc64) printf 'ppc64\n' ;;
        loongarch64|loong64) printf 'loong64\n' ;;
        mips64le) printf 'mips64le_softfloat\n' ;;
        mips64) printf 'mips64_softfloat\n' ;;
        mipsle) printf 'mipsle_softfloat\n' ;;
        mips) printf 'mips_softfloat\n' ;;
        *) return 1 ;;
    esac
}

resolve_speedtest_go_version() {
    case "$SPEEDTEST_GO_VERSION" in
        latest|auto|'')
            latest_json=$(http_get "https://api.github.com/repos/showwin/speedtest-go/releases/latest" "$TIMEOUT_NORMAL" 2>/dev/null || true)
            latest_tag=$(printf '%s\n' "$latest_json" | awk -F'"' '/"tag_name"[[:space:]]*:/ {print $4; exit}' | sed 's/^v//')
            if [ -n "$latest_tag" ]; then
                printf '%s\n' "$latest_tag"
            else
                printf '%s\n' "$ECSSPEED_FALLBACK_SPEEDTEST_GO_VERSION"
            fi
            ;;
        v*) printf '%s\n' "${SPEEDTEST_GO_VERSION#v}" ;;
        *) printf '%s\n' "$SPEEDTEST_GO_VERSION" ;;
    esac
}

sha256_file() {
    file=$1
    if command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command_exists sha256; then
        sha256 -q "$file"
    elif command_exists openssl; then
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    else
        return 1
    fi
}

verify_checksum() {
    archive=$1
    checksums=$2
    asset=$3
    expected=$(awk -v asset="$asset" '$2 == asset {print $1; exit}' "$checksums")
    [ -n "$expected" ] || return 1
    actual=$(sha256_file "$archive" 2>/dev/null || true)
    [ -n "$actual" ] || return 1
    [ "$actual" = "$expected" ]
}

ensure_speedtest_go() {
    version=$(resolve_speedtest_go_version)
    asset_os=$(detect_asset_os) || { warn "unsupported OS for speedtest-go: $(uname -s 2>/dev/null)"; return 1; }
    asset_arch=$(detect_asset_arch) || { warn "unsupported architecture for speedtest-go: $(uname -m 2>/dev/null)"; return 1; }
    asset="speedtest-go_${version}_${asset_os}_${asset_arch}.tar.gz"
    release_base="https://github.com/showwin/speedtest-go/releases/download/v${version}"

    if [ -x "$SPEEDTEST_BIN" ] && [ "$SPEEDTEST_GO_AUTO_UPDATE" != "1" ]; then
        info "speedtest-go found"
        return 0
    fi
    if [ -x "$SPEEDTEST_BIN" ] && [ -f "$SPEEDTEST_VERSION_FILE" ] && [ "$(cat "$SPEEDTEST_VERSION_FILE" 2>/dev/null)" = "$version" ]; then
        info "speedtest-go $version found"
        return 0
    fi

    archive="$ECSSPEED_TEMP_DIR/$asset"
    checksums="$ECSSPEED_TEMP_DIR/checksums.txt"
    download_with_fallback "$release_base/$asset" "$archive" "$TIMEOUT_LONG" || {
        warn "failed to download $asset"
        return 1
    }
    download_with_fallback "$release_base/checksums.txt" "$checksums" "$TIMEOUT_LONG" || {
        warn "failed to download checksum file"
        return 1
    }
    if ! verify_checksum "$archive" "$checksums" "$asset"; then
        err "checksum verification failed for $asset"
        rm -f "$archive"
        return 1
    fi
    info "checksum verified for $asset"

    extract_dir="$ECSSPEED_TEMP_DIR/speedtest-go-extract"
    mkdir -p "$extract_dir" || return 1
    tar -zxf "$archive" -C "$extract_dir" || return 1
    found_bin=$(find "$extract_dir" -type f \( -name speedtest-go -o -name speedtest-go.exe \) | head -1)
    [ -n "$found_bin" ] || return 1
    cp "$found_bin" "$SPEEDTEST_BIN" || return 1
    chmod 755 "$SPEEDTEST_BIN" || return 1
    printf '%s\n' "$version" > "$SPEEDTEST_VERSION_FILE"
    info "Installed speedtest-go $version"
}

display_width() {
    text=$1
    bytes=$(printf '%s' "$text" | wc -c | awk '{print $1}')
    chars=$(printf '%s' "$text" | wc -m | awk '{print $1}')
    case "$bytes$chars" in
        *[!0-9]*) printf '%s\n' "$bytes"; return ;;
    esac
    if [ "$bytes" -le "$chars" ]; then
        printf '%s\n' "$chars"
    else
        printf '%s\n' $((chars + (bytes - chars) / 2))
    fi
}

pad_str() {
    str=$1
    width=$2
    len=$(display_width "$str")
    pad=$((width - len))
    [ "$pad" -lt 1 ] && pad=1
    printf '%s%*s' "$str" "$pad" ''
}

table_rule() {
    print_line "——————————————————————————————————————————————————————————————————————————————"
}

temp_head() {
    table_rule
    print_line "$(pad_str "ID 位置" 24)$(pad_str "上传速度" 16)$(pad_str "下载速度" 16)延迟"
}

print_menu_line() {
    plain=$1
    colored=$2
    if [ -n "$NO_COLOR" ]; then
        print_line "$plain"
        return
    fi
    if [ "$JSON_MODE" = "1" ]; then
        printf '%b\n' "$colored" >&2
    else
        printf '%b\n' "$colored"
    fi
    log_plain "$plain"
}

preinfo() {
    table_rule
    print_line "             $MODE_TITLE"
    print_line "             wget -qO- https://bash.spiritlhl.net/$SCRIPT_SHORTCUT | sh"
    print_line "             Repo：https://github.com/spiritLHLS/ecsspeed "
    if [ "$ECSSPEED_MODE" = "ping" ]; then
        print_line "             脚本更新: $ECSSPEED_SCRIPT_VERSION "
    else
        print_line "             节点更新: $CSV_DATE  | 脚本更新: $ECSSPEED_SCRIPT_VERSION "
        if [ -f "$SPEEDTEST_VERSION_FILE" ]; then
            print_line "             speedtest-go: $(cat "$SPEEDTEST_VERSION_FILE" 2>/dev/null)"
        fi
    fi
    table_rule
    if [ "$ECSSPEED_MODE" != "ping" ]; then
        info "脚本当天运行次数:${TODAY}，累计运行次数:${TOTAL}"
    fi
}

selecttest() {
    if [ -n "$CLI_SELECTION" ]; then
        selection=$CLI_SELECTION
        return 0
    fi
    print_line "测速类型:"
    print_menu_line "	1.三网测速(就近节点)	3.联通		6.香港		10.退出测速" "	${GREEN}1.${PLAIN}三网测速(就近节点)	${GREEN}3.${PLAIN}联通		${GREEN}6.${PLAIN}香港		${GREEN}10.${PLAIN}退出测速"
    print_menu_line "	2.三网测速(所有节点)	4.电信		7.台湾" "	${GREEN}2.${PLAIN}三网测速(所有节点)	${GREEN}4.${PLAIN}电信		${GREEN}7.${PLAIN}台湾"
    print_menu_line "				5.移动		8.日本" "				${GREEN}5.${PLAIN}移动		${GREEN}8.${PLAIN}日本"
    print_menu_line "						9.新加坡" "						${GREEN}9.${PLAIN}新加坡"
    table_rule
    while :; do
        if [ -r /dev/tty ]; then
            printf '\n%s' "请输入数字选择测速类型: " > /dev/tty
            IFS= read -r selection < /dev/tty || selection=
        elif [ -t 0 ]; then
            printf '\n%s' "请输入数字选择测速类型: "
            IFS= read -r selection || selection=
        else
            selection=1
            warn "non-interactive input detected; default to test type 1"
            return 0
        fi
        case "$selection" in
            10|[1-9]) break ;;
            *) err "输入错误, 请输入正确的数字!" ;;
        esac
    done
}

check_csv_version() {
    readme=$(fetch_text "$VERSION_README_URL" "$TIMEOUT_NORMAL" 2>/dev/null || true)
    CSV_DATE=$(printf '%s\n' "$readme" | sed -n 's/.*数据更新时间: //p' | head -1)
    [ -n "$CSV_DATE" ] || CSV_DATE="unknown"
}

statistics_of_run_times() {
    count=$(http_get "https://hits.spiritlhl.net/ecsspeed?action=hit&title=Hits&title_bg=%23555555&count_bg=%2324dde1&edge_flat=false" 2 2>/dev/null || true)
    TODAY=$(printf '%s\n' "$count" | sed -n 's/.*"daily":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
    TOTAL=$(printf '%s\n' "$count" | sed -n 's/.*"total":[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
    [ -n "$TODAY" ] || TODAY=0
    [ -n "$TOTAL" ] || TOTAL=0
}

trim_field() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\r$//'
}

strip_host_port() {
    hp=$1
    case "$hp" in
        \[*\]*) printf '%s\n' "$hp" | sed 's/^\[\([^]]*\)\].*/\1/' ;;
        *:*:*) printf '%s\n' "$hp" ;;
        *:*) printf '%s\n' "$hp" | sed 's/:.*//' ;;
        *) printf '%s\n' "$hp" ;;
    esac
}

is_ipv4() {
    ip=$1
    printf '%s\n' "$ip" | awk -F. 'NF==4 {for(i=1;i<=4;i++){if($i !~ /^[0-9]+$/ || $i<0 || $i>255) exit 1} exit 0} {exit 1}'
}

is_ipv6() {
    case "$1" in
        *:*) return 0 ;;
        *) return 1 ;;
    esac
}

is_private_ipv4() {
    address=$1
    case "$address" in
        10.*|127.*|169.254.*|192.168.*) return 0 ;;
        172.*)
            second=$(printf '%s\n' "$address" | cut -d. -f2)
            [ "$second" -ge 16 ] 2>/dev/null && [ "$second" -le 31 ] 2>/dev/null && return 0
            ;;
    esac
    return 1
}

is_private_ipv6() {
    address=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$address" in
        ::ffff:*)
            mapped_v4=${address##*::ffff:}
            is_private_ipv4 "$mapped_v4" && return 0
            ;;
    esac
    case "$address" in
        ::|::1|fc*|fd*|fe80:*|fec0:*) return 0 ;;
    esac
    return 1
}

resolve_host() {
    host=$1
    [ -z "$host" ] && return 1
    if is_ipv4 "$host" || is_ipv6 "$host"; then
        printf '%s\n' "$host"
        return 0
    fi
    if command_exists getent; then
        getent ahosts "$host" 2>/dev/null | awk '{print $1}' | while IFS= read -r ip; do
            [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && continue
            printf '%s\n' "$ip"
            break
        done
        return 0
    fi
    if command_exists host; then
        host "$host" 2>/dev/null | awk '/has address|has IPv6 address/ {print $NF}' | while IFS= read -r ip; do
            [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && continue
            printf '%s\n' "$ip"
            break
        done
        return 0
    fi
    if command_exists dig; then
        { dig +short A "$host" 2>/dev/null; dig +short AAAA "$host" 2>/dev/null; } | awk '/^[0-9A-Fa-f:.]+$/ {print}' | while IFS= read -r ip; do
            [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && continue
            printf '%s\n' "$ip"
            break
        done
        return 0
    fi
    if command_exists drill; then
        drill "$host" 2>/dev/null | awk '/^[^;].*[[:space:]]IN[[:space:]]+(A|AAAA)[[:space:]]/ {print $NF}' | while IFS= read -r ip; do
            [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && continue
            printf '%s\n' "$ip"
            break
        done
        return 0
    fi
    if command_exists nslookup; then
        nslookup "$host" 2>/dev/null | awk '
            /^Name:/ {answer=1; next}
            answer && /^Address: / {print $2; exit}
            answer && /^Addresses: / {
                for (i=2; i<=NF; i++) {
                    print $i
                    exit
                }
            }
        ' | while IFS= read -r ip; do
            [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && continue
            printf '%s\n' "$ip"
            break
        done
        return 0
    fi
    return 1
}

clean_endpoint_ip() {
    endpoint=$1
    host=$(strip_host_port "$endpoint")
    ip=$(resolve_host "$host" | head -1)
    [ -n "$ip" ] || return 1
    if is_ipv4 "$ip" && is_private_ipv4 "$ip"; then
        return 1
    fi
    if is_ipv6 "$ip" && is_private_ipv6 "$ip"; then
        return 1
    fi
    [ "$INCLUDE_IPV6" = "0" ] && is_ipv6 "$ip" && return 1
    printf '%s\n' "$ip"
}

timeout_cmd() {
    if command_exists timeout; then
        printf 'timeout\n'
    elif command_exists gtimeout; then
        printf 'gtimeout\n'
    fi
}

run_limited_ping() {
    ip=$1
    out=$2
    timeout_bin=$(timeout_cmd)
    limit=$((PING_TIMEOUT + 1))
    if is_ipv6 "$ip"; then
        if [ -n "$timeout_bin" ]; then
            "$timeout_bin" "$limit" ping -6 -c 1 "$ip" >"$out" 2>/dev/null && return 0
            command_exists ping6 && "$timeout_bin" "$limit" ping6 -c 1 "$ip" >"$out" 2>/dev/null && return 0
            return 1
        fi
        case "$(uname -s 2>/dev/null)" in
            Linux) ping -6 -c 1 -W "$PING_TIMEOUT" "$ip" >"$out" 2>/dev/null ;;
            Darwin|FreeBSD|OpenBSD) ping6 -c 1 -X "$PING_TIMEOUT" "$ip" >"$out" 2>/dev/null ;;
            *) ping -6 -c 1 -W "$PING_TIMEOUT" "$ip" >"$out" 2>/dev/null ;;
        esac
        return $?
    fi

    if [ -n "$timeout_bin" ]; then
        "$timeout_bin" "$limit" ping -c 1 "$ip" >"$out" 2>/dev/null
        return $?
    fi
    case "$(uname -s 2>/dev/null)" in
        Linux) ping -c 1 -W "$PING_TIMEOUT" "$ip" >"$out" 2>/dev/null ;;
        Darwin|FreeBSD|OpenBSD) ping -c 1 -t "$PING_TIMEOUT" -W $((PING_TIMEOUT * 1000)) "$ip" >"$out" 2>/dev/null ;;
        *) ping -c 1 -W "$PING_TIMEOUT" "$ip" >"$out" 2>/dev/null ;;
    esac
}

ping_once() {
    ip=$1
    ping_tmp=$(mktemp "$ECSSPEED_TEMP_DIR/pingout.XXXXXX" 2>/dev/null)
    [ -n "$ping_tmp" ] || ping_tmp="$ECSSPEED_TEMP_DIR/pingout.$$"
    if run_limited_ping "$ip" "$ping_tmp"; then
        awk -F'time[=<]' '/time[=<]/{split($2,a," "); print a[1]; exit}' "$ping_tmp"
        rm -f "$ping_tmp"
        return 0
    fi
    rm -f "$ping_tmp"
    return 1
}

fetch_net_records() {
    url=$1
    prefix=$2
    out=$3
    csv=$(fetch_text "$url" "$TIMEOUT_NORMAL" 2>/dev/null || true)
    printf '%s\n' "$csv" | awk -F, -v prefix="$prefix" '
        function trim(s){gsub(/\r/,"",s); gsub(/^[ \t]+|[ \t]+$/,"",s); return s}
        NF >= 5 {
            id=trim($1); city=trim($4); ip=trim($5); host=trim($6);
            if (id == "id" || id == "" || city == "" || ip == "") next;
            gsub(/ /, "", city);
            name=prefix city;
            sub(/^日本日本/, "日本", name);
            key=id "|" name "|" host "|" ip;
            if (!seen[key]++) print id "\t" id "\t" name "\t" ip "\t" host;
        }
    ' > "$out"
}

fetch_cn_records() {
    url=$1
    prefix=$2
    out=$3
    exclude_hk_tw=$4
    csv=$(fetch_text "$url" "$TIMEOUT_NORMAL" 2>/dev/null || true)
    printf '%s\n' "$csv" | awk -F, -v prefix="$prefix" -v exclude_hk_tw="$exclude_hk_tw" '
        function trim(s){gsub(/\r/,"",s); gsub(/^[ \t]+|[ \t]+$/,"",s); return s}
        NF >= 9 {
            id=trim($1); https=trim($3); host=trim($6); city=trim($9);
            ping=trim($20); download=trim($21); upload=trim($22);
            if (id == "id" || id == "" || host == "" || city == "") next;
            gsub(/ /, "", city);
            gsub(/市/, "", city);
            gsub(/中国/, "", city);
            if (exclude_hk_tw == "1" && (city ~ /香港/ || city ~ /台湾/)) next;
            host_base=host;
            sub(/:.*/, "", host_base);
            scheme=(https == "1" ? "https" : "http");
            if (ping == "") ping=scheme "://" host "/hello";
            if (download == "") download=scheme "://" host "/download";
            if (upload == "") upload=scheme "://" host "/upload";
            name=prefix city;
            key=host_base "|" name "|" id;
            if (!seen[key]++) print host "\t" id "\t" name "\t" host_base "\t" ping "\t" download "\t" upload;
        }
    ' > "$out"
}

provider_prefix() {
    path=$1
    case "$path" in
        *Mobile*|*mobile*) printf '移动' ;;
        *Telecom*|*telecom*) printf '电信' ;;
        *Unicom*|*unicom*) printf '联通' ;;
        *) printf '' ;;
    esac
}

records_for_choice() {
    rfc_choice=$1
    rfc_out=$2
    : > "$rfc_out"
    case "$ECSSPEED_MODE:$rfc_choice" in
        net:9) fetch_net_records "$SERVER_BASE_URL/SG.csv" "" "$rfc_out" ;;
        net:8) fetch_net_records "$SERVER_BASE_URL/JP.csv" "" "$rfc_out" ;;
        net:7) fetch_net_records "$SERVER_BASE_URL/TW.csv" "" "$rfc_out" ;;
        net:6) fetch_net_records "$SERVER_BASE_URL/HK.csv" "" "$rfc_out" ;;
        net:5) fetch_net_records "$SERVER_BASE_URL/CN_Mobile.csv" "移动" "$rfc_out" ;;
        net:4) fetch_net_records "$SERVER_BASE_URL/CN_Telecom.csv" "电信" "$rfc_out" ;;
        net:3) fetch_net_records "$SERVER_BASE_URL/CN_Unicom.csv" "联通" "$rfc_out" ;;
        net:2)
            fetch_net_records "$SERVER_BASE_URL/CN_Unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/u.records"
            fetch_net_records "$SERVER_BASE_URL/CN_Telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/t.records"
            fetch_net_records "$SERVER_BASE_URL/CN_Mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/m.records"
            cat "$ECSSPEED_TEMP_DIR/u.records" "$ECSSPEED_TEMP_DIR/t.records" "$ECSSPEED_TEMP_DIR/m.records" > "$rfc_out"
            ;;
        net:1)
            nearest_three_net "$rfc_out"
            ;;
        cn:9) fetch_cn_records "$SERVER_BASE_URL/SG.csv" "" "$rfc_out" 0 ;;
        cn:8) fetch_cn_records "$SERVER_BASE_URL/JP.csv" "" "$rfc_out" 0 ;;
        cn:7) fetch_cn_records "$SERVER_BASE_URL/TW.csv" "" "$rfc_out" 0 ;;
        cn:6) fetch_cn_records "$SERVER_BASE_URL/HK.csv" "" "$rfc_out" 0 ;;
        cn:5) fetch_cn_records "$SERVER_BASE_URL/mobile.csv" "移动" "$rfc_out" 0 ;;
        cn:4) fetch_cn_records "$SERVER_BASE_URL/telecom.csv" "电信" "$rfc_out" 0 ;;
        cn:3) fetch_cn_records "$SERVER_BASE_URL/unicom.csv" "联通" "$rfc_out" 0 ;;
        cn:2)
            fetch_cn_records "$SERVER_BASE_URL/unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/u.records" 0
            fetch_cn_records "$SERVER_BASE_URL/telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/t.records" 0
            fetch_cn_records "$SERVER_BASE_URL/mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/m.records" 0
            cat "$ECSSPEED_TEMP_DIR/u.records" "$ECSSPEED_TEMP_DIR/t.records" "$ECSSPEED_TEMP_DIR/m.records" > "$rfc_out"
            ;;
        cn:1)
            nearest_three_cn "$rfc_out"
            ;;
    esac
}

nearest_three_net() {
    ntn_out=$1
    : > "$ntn_out"
    fetch_net_records "$SERVER_BASE_URL/CN_Unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/unicom.records"
    select_nearest "$ECSSPEED_TEMP_DIR/unicom.records" "$ECSSPEED_TEMP_DIR/unicom.nearest" 2
    fetch_net_records "$SERVER_BASE_URL/CN_Telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/telecom.records"
    select_nearest "$ECSSPEED_TEMP_DIR/telecom.records" "$ECSSPEED_TEMP_DIR/telecom.nearest" 2
    fetch_net_records "$SERVER_BASE_URL/CN_Mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/mobile.records"
    select_nearest "$ECSSPEED_TEMP_DIR/mobile.records" "$ECSSPEED_TEMP_DIR/mobile.nearest" 2
    cat "$ECSSPEED_TEMP_DIR/unicom.nearest" "$ECSSPEED_TEMP_DIR/telecom.nearest" "$ECSSPEED_TEMP_DIR/mobile.nearest" > "$ntn_out"
}

nearest_three_cn() {
    ntc_out=$1
    : > "$ntc_out"
    fetch_cn_records "$SERVER_BASE_URL/unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/unicom.records" 1
    select_nearest "$ECSSPEED_TEMP_DIR/unicom.records" "$ECSSPEED_TEMP_DIR/unicom.nearest" 2
    fetch_cn_records "$SERVER_BASE_URL/telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/telecom.records" 1
    select_nearest "$ECSSPEED_TEMP_DIR/telecom.records" "$ECSSPEED_TEMP_DIR/telecom.nearest" 2
    fetch_cn_records "$SERVER_BASE_URL/mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/mobile.records" 1
    select_nearest "$ECSSPEED_TEMP_DIR/mobile.records" "$ECSSPEED_TEMP_DIR/mobile.nearest" 2
    cat "$ECSSPEED_TEMP_DIR/unicom.nearest" "$ECSSPEED_TEMP_DIR/telecom.nearest" "$ECSSPEED_TEMP_DIR/mobile.nearest" > "$ntc_out"
}

ping_record_worker() {
    endpoint=$1
    idx=$2
    dir=$3
    ping_url=$4
    ip=$(clean_endpoint_ip "$endpoint" 2>/dev/null || true)
    [ -n "$ip" ] || exit 0
    if [ "$ECSSPEED_MODE" = "cn" ] && [ -n "$ping_url" ] && command_exists curl; then
        stat=$(curl_speed_stat "$ping_url" latency)
        code=$(printf '%s\n' "$stat" | awk '{print $1}')
        seconds=$(printf '%s\n' "$stat" | awk '{print $2}')
        if valid_http_code "$code" && [ -n "$seconds" ]; then
            latency=$(LC_ALL=C awk -v s="$seconds" 'BEGIN{printf "%.3f", s * 1000}')
        else
            latency=
        fi
    else
        latency=$(ping_once "$ip" 2>/dev/null || true)
    fi
    [ -n "$latency" ] || exit 0
    printf '%s\t%s\n' "$latency" "$idx" > "$dir/$idx.ping"
}

ping_output_worker() {
    endpoint=$1
    idx=$2
    dir=$3
    ping_url=$4
    ip=$(clean_endpoint_ip "$endpoint" 2>/dev/null || true)
    [ -n "$ip" ] || exit 0
    if [ "$ECSSPEED_MODE" = "cn" ] && [ -n "$ping_url" ] && command_exists curl; then
        stat=$(curl_speed_stat "$ping_url" latency)
        code=$(printf '%s\n' "$stat" | awk '{print $1}')
        seconds=$(printf '%s\n' "$stat" | awk '{print $2}')
        if valid_http_code "$code" && [ -n "$seconds" ]; then
            latency=$(LC_ALL=C awk -v s="$seconds" 'BEGIN{printf "%.3f", s * 1000}')
        else
            latency=
        fi
    else
        latency=$(ping_once "$ip" 2>/dev/null || true)
    fi
    [ -n "$latency" ] || exit 0
    printf '%s\t%s\t%s\n' "$latency" "$idx" "$ip" > "$dir/$idx.ping"
}

select_nearest() {
    in=$1
    out=$2
    count=$3
    : > "$out"
    [ -s "$in" ] || return 0
    pdir="$ECSSPEED_TEMP_DIR/ping.$$.$(basename "$out")"
    mkdir -p "$pdir" || return 1
    idx=0
    active=0
    while IFS="$(printf '\t')" read -r target id name endpoint ping_url download_url upload_url rest || [ -n "$target" ]; do
        idx=$((idx + 1))
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$target" "$id" "$name" "$endpoint" "$ping_url" "$download_url" "$upload_url" > "$pdir/$idx.record"
        ping_record_worker "$endpoint" "$idx" "$pdir" "$ping_url" &
        active=$((active + 1))
        if [ "$active" -ge "$PING_CONCURRENCY" ]; then
            wait
            active=0
        fi
    done < "$in"
    wait
    cat "$pdir"/*.ping 2>/dev/null | sort -n | head -n "$count" | while IFS="$(printf '\t')" read -r latency idx; do
        cat "$pdir/$idx.record"
    done > "$out"
    rm -rf "$pdir"
}

ping_records_sorted() {
    family=$1
    in=$2
    out=$3
    : > "$out"
    [ -s "$in" ] || return 0
    pdir="$ECSSPEED_TEMP_DIR/pingout.$$.$family.$(basename "$out")"
    mkdir -p "$pdir" || return 1
    idx=0
    active=0
    while IFS="$(printf '\t')" read -r target node_id name endpoint ping_url download_url upload_url rest || [ -n "$target" ]; do
        idx=$((idx + 1))
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$target" "$node_id" "$name" "$endpoint" "$ping_url" "$download_url" "$upload_url" > "$pdir/$idx.record"
        ping_output_worker "$endpoint" "$idx" "$pdir" "$ping_url" &
        active=$((active + 1))
        if [ "$active" -ge "$PING_CONCURRENCY" ]; then
            wait
            active=0
        fi
    done < "$in"
    wait
    cat "$pdir"/*.ping 2>/dev/null | sort -n | while IFS="$(printf '\t')" read -r latency idx ip; do
        IFS="$(printf '\t')" read -r target node_id name endpoint ping_url download_url upload_url rest < "$pdir/$idx.record"
        printf '%s-speedtest.%s-%s\t%s\t%s\n' "$node_id" "$family" "$name" "$latency" "$ip"
    done > "$out"
    rm -rf "$pdir"
}

precheck_record() {
    endpoint=$1
    ping_url=$2
    [ "$PRECHECK_NODES" = "1" ] || return 0
    if [ "$ECSSPEED_MODE" = "cn" ] && [ -n "$ping_url" ] && command_exists curl; then
        curl -fsSL -A "$ECSSPEED_BROWSER_UA" --connect-timeout "$TIMEOUT_SHORT" --max-time "$TIMEOUT_NORMAL" -o /dev/null "$ping_url" 2>/dev/null
        return $?
    fi
    ip=$(clean_endpoint_ip "$endpoint" 2>/dev/null || true)
    [ -n "$ip" ] || return 1
    latency=$(ping_once "$ip" 2>/dev/null || true)
    [ -n "$latency" ]
}

normalize_metric() {
    val=$1
    unit=$2
    cleaned=$(printf '%s' "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$cleaned" ] && { printf 'NULL\n'; return; }
    metric_num=$(printf '%s\n' "$cleaned" | awk '{print $1}')
    metric_unit=$(printf '%s\n' "$cleaned" | awk '{$1=""; sub(/^[ \t]+/,""); print}' | sed 's/[[:space:]]*(.*//')
    [ -n "$metric_unit" ] || metric_unit=$unit
    case "$metric_num" in
        *[!0-9.]*|'') printf '%s\n' "$cleaned" | sed 's/[[:space:]][[:space:]]*/ /g' ;;
        *) LC_ALL=C awk -v n="$metric_num" -v u="$metric_unit" 'BEGIN{printf "%.2f %s\n", n, u}' ;;
    esac
}

extract_labeled_value() {
    label=$1
    log=$2
    awk -v label="$label" '
        $0 ~ label "[[:space:]]*:" {
            sub(".*" label "[[:space:]]*:[[:space:]]*", "", $0)
            print
            exit
        }
    ' "$log"
}

extract_first_number() {
    printf '%s\n' "$1" | awk '
        {
            for (i = 1; i <= NF; i++) {
                field = $i
                gsub(/,/, ".", field)
                gsub(/^[^0-9.]*/, "", field)
                gsub(/[^0-9.].*$/, "", field)
                if (field ~ /^[0-9]+([.][0-9]+)?$/) {
                    print field
                    exit
                }
            }
        }
    '
}

format_mbps_from_bytes_per_second() {
    bytes_per_second=$1
    LC_ALL=C awk -v b="$bytes_per_second" 'BEGIN{printf "%.2f Mbps\n", b * 8 / 1000000}'
}

format_seconds_as_ms() {
    seconds=$1
    LC_ALL=C awk -v s="$seconds" 'BEGIN{printf "%.2fms\n", s * 1000}'
}

ensure_upload_payload() {
    CN_UPLOAD_PAYLOAD="$ECSSPEED_TEMP_DIR/upload-payload.bin"
    [ -s "$CN_UPLOAD_PAYLOAD" ] && return 0
    dd if=/dev/zero of="$CN_UPLOAD_PAYLOAD" bs=1024 count=512 >/dev/null 2>&1
}

curl_speed_stat() {
    stat_url=$1
    stat_mode=$2
    case "$stat_mode" in
        download)
            curl -L -A "$ECSSPEED_BROWSER_UA" --connect-timeout "$TIMEOUT_NORMAL" --max-time "$TIMEOUT_NORMAL" \
                -o /dev/null -w '%{http_code} %{speed_download} %{size_download} %{time_total}\n' "$stat_url" 2>/dev/null || true
            ;;
        upload)
            ensure_upload_payload || return 1
            curl -L -A "$ECSSPEED_BROWSER_UA" --connect-timeout "$TIMEOUT_NORMAL" --max-time "$TIMEOUT_NORMAL" \
                -X POST --data-binary "@$CN_UPLOAD_PAYLOAD" -o /dev/null \
                -w '%{http_code} %{speed_upload} %{size_upload} %{time_total}\n' "$stat_url" 2>/dev/null || true
            ;;
        latency)
            curl -fsSL -A "$ECSSPEED_BROWSER_UA" --connect-timeout "$TIMEOUT_SHORT" --max-time "$TIMEOUT_NORMAL" \
                -o /dev/null -w '%{http_code} %{time_total}\n' "$stat_url" 2>/dev/null || true
            ;;
    esac
}

valid_http_code() {
    case "$1" in
        2*|3*) return 0 ;;
        *) return 1 ;;
    esac
}

measure_http_latency() {
    ping_url=$1
    samples=
    i=1
    while [ "$i" -le 3 ]; do
        stat=$(curl_speed_stat "$ping_url" latency)
        code=$(printf '%s\n' "$stat" | awk '{print $1}')
        seconds=$(printf '%s\n' "$stat" | awk '{print $2}')
        if valid_http_code "$code" && [ -n "$seconds" ]; then
            samples="$samples $seconds"
        fi
        i=$((i + 1))
    done
    [ -n "$samples" ] || return 1
    best=$(printf '%s\n' $samples | LC_ALL=C awk 'NR == 1 || $1 < min {min=$1} END{print min}')
    format_seconds_as_ms "$best"
}

measure_http_speed() {
    url=$1
    mode=$2
    stat=$(curl_speed_stat "$url" "$mode")
    code=$(printf '%s\n' "$stat" | awk '{print $1}')
    speed=$(printf '%s\n' "$stat" | awk '{print $2}')
    size=$(printf '%s\n' "$stat" | awk '{print $3}')
    valid_http_code "$code" || return 1
    case "$speed" in
        ''|*[!0-9.]*)
            return 1
            ;;
    esac
    case "$size" in
        ''|*[!0-9.]*)
            return 1
            ;;
    esac
    LC_ALL=C awk -v s="$speed" -v z="$size" 'BEGIN{exit !(s > 0 && z > 0)}' || return 1
    format_mbps_from_bytes_per_second "$speed"
}

parse_speedtest_log() {
    log=$1
    dl=$(extract_labeled_value "Download" "$log")
    up=$(extract_labeled_value "Upload" "$log")
    latency=$(extract_labeled_value "Latency" "$log")
    dl=$(normalize_metric "$dl" "Mbps")
    up=$(normalize_metric "$up" "Mbps")
    latency=$(extract_first_number "$latency")
    [ -n "$latency" ] && latency=$(LC_ALL=C awk -v n="$latency" 'BEGIN{printf "%.2fms\n", n}') || latency="NULL"
    printf '%s\t%s\t%s\n' "$up" "$dl" "$latency"
}

run_cn_speedtest_record() {
    node_id=$1
    name=$2
    ping_url=$3
    download_url=$4
    upload_url=$5
    [ -n "$ping_url" ] || return 1
    [ -n "$download_url" ] || return 1
    [ -n "$upload_url" ] || return 1
    latency=$(measure_http_latency "$ping_url" 2>/dev/null || true)
    dl=$(measure_http_speed "$download_url" download 2>/dev/null || true)
    up=$(measure_http_speed "$upload_url" upload 2>/dev/null || true)
    [ -n "$latency" ] || latency="NULL"
    [ -n "$dl" ] || dl="NULL"
    [ -n "$up" ] || up="NULL"
    if [ "$up$dl$latency" != "NULLNULLNULL" ]; then
        emit_speed_result "$node_id" "$name" "$up" "$dl" "$latency" "ok" ""
        return 0
    fi
    emit_speed_result "$node_id" "$name" "NULL" "NULL" "NULL" "failed" "speedtest.cn http probe failed"
    return 1
}

run_speedtest_record() {
    target=$1
    node_id=$2
    name=$3
    endpoint=$4
    ping_url=$5
    download_url=$6
    upload_url=$7
    if [ "$ECSSPEED_MODE" = "cn" ]; then
        run_cn_speedtest_record "$node_id" "$name" "$ping_url" "$download_url" "$upload_url"
        return $?
    fi
    log="$ECSSPEED_TEMP_DIR/speedtest-${node_id}.log"
    tries=1
    delay=1
    while [ "$tries" -le "$RETRIES" ]; do
        rm -f "$log"
        speedtest_ok=0
        if [ "$ECSSPEED_MODE" = "net" ]; then
            "$SPEEDTEST_BIN" --ua="$ECSSPEED_BROWSER_UA" --server="$target" > "$log" 2>&1
            speedtest_ok=$?
        else
            "$SPEEDTEST_BIN" --ua="$ECSSPEED_BROWSER_UA" --custom-url="http://$target/upload.php" > "$log" 2>&1
            speedtest_ok=$?
        fi
        if [ "$speedtest_ok" -eq 0 ]; then
            parsed=$(parse_speedtest_log "$log")
            up=$(printf '%s\n' "$parsed" | awk -F '\t' '{print $1}')
            dl=$(printf '%s\n' "$parsed" | awk -F '\t' '{print $2}')
            latency=$(printf '%s\n' "$parsed" | awk -F '\t' '{print $3}')
            if [ "$up$dl$latency" != "NULLNULLNULL" ]; then
                emit_speed_result "$node_id" "$name" "$up" "$dl" "$latency" "ok" ""
                return 0
            fi
        fi
        tries=$((tries + 1))
        [ "$tries" -le "$RETRIES" ] && sleep "$delay"
        delay=$((delay * 2))
    done
    error_msg=$(tail -n 3 "$log" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')
    emit_speed_result "$node_id" "$name" "NULL" "NULL" "NULL" "failed" "$error_msg"
    return 1
}

emit_speed_result() {
    node_id=$1
    name=$2
    upload=$3
    download=$4
    latency=$5
    status=$6
    error_msg=$7
    if [ "$status" = "ok" ]; then
        print_line "$(pad_str "$node_id $name" 24)$(pad_str "$upload" 16)$(pad_str "$download" 16)$latency"
    else
        warn "$(pad_str "$node_id $name" 24) test failed"
    fi
    printf 'speed\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ECSSPEED_MODE" "$node_id" "$name" "$upload" "$download" "$latency" "$status" "$error_msg" >> "$RESULTS_FILE"
}

test_records() {
    records=$1
    [ -s "$records" ] || { warn "no server records available"; return 0; }
    while IFS="$(printf '\t')" read -r target node_id name endpoint ping_url download_url upload_url rest || [ -n "$target" ]; do
        [ -n "$target" ] || continue
        if ! precheck_record "$endpoint" "$ping_url"; then
            warn "$node_id $name unreachable, skipped"
            printf 'speed\t%s\t%s\t%s\tNULL\tNULL\tNULL\tskipped\tunreachable\n' "$ECSSPEED_MODE" "$node_id" "$name" >> "$RESULTS_FILE"
            continue
        fi
        run_speedtest_record "$target" "$node_id" "$name" "$endpoint" "$ping_url" "$download_url" "$upload_url" || true
    done < "$records"
}

run_speed_mode() {
    preinfo
    selecttest
    case "$selection" in
        10) print_line "Exit"; return 0 ;;
        1|2|3|4|5|6|7|8|9) ;;
        *) die "invalid test type: $selection" ;;
    esac
    if [ "$ECSSPEED_MODE" = "net" ]; then
        ensure_speedtest_go || die "speedtest-go is unavailable for this system"
        info "speedtest-go: $(cat "$SPEEDTEST_VERSION_FILE" 2>/dev/null || printf unknown)"
    else
        ensure_command curl "curl" || die "curl is required for ecsspeed-cn HTTP speed tests"
    fi
    START_TIME=$(date +%s)
    warn "checking speedtest servers"
    records="$ECSSPEED_TEMP_DIR/selected.records"
    records_for_choice "$selection" "$records"
    if [ "$selection" = "1" ]; then
        blue "就近节点若缺少某运营商，那么该运营商连通性很差，建议使用对应运营商选项全测看看"
    fi
    temp_head
    test_records "$records"
    print_end_time
}

ping_collect_one() {
    pco_family=$1
    pco_source_url=$2
    pco_prefix=$3
    pco_out=$4
    pco_raw="$ECSSPEED_TEMP_DIR/$pco_family.$pco_prefix.records"
    if [ "$pco_family" = "cn" ]; then
        fetch_cn_records "$pco_source_url" "$pco_prefix" "$pco_raw" 1
    else
        fetch_net_records "$pco_source_url" "$pco_prefix" "$pco_raw"
    fi
    ping_records_sorted "$pco_family" "$pco_raw" "$pco_out"
}

run_ping_mode() {
    preinfo
    START_TIME=$(date +%s)
    warn "checking speedtest servers and ping latency"
    ping_collect_one cn "$SERVER_BASE_URL_CN/unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/ping.cn.unicom" &
    ping_collect_one net "$SERVER_BASE_URL_NET/CN_Unicom.csv" "联通" "$ECSSPEED_TEMP_DIR/ping.net.unicom" &
    wait
    ping_collect_one cn "$SERVER_BASE_URL_CN/telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/ping.cn.telecom" &
    ping_collect_one net "$SERVER_BASE_URL_NET/CN_Telecom.csv" "电信" "$ECSSPEED_TEMP_DIR/ping.net.telecom" &
    wait
    ping_collect_one cn "$SERVER_BASE_URL_CN/mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/ping.cn.mobile" &
    ping_collect_one net "$SERVER_BASE_URL_NET/CN_Mobile.csv" "移动" "$ECSSPEED_TEMP_DIR/ping.net.mobile" &
    wait
    combined="$ECSSPEED_TEMP_DIR/ping.combined"
    cat "$ECSSPEED_TEMP_DIR"/ping.cn.unicom "$ECSSPEED_TEMP_DIR"/ping.net.unicom \
        "$ECSSPEED_TEMP_DIR"/ping.cn.telecom "$ECSSPEED_TEMP_DIR"/ping.net.telecom \
        "$ECSSPEED_TEMP_DIR"/ping.cn.mobile "$ECSSPEED_TEMP_DIR"/ping.net.mobile 2>/dev/null |
        awk -F '\t' '!seen[$3]++ {print}' > "$combined"
    print_ping_table "$combined"
    print_end_time
}

print_ping_table() {
    file=$1
    counter=0
    while IFS="$(printf '\t')" read -r label latency ip || [ -n "$label" ]; do
        clean_label=$(printf '%s' "$label" | sed 's/^[0-9]*-speedtest\.[a-z]*-//;s/5G//g')
        latency_int=$(printf '%s' "$latency" | cut -d. -f1)
        [ -n "$latency_int" ] || latency_int=9999
        color=$RED
        if [ "$latency_int" -le 50 ] 2>/dev/null; then color=$GREEN
        elif [ "$latency_int" -le 100 ] 2>/dev/null; then color=$GREEN
        elif [ "$latency_int" -le 200 ] 2>/dev/null; then color=$BLUE
        elif [ "$latency_int" -le 300 ] 2>/dev/null; then color=$YELLOW
        fi
        cell="$(pad_str "$clean_label" 18)$(pad_str "${latency_int}ms" 8)"
        if [ "$JSON_MODE" = "1" ]; then
            printf '%s|' "$cell" >&2
        else
            printf '%b%s%b|' "$color" "$cell" "$PLAIN"
        fi
        log_plain "$clean_label ${latency_int}ms"
        printf 'ping\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ECSSPEED_MODE" "NULL" "$clean_label" "NULL" "NULL" "${latency_int}ms" "ok" "" >> "$RESULTS_FILE"
        counter=$((counter + 1))
        if [ $((counter % 3)) -eq 0 ]; then
            if [ "$JSON_MODE" = "1" ]; then printf '\n' >&2; else printf '\n'; fi
        fi
    done < "$file"
    if [ $((counter % 3)) -ne 0 ]; then
        if [ "$JSON_MODE" = "1" ]; then printf '\n' >&2; else printf '\n'; fi
    fi
}

print_end_time() {
    end_time=$(date +%s)
    [ -n "$START_TIME" ] || START_TIME=$end_time
    elapsed=$((end_time - START_TIME))
    table_rule
    if [ "$elapsed" -gt 60 ]; then
        min=$((elapsed / 60))
        sec=$((elapsed % 60))
        print_line " 总共花费      : ${min} 分 ${sec} 秒"
    else
        print_line " 总共花费      : ${elapsed} 秒"
    fi
    print_line " 时间          : $(date)"
    table_rule
}

json_escape() {
    printf '%s' "$1" | awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); gsub(/\r/,"\\r"); gsub(/\n/,"\\n"); print}'
}

print_json_results() {
    json_tmp="$ECSSPEED_TEMP_DIR/results.json"
    {
        printf '{'
        printf '"mode":"%s",' "$(json_escape "$ECSSPEED_MODE")"
        printf '"script_version":"%s",' "$(json_escape "$ECSSPEED_SCRIPT_VERSION")"
        printf '"results":['
        first=1
        while IFS="$(printf '\t')" read -r kind mode node_id name upload download latency status error_msg || [ -n "$kind" ]; do
            [ -n "$kind" ] || continue
            [ "$first" = "1" ] || printf ','
            first=0
            printf '{'
            printf '"kind":"%s",' "$(json_escape "$kind")"
            printf '"mode":"%s",' "$(json_escape "$mode")"
            printf '"id":"%s",' "$(json_escape "$node_id")"
            printf '"name":"%s",' "$(json_escape "$name")"
            printf '"upload":"%s",' "$(json_escape "$upload")"
            printf '"download":"%s",' "$(json_escape "$download")"
            printf '"latency":"%s",' "$(json_escape "$latency")"
            printf '"status":"%s",' "$(json_escape "$status")"
            printf '"error":"%s"' "$(json_escape "$error_msg")"
            printf '}'
        done < "$RESULTS_FILE"
        printf ']}'
        printf '\n'
    } > "$json_tmp"
    cat "$json_tmp"
    [ -n "$JSON_FILE" ] && cp "$json_tmp" "$JSON_FILE"
}
