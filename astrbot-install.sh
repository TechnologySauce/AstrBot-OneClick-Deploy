#!/bin/bash
# ==============================================================================
# AstrBot 一键部署脚本
# 一键安装 Docker 并部署 AstrBot / Napcat 服务
#
# 作者：科技酱
# 网站：https://www.asoe.cn
# 技术文档：https://docs.asoe.cn
# GitHub：https://github.com/techjiang/
# 哔哩哔哩：https://space.bilibili.com/1768832152
# 玲珑：https://forums.asoe.cn/
# QQ群：291974598  QQ群②：474819022  QQ群③：631167288
#
# 项目仓库：https://gitee.com/einternet/AstrBot-OneClick-Deploy
# ==============================================================================

# 不使用 set -e，改为手动错误处理以提供更好的交互体验

# ============================== 全局变量定义 ==============================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 项目信息
PROJECT_NAME="AstrBot"
AUTHOR="科技酱"
VERSION="2.0.0"

# 容器与数据卷配置
ASTRBOT_CONTAINER_NAME="astrbot"
NAPCAT_CONTAINER_NAME="napcat"
ASTRBOT_IMAGE="snowykami/astrbot:latest"
NAPCAT_IMAGE="mlikiowa/napcat-docker:latest"

# 数据卷路径（宿主机）
ASTRBOT_DATA_DIR="/home/astrbot/data"
NAPCAT_DATA_DIR="/home/napcat/data"

# 备份目录
BACKUP_DIR="/home/astrbot/backup"

# 端口配置
ASTRBOT_PORT="6185"
NAPCAT_PORT="6099"

# 脚本下载地址
SCRIPT_URL="https://gitee.com/einternet/AstrBot-OneClick-Deploy/raw/main/astrbot-install.sh"

# 镜像加速器配置文件
DAEMON_JSON="/etc/docker/daemon.json"

# 非交互模式标志
NON_INTERACTIVE=false

# 部署方式：docker（docker run）或 compose（docker compose）
DEPLOY_METHOD="docker"

# Docker Compose 文件路径
COMPOSE_FILE="/home/astrbot/docker-compose.yml"

# 全局错误计数
ERROR_COUNT=0

# ============================== 基础函数 ==============================

# 打印信息
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# 打印警告
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 打印错误
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

# 打印提示
tip() {
    echo -e "${CYAN}[TIP]${NC} $1"
}

# 打印步骤
step() {
    echo ""
    echo -e "${PURPLE}▶ $1${NC}"
}

# 分隔线
print_separator() {
    echo -e "${BLUE}================================================================${NC}"
}

# 确认提示（非交互模式下自动确认）
confirm() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi
    local msg="$1"
    local default="${2:-y}"
    local prompt
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    read -p "$msg $prompt: " REPLY
    REPLY=${REPLY:-$default}
    case "$REPLY" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 获取服务器 IP 地址
get_server_ip() {
    local ip
    # 优先获取公网 IP
    if command_exists curl; then
        ip=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || true)
    fi
    # 获取内网 IP 作为后备
    if [ -z "$ip" ] || [ "$ip" = "" ]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$ip" ] || [ "$ip" = "" ]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
}

# 检查网络连通性
check_network() {
    info "检查网络连通性..."
    local test_hosts=("gitee.com" "download.docker.com" "hub.docker.com")
    local all_ok=true
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            info "  ✓ $host 可达"
        else
            warn "  ✗ $host 不可达（可能影响安装）"
            all_ok=false
        fi
    done
    if [ "$all_ok" = false ]; then
        warn "部分网络不可达，安装过程可能受影响。"
        if ! confirm "是否继续？" "n"; then
            info "用户取消，退出。"
            exit 0
        fi
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":${port} " ; then
        return 0  # 端口被占用
    elif netstat -tlnp 2>/dev/null | grep -q ":${port} " ; then
        return 0
    else
        return 1  # 端口可用
    fi
}

# 等待容器健康
wait_container_healthy() {
    local container_name=$1
    local max_wait=60
    local waited=0
    while [ $waited -lt $max_wait ]; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "notfound")
        if [ "$status" = "running" ]; then
            return 0
        elif [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
            return 1
        fi
        sleep 2
        waited=$((waited + 2))
        echo -ne "${CYAN}等待容器启动... ${waited}s${NC}\r"
    done
    echo ""
    return 1
}

# 打印横幅
print_banner() {
    clear
    echo -e "${PURPLE}"
    cat <<'BANNER'
  █████╗ ██╗   ██╗██████╗  ██████╗ ███████╗██╗   ██╗    ██████╗██╗  ██╗    ██████╗
  ██╔══██╗╚██╗ ██╔╝██╔══██╗██╔═══██╗██╔════╝██║   ██║   ██╔════╝██║  ██║   ██╔═══██╗
  ███████║ ╚████╔╝ ██████╔╝██║   ██║███████╗██║   ██║   ██║     ███████║   ██║   ██║
  ██╔══██║  ╚██╔╝  ██╔══██╗██║   ██║╚════██║██║   ██║   ██║     ██╔══██║   ██║   ██║
  ██║  ██║   ██║   ██████╔╝╚██████╔╝███████║╚██████╔╝   ╚██████╗██║  ██║   ╚██████╔╝
  ╚═╝  ╚═╝   ╚═╝   ╚═════╝  ╚═════╝ ╚══════╝ ╚═════╝     ╚═════╝╚═╝  ╚═╝    ╚═════╝
BANNER
    echo -e "${NC}"
    print_separator
    echo -e "  ${GREEN}AstrBot 一键部署脚本 v${VERSION}${NC}"
    echo -e "  作者：${AUTHOR}"
    echo -e "  官网：https://www.asoe.cn"
    echo -e "  文档：https://docs.asoe.cn"
    echo -e "  项目：https://gitee.com/einternet/AstrBot-OneClick-Deploy"
    echo -e "  部署方式：${YELLOW}${DEPLOY_METHOD}${NC}"
    if [ "$NON_INTERACTIVE" = true ]; then
        echo -e "  模式：${YELLOW}非交互模式${NC}"
    fi
    print_separator
    echo -e "  ${YELLOW}AstrBot 官方文档：https://astrbot.app${NC}"
    print_separator
    echo ""
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行！请使用 sudo 或切换到 root 用户。"
        echo -e "  示例：sudo $0"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        OS_VERSION_ID="$VERSION_ID"
        info "检测到系统：$PRETTY_NAME"
    else
        error "无法检测系统类型！请确保使用 Ubuntu 20.04+ 或 Debian 11+ 系统。"
        exit 1
    fi

    # 检查是否为受支持的系统
    case "$OS_ID" in
        ubuntu|debian)
            info "系统兼容性检查通过（$OS_ID $OS_VERSION_ID）"
            ;;
        *)
            warn "检测到非 Ubuntu/Debian 系统（$OS_ID），脚本可能不完全兼容。"
            warn "推荐使用 Ubuntu 20.04+ 或 Debian 11+ 系统。"
            if ! confirm "是否继续？" "n"; then
                info "用户取消，退出。"
                exit 0
            fi
            ;;
    esac

    # 检查 CPU 架构
    local arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    info "CPU 架构：$arch"

    # 检查内存
    local total_mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "$total_mem_kb" ]; then
        local total_mem_mb=$((total_mem_kb / 1024))
        if [ $total_mem_mb -lt 512 ]; then
            warn "内存不足 512MB（当前：${total_mem_mb}MB），可能导致服务不稳定"
        else
            info "内存：${total_mem_mb}MB"
        fi
    fi

    # 检查磁盘空间
    local avail_disk_kb=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$avail_disk_kb" ]; then
        local avail_disk_mb=$((avail_disk_kb / 1024))
        local avail_disk_gb=$((avail_disk_mb / 1024))
        if [ $avail_disk_mb -lt 1024 ]; then
            warn "磁盘可用空间不足 1GB（当前：${avail_disk_mb}MB）"
        else
            info "可用磁盘空间：${avail_disk_gb}GB"
        fi
    fi
}

# 检查端口占用
check_ports() {
    local port_conflict=false

    if check_port "$ASTRBOT_PORT"; then
        warn "端口 $ASTRBOT_PORT 已被占用！"
        echo -e "  占用进程：$(ss -tlnp 2>/dev/null | grep ':*${ASTRBOT_PORT} ' || echo '未知')"
        port_conflict=true
    fi

    if check_port "$NAPCAT_PORT"; then
        warn "端口 $NAPCAT_PORT 已被占用！"
        echo -e "  占用进程：$(ss -tlnp 2>/dev/null | grep ':*${NAPCAT_PORT} ' || echo '未知')"
        port_conflict=true
    fi

    if [ "$port_conflict" = true ]; then
        warn "存在端口冲突，可能导致服务无法正常启动"
        if ! confirm "是否继续？" "n"; then
            info "用户取消，退出。"
            exit 0
        fi
    else
        info "端口检查通过（$ASTRBOT_PORT, $NAPCAT_PORT 均可用）"
    fi
}

# ============================== Docker 安装与配置 ==============================

# 检查 Docker 是否已安装
check_docker() {
    if command -v docker &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装 Docker
install_docker() {
    print_separator
    echo -e "${CYAN}[Docker 安装]${NC}"
    print_separator

    if check_docker; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        info "Docker 已安装（版本：$DOCKER_VERSION）"
        if confirm "是否重新安装/更新 Docker？" "n"; then
            info "开始更新 Docker..."
        else
            info "跳过 Docker 安装。"
            return 0
        fi
    else
        info "未检测到 Docker，开始安装..."
    fi

    # 更新 apt 并安装依赖
    step "更新系统包管理器并安装依赖..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        wget \
        software-properties-common \
        iptables \
        >/dev/null 2>&1

    # 安装 Docker GPG key
    step "添加 Docker 官方 GPG 密钥..."
    install -m 0755 -d /etc/apt/keyrings
    # 先清理旧的 key 文件
    rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    if ! curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        warn "Docker 官方源获取 GPG 密钥失败，尝试使用国内镜像源..."
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$OS_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 添加 Docker apt 源
    step "添加 Docker apt 源..."
    DOCKER_REPO="https://download.docker.com/linux/$OS_ID"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO} \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    # 安装 Docker
    step "安装 Docker CE..."
    apt-get update -y >/dev/null 2>&1
    if ! apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        >/dev/null 2>&1; then
        warn "从 Docker 官方源安装失败，尝试使用阿里云镜像源..."
        # 替换为阿里云源
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/$OS_ID \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
        apt-get update -y >/dev/null 2>&1
        apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin \
            >/dev/null 2>&1
    fi

    # 启动 Docker 并设置开机自启
    step "启动 Docker 服务..."
    systemctl start docker
    systemctl enable docker

    # 验证安装
    if check_docker; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        info "Docker 安装成功！版本：$DOCKER_VERSION"
        # 验证 Docker 运行
        if docker info >/dev/null 2>&1; then
            info "Docker 守护进程运行正常"
        else
            warn "Docker 守护进程可能未正常运行，请检查：systemctl status docker"
        fi
    else
        error "Docker 安装失败！请检查系统日志。"
        exit 1
    fi
}

# 配置 Docker 镜像加速
configure_docker_mirror() {
    print_separator
    echo -e "${CYAN}[Docker 镜像加速配置]${NC}"
    print_separator

    if [ -f "$DAEMON_JSON" ]; then
        info "已存在 Docker 镜像加速配置文件：$DAEMON_JSON"
        if ! confirm "是否覆盖更新镜像加速配置？" "y"; then
            info "跳过镜像加速配置。"
            return 0
        fi
    else
        info "未检测到镜像加速配置，开始配置..."
    fi

    # 写入镜像加速配置
    step "写入镜像加速源配置..."
    mkdir -p $(dirname "$DAEMON_JSON")
    cat > "$DAEMON_JSON" <<'EOF'
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.xuanyuan.me",
        "https://docker.m.daocloud.io",
        "https://dockerproxy.com",
        "https://docker.nju.edu.cn",
        "https://mirror.ccs.tencentyun.com",
        "https://hub-mirror.c.163.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-shm-size": "128M"
}
EOF

    # 重启 Docker 使配置生效
    step "重启 Docker 使配置生效..."
    systemctl daemon-reload
    systemctl restart docker

    info "镜像加速配置完成！"
    tip "已配置以下加速源："
    echo -e "    - https://docker.1ms.run"
    echo -e "    - https://docker.xuanyuan.me"
    echo -e "    - https://docker.m.daocloud.io"
    echo -e "    - https://dockerproxy.com"
    echo -e "    - https://docker.nju.edu.cn"
    echo -e "    - https://mirror.ccs.tencentyun.com"
    echo -e "    - https://hub-mirror.c.163.com"
}

# 配置防火墙
configure_firewall() {
    print_separator
    echo -e "${CYAN}[防火墙配置]${NC}"
    print_separator

    if command_exists ufw; then
        info "检测到 UFW 防火墙"
        info "开放端口：$ASTRBOT_PORT (AstrBot), $NAPCAT_PORT (NapCat)"
        ufw allow "$ASTRBOT_PORT"/tcp >/dev/null 2>&1 || true
        ufw allow "$NAPCAT_PORT"/tcp >/dev/null 2>&1 || true
        if ufw status 2>/dev/null | grep -q "inactive"; then
            warn "UFW 防火墙当前未启用"
            if confirm "是否启用 UFW 防火墙？（注意：确保 SSH 端口已放行）" "n"; then
                ufw allow 22/tcp >/dev/null 2>&1 || true
                ufw --force enable >/dev/null 2>&1
                ufw reload >/dev/null 2>&1
                info "UFW 防火墙已启用"
            fi
        else
            info "UFW 防火墙已在运行"
        fi
        info "防火墙配置完成"
    elif command_exists firewall-cmd; then
        info "检测到 firewalld 防火墙"
        info "开放端口：$ASTRBOT_PORT (AstrBot), $NAPCAT_PORT (NapCat)"
        firewall-cmd --permanent --add-port="${ASTRBOT_PORT}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port="${NAPCAT_PORT}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        info "防火墙配置完成"
    else
        warn "未检测到防火墙（ufw/firewalld），跳过防火墙配置"
        tip "如果服务器有云安全组，请手动放行端口：$ASTRBOT_PORT 和 $NAPCAT_PORT"
    fi
}

# 生成 Docker Compose 文件
generate_compose_file() {
    step "生成 docker-compose.yml 配置文件..."
    mkdir -p "$(dirname "$COMPOSE_FILE")"

    cat > "$COMPOSE_FILE" <<EOF
version: "3.8"

services:
  astrbot:
    image: ${ASTRBOT_IMAGE}
    container_name: ${ASTRBOT_CONTAINER_NAME}
    restart: always
    ports:
      - "${ASTRBOT_PORT}:6185"
    volumes:
      - ${ASTRBOT_DATA_DIR}:/AstrBot/data
    networks:
      - astrbot-net

  napcat:
    image: ${NAPCAT_IMAGE}
    container_name: ${NAPCAT_CONTAINER_NAME}
    restart: always
    environment:
      - NAPCAT_GID=0
      - NAPCAT_UID=0
      - ACCOUNT=
    ports:
      - "${NAPCAT_PORT}:6099"
    volumes:
      - ${NAPCAT_DATA_DIR}:/app/napcat/config
    networks:
      - astrbot-net

networks:
  astrbot-net:
    driver: bridge
EOF

    info "docker-compose.yml 已生成：$COMPOSE_FILE"
}

# 通过 Docker Compose 部署
deploy_via_compose() {
    print_separator
    echo -e "${CYAN}[Docker Compose 部署]${NC}"
    print_separator

    # 生成 compose 文件
    generate_compose_file

    # 创建数据目录
    info "创建数据目录..."
    mkdir -p "$ASTRBOT_DATA_DIR"
    mkdir -p "$NAPCAT_DATA_DIR"

    # 拉取镜像
    step "拉取镜像..."
    docker compose -f "$COMPOSE_FILE" pull

    # 启动服务
    step "启动容器..."
    if docker compose -f "$COMPOSE_FILE" up -d; then
        info "Docker Compose 部署成功！"
    else
        error "Docker Compose 部署失败！"
        return 1
    fi

    # 验证容器状态
    local server_ip=$(get_server_ip)
    if docker ps --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "AstrBot 容器运行正常"
        tip "AstrBot：http://${server_ip}:${ASTRBOT_PORT}"
    else
        error "AstrBot 容器未正常运行"
    fi

    if docker ps --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "NapCat 容器运行正常"
        tip "NapCat：http://${server_ip}:${NAPCAT_PORT}"
    else
        error "NapCat 容器未正常运行"
    fi
}

# 通过 Docker Compose 更新
update_via_compose() {
    print_separator
    echo -e "${CYAN}[Docker Compose 更新]${NC}"
    print_separator

    if [ ! -f "$COMPOSE_FILE" ]; then
        warn "未找到 docker-compose.yml 文件，重新生成..."
        generate_compose_file
    fi

    step "拉取最新镜像..."
    docker compose -f "$COMPOSE_FILE" pull

    step "重建容器..."
    docker compose -f "$COMPOSE_FILE" up -d

    info "Docker Compose 服务更新完成！"
}

# 通过 Docker Compose 停止
stop_via_compose() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" stop
        info "Docker Compose 服务已停止"
    else
        warn "未找到 docker-compose.yml 文件"
    fi
}

# 通过 Docker Compose 启动
start_via_compose() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" start
        info "Docker Compose 服务已启动"
    else
        warn "未找到 docker-compose.yml 文件"
    fi
}

# 通过 Docker Compose 重启
restart_via_compose() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" restart
        info "Docker Compose 服务已重启"
    else
        warn "未找到 docker-compose.yml 文件"
    fi
}

# 通过 Docker Compose 卸载
uninstall_via_compose() {
    print_separator
    echo -e "${RED}[Docker Compose 卸载]${NC}"
    print_separator

    warn "此操作将停止并删除所有 Compose 服务容器！"
    warn "数据目录中的数据将被保留。"
    if ! confirm "确认卸载？" "n"; then
        info "取消卸载。"
        return 0
    fi

    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" down --rmi all 2>/dev/null || true
        info "Compose 服务已卸载"
    else
        warn "未找到 docker-compose.yml 文件，手动清理容器..."
        docker stop "$ASTRBOT_CONTAINER_NAME" "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$ASTRBOT_CONTAINER_NAME" "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
        docker rmi "$ASTRBOT_IMAGE" "$NAPCAT_IMAGE" 2>/dev/null || true
    fi
    info "卸载完成（数据目录已保留）"
}

# ============================== 备份与恢复 ==============================

# 备份数据
backup_data() {
    print_separator
    echo -e "${CYAN}[数据备份]${NC}"
    print_separator

    local backup_time=$(date +"%Y%m%d_%H%M%S")
    local backup_path="${BACKUP_DIR}/${backup_time}"

    info "备份时间：$backup_time"
    info "备份目录：$backup_path"

    mkdir -p "$backup_path"

    local backup_ok=true

    # 备份 AstrBot 数据
    if [ -d "$ASTRBOT_DATA_DIR" ] && [ "$(ls -A $ASTRBOT_DATA_DIR 2>/dev/null)" ]; then
        step "备份 AstrBot 数据..."
        if tar czf "${backup_path}/astrbot_data.tar.gz" -C "$(dirname $ASTRBOT_DATA_DIR)" "$(basename $ASTRBOT_DATA_DIR)" 2>/dev/null; then
            local abot_size=$(du -sh "${backup_path}/astrbot_data.tar.gz" 2>/dev/null | awk '{print $1}')
            info "AstrBot 数据备份完成（大小：$abot_size）"
        else
            warn "AstrBot 数据备份失败"
            backup_ok=false
        fi
    else
        warn "AstrBot 数据目录为空或不存在，跳过备份"
    fi

    # 备份 NapCat 数据
    if [ -d "$NAPCAT_DATA_DIR" ] && [ "$(ls -A $NAPCAT_DATA_DIR 2>/dev/null)" ]; then
        step "备份 NapCat 数据..."
        if tar czf "${backup_path}/napcat_data.tar.gz" -C "$(dirname $NAPCAT_DATA_DIR)" "$(basename $NAPCAT_DATA_DIR)" 2>/dev/null; then
            local ncat_size=$(du -sh "${backup_path}/napcat_data.tar.gz" 2>/dev/null | awk '{print $1}')
            info "NapCat 数据备份完成（大小：$ncat_size）"
        else
            warn "NapCat 数据备份失败"
            backup_ok=false
        fi
    else
        warn "NapCat 数据目录为空或不存在，跳过备份"
    fi

    # 备份 compose 文件
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "${backup_path}/docker-compose.yml" 2>/dev/null || true
    fi

    # 创建备份信息文件
    cat > "${backup_path}/backup_info.txt" <<EOF
备份时间: $backup_time
脚本版本: v${VERSION}
AstrBot 数据: ${ASTRBOT_DATA_DIR}
NapCat 数据: ${NAPCAT_DATA_DIR}
备份创建者: AstrBot 一键部署脚本
EOF

    if [ "$backup_ok" = true ]; then
        info "备份完成！备份路径：$backup_path"
        local total_size=$(du -sh "$backup_path" 2>/dev/null | awk '{print $1}')
        tip "备份总大小：$total_size"
    else
        warn "备份完成，但部分数据备份失败，请检查上方日志"
    fi

    # 清理旧备份（保留最近 5 个）
    local backup_count=$(ls -d ${BACKUP_DIR}/*/ 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 5 ]; then
        info "清理旧备份（保留最近 5 个）..."
        ls -dt ${BACKUP_DIR}/*/ 2>/dev/null | tail -n +6 | while read old_backup; do
            rm -rf "$old_backup"
        done
        info "已清理 $((backup_count - 5)) 个旧备份"
    fi
}

# 恢复数据
restore_data() {
    print_separator
    echo -e "${CYAN}[数据恢复]${NC}"
    print_separator

    # 列出可用备份
    local backups=()
    if [ -d "$BACKUP_DIR" ]; then
        while IFS= read -r line; do
            backups+=("$line")
        done < <(ls -dt ${BACKUP_DIR}/*/ 2>/dev/null)
    fi

    if [ ${#backups[@]} -eq 0 ]; then
        warn "未找到任何备份文件"
        tip "备份目录：$BACKUP_DIR"
        return 0
    fi

    info "可用备份列表："
    local i=1
    for backup in "${backups[@]}"; do
        local bname=$(basename "$backup")
        local bsize=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
        echo -e "  ${YELLOW}${i}${NC} - ${bname} （大小：${bsize}）"
        i=$((i + 1))
    done
    echo -e "  ${YELLOW}0${NC} - 返回"

    read -p "请选择要恢复的备份 (0-$((i-1))): " RESTORE_CHOICE

    if [ "$RESTORE_CHOICE" = "0" ] || [ -z "$RESTORE_CHOICE" ]; then
        info "取消恢复"
        return 0
    fi

    if ! [[ "$RESTORE_CHOICE" =~ ^[0-9]+$ ]] || [ "$RESTORE_CHOICE" -lt 1 ] || [ "$RESTORE_CHOICE" -gt ${#backups[@]} ]; then
        warn "无效选择"
        return 0
    fi

    local selected_backup="${backups[$((RESTORE_CHOICE - 1))]}"
    info "选中备份：$(basename "$selected_backup")"

    warn "恢复操作将覆盖当前数据！"
    warn "建议在恢复前先停止相关服务。"
    if ! confirm "确认恢复？" "n"; then
        info "取消恢复"
        return 0
    fi

    # 停止服务
    if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" stop 2>/dev/null || true
    else
        docker stop "$ASTRBOT_CONTAINER_NAME" "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
    fi

    # 恢复 AstrBot 数据
    if [ -f "${selected_backup}/astrbot_data.tar.gz" ]; then
        step "恢复 AstrBot 数据..."
        mkdir -p "$(dirname "$ASTRBOT_DATA_DIR")"
        if tar xzf "${selected_backup}/astrbot_data.tar.gz" -C "$(dirname "$ASTRBOT_DATA_DIR")" 2>/dev/null; then
            info "AstrBot 数据恢复成功"
        else
            error "AstrBot 数据恢复失败"
        fi
    else
        warn "备份中无 AstrBot 数据，跳过"
    fi

    # 恢复 NapCat 数据
    if [ -f "${selected_backup}/napcat_data.tar.gz" ]; then
        step "恢复 NapCat 数据..."
        mkdir -p "$(dirname "$NAPCAT_DATA_DIR")"
        if tar xzf "${selected_backup}/napcat_data.tar.gz" -C "$(dirname "$NAPCAT_DATA_DIR")" 2>/dev/null; then
            info "NapCat 数据恢复成功"
        else
            error "NapCat 数据恢复失败"
        fi
    else
        warn "备份中无 NapCat 数据，跳过"
    fi

    # 恢复 compose 文件
    if [ -f "${selected_backup}/docker-compose.yml" ]; then
        cp "${selected_backup}/docker-compose.yml" "$COMPOSE_FILE" 2>/dev/null || true
    fi

    # 重启服务
    step "重启服务..."
    if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" start 2>/dev/null || true
    else
        docker start "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
        docker start "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
    fi

    info "数据恢复完成！"
}

# ============================== 系统清理 ==============================

# 清理 Docker 无用资源
docker_cleanup() {
    print_separator
    echo -e "${CYAN}[Docker 资源清理]${NC}"
    print_separator

    info "清理前磁盘使用："
    docker system df 2>/dev/null || true

    if confirm "执行 docker system prune 清理无用资源？" "n"; then
        step "清理无用镜像、容器、网络..."
        docker system prune -a -f --volumes 2>/dev/null | grep -E "Total|deleted" || true
        info "清理完成"
        echo ""
        info "清理后磁盘使用："
        docker system df 2>/dev/null || true
    else
        info "跳过清理"
    fi
}

# ============================== AstrBot 部署 ==============================

# 部署 AstrBot
deploy_astrbot() {
    print_separator
    echo -e "${CYAN}[AstrBot 部署]${NC}"
    print_separator

    # 检查是否已存在容器
    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        warn "检测到已存在 AstrBot 容器（$ASTRBOT_CONTAINER_NAME）"
        echo -e "  ${YELLOW}1${NC} - 重新部署（删除旧容器并重新创建）"
        echo -e "  ${YELLOW}2${NC} - 更新镜像（拉取最新镜像并重启容器）"
        echo -e "  ${YELLOW}3${NC} - 跳过"
        read -p "请选择操作 (1/2/3): " CHOICE

        case "$CHOICE" in
            1)
                info "停止并删除旧容器..."
                docker stop "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
                docker rm "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
                ;;
            2)
                update_astrbot
                return 0
                ;;
            3)
                info "跳过 AstrBot 部署。"
                return 0
                ;;
            *)
                error "无效选择，跳过 AstrBot 部署。"
                return 0
                ;;
        esac
    fi

    # 创建数据目录
    info "创建数据目录：$ASTRBOT_DATA_DIR"
    mkdir -p "$ASTRBOT_DATA_DIR"

    # 拉取镜像
    info "拉取 AstrBot 镜像（$ASTRBOT_IMAGE）..."
    docker pull "$ASTRBOT_IMAGE"

    # 创建并启动容器
    info "创建并启动 AstrBot 容器..."
    docker run -d \
        --name "$ASTRBOT_CONTAINER_NAME" \
        --restart=always \
        -p "${ASTRBOT_PORT}:6185" \
        -v "${ASTRBOT_DATA_DIR}:/AstrBot/data" \
        "$ASTRBOT_IMAGE"

    # 验证容器状态
    if docker ps --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "AstrBot 部署成功！"
        tip "访问地址：http://$(hostname -I 2>/dev/null | awk '{print $1}'):${ASTRBOT_PORT}"
        tip "数据目录：$ASTRBOT_DATA_DIR"
    else
        error "AstrBot 容器启动失败！请查看日志：docker logs $ASTRBOT_CONTAINER_NAME"
    fi
}

# 更新 AstrBot
update_astrbot() {
    info "更新 AstrBot..."

    # 拉取最新镜像
    info "拉取最新 AstrBot 镜像..."
    docker pull "$ASTRBOT_IMAGE"

    # 停止并删除旧容器
    info "停止并删除旧容器..."
    docker stop "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true

    # 重新创建容器
    info "重新创建 AstrBot 容器..."
    docker run -d \
        --name "$ASTRBOT_CONTAINER_NAME" \
        --restart=always \
        -p "${ASTRBOT_PORT}:6185" \
        -v "${ASTRBOT_DATA_DIR}:/AstrBot/data" \
        "$ASTRBOT_IMAGE"

    if docker ps --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "AstrBot 更新成功！"
    else
        error "AstrBot 更新后容器启动失败！请查看日志：docker logs $ASTRBOT_CONTAINER_NAME"
    fi
}

# ============================== NapCat 部署 ==============================

# 部署 NapCat
deploy_napcat() {
    print_separator
    echo -e "${CYAN}[NapCat 部署]${NC}"
    print_separator

    # 检查是否已存在容器
    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        warn "检测到已存在 NapCat 容器（$NAPCAT_CONTAINER_NAME）"
        echo -e "  ${YELLOW}1${NC} - 重新部署（删除旧容器并重新创建）"
        echo -e "  ${YELLOW}2${NC} - 更新镜像（拉取最新镜像并重启容器）"
        echo -e "  ${YELLOW}3${NC} - 跳过"
        read -p "请选择操作 (1/2/3): " CHOICE

        case "$CHOICE" in
            1)
                info "停止并删除旧容器..."
                docker stop "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
                docker rm "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
                ;;
            2)
                update_napcat
                return 0
                ;;
            3)
                info "跳过 NapCat 部署。"
                return 0
                ;;
            *)
                error "无效选择，跳过 NapCat 部署。"
                return 0
                ;;
        esac
    fi

    # 创建数据目录
    info "创建数据目录：$NAPCAT_DATA_DIR"
    mkdir -p "$NAPCAT_DATA_DIR"

    # 拉取镜像
    info "拉取 NapCat 镜像（$NAPCAT_IMAGE）..."
    docker pull "$NAPCAT_IMAGE"

    # 创建并启动容器
    info "创建并启动 NapCat 容器..."
    docker run -d \
        --name "$NAPCAT_CONTAINER_NAME" \
        --restart=always \
        -e NAPCAT_GID=0 \
        -e NAPCAT_UID=0 \
        -e ACCOUNT="" \
        -p "${NAPCAT_PORT}:6099" \
        -v "${NAPCAT_DATA_DIR}:/app/napcat/config" \
        "$NAPCAT_IMAGE"

    # 验证容器状态
    if docker ps --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "NapCat 部署成功！"
        tip "WebUI 地址：http://$(hostname -I 2>/dev/null | awk '{print $1}'):${NAPCAT_PORT}"
        tip "数据目录：$NAPCAT_DATA_DIR"
    else
        error "NapCat 容器启动失败！请查看日志：docker logs $NAPCAT_CONTAINER_NAME"
    fi
}

# 更新 NapCat
update_napcat() {
    info "更新 NapCat..."

    # 拉取最新镜像
    info "拉取最新 NapCat 镜像..."
    docker pull "$NAPCAT_IMAGE"

    # 停止并删除旧容器
    info "停止并删除旧容器..."
    docker stop "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true

    # 重新创建容器
    info "重新创建 NapCat 容器..."
    docker run -d \
        --name "$NAPCAT_CONTAINER_NAME" \
        --restart=always \
        -e NAPCAT_GID=0 \
        -e NAPCAT_UID=0 \
        -e ACCOUNT="" \
        -p "${NAPCAT_PORT}:6099" \
        -v "${NAPCAT_DATA_DIR}:/app/napcat/config" \
        "$NAPCAT_IMAGE"

    if docker ps --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "NapCat 更新成功！"
    else
        error "NapCat 更新后容器启动失败！请查看日志：docker logs $NAPCAT_CONTAINER_NAME"
    fi
}

# ============================== 管理功能 ==============================

# 查看容器状态
show_status() {
    print_separator
    echo -e "${CYAN}[容器状态]${NC}"
    print_separator

    echo ""
    echo -e "${GREEN}AstrBot 容器：${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        docker ps -a --filter "name=^${ASTRBOT_CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        warn "AstrBot 容器未部署"
    fi

    echo ""
    echo -e "${GREEN}NapCat 容器：${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        docker ps -a --filter "name=^${NAPCAT_CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        warn "NapCat 容器未部署"
    fi
    echo ""
}

# 启动服务
start_services() {
    print_separator
    echo -e "${CYAN}[启动服务]${NC}"
    print_separator

    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "启动 AstrBot..."
        docker start "$ASTRBOT_CONTAINER_NAME"
        info "AstrBot 已启动"
    else
        warn "AstrBot 容器不存在，请先部署"
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "启动 NapCat..."
        docker start "$NAPCAT_CONTAINER_NAME"
        info "NapCat 已启动"
    else
        warn "NapCat 容器不存在，请先部署"
    fi
}

# 停止服务
stop_services() {
    print_separator
    echo -e "${CYAN}[停止服务]${NC}"
    print_separator

    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "停止 AstrBot..."
        docker stop "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
        info "AstrBot 已停止"
    else
        warn "AstrBot 容器不存在"
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "停止 NapCat..."
        docker stop "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
        info "NapCat 已停止"
    else
        warn "NapCat 容器不存在"
    fi
}

# 重启服务
restart_services() {
    print_separator
    echo -e "${CYAN}[重启服务]${NC}"
    print_separator

    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        info "重启 AstrBot..."
        docker restart "$ASTRBOT_CONTAINER_NAME"
        info "AstrBot 已重启"
    else
        warn "AstrBot 容器不存在，请先部署"
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        info "重启 NapCat..."
        docker restart "$NAPCAT_CONTAINER_NAME"
        info "NapCat 已重启"
    else
        warn "NapCat 容器不存在，请先部署"
    fi
}

# 查看日志
show_logs() {
    print_separator
    echo -e "${CYAN}[查看日志]${NC}"
    print_separator

    echo -e "  ${YELLOW}1${NC} - 查看 AstrBot 日志"
    echo -e "  ${YELLOW}2${NC} - 查看 NapCat 日志"
    echo -e "  ${YELLOW}3${NC} - 返回主菜单"
    read -p "请选择 (1/2/3): " LOG_CHOICE

    case "$LOG_CHOICE" in
        1)
            if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
                info "AstrBot 日志（Ctrl+C 退出）："
                docker logs -f --tail 100 "$ASTRBOT_CONTAINER_NAME"
            else
                warn "AstrBot 容器不存在"
            fi
            ;;
        2)
            if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
                info "NapCat 日志（Ctrl+C 退出）："
                docker logs -f --tail 100 "$NAPCAT_CONTAINER_NAME"
            else
                warn "NapCat 容器不存在"
            fi
            ;;
        3)
            return 0
            ;;
        *)
            warn "无效选择"
            ;;
    esac
}

# 卸载服务
uninstall_services() {
    print_separator
    echo -e "${RED}[卸载服务]${NC}"
    print_separator

    warn "此操作将删除 AstrBot 和 NapCat 容器！"
    warn "数据目录中的数据将被保留（如需彻底删除，请手动清理对应目录）。"
    echo ""
    echo -e "  ${YELLOW}1${NC} - 卸载 AstrBot"
    echo -e "  ${YELLOW}2${NC} - 卸载 NapCat"
    echo -e "  ${YELLOW}3${NC} - 全部卸载"
    echo -e "  ${YELLOW}4${NC} - 返回"
    read -p "请选择 (1/2/3/4): " UNINSTALL_CHOICE

    case "$UNINSTALL_CHOICE" in
        1)
            info "卸载 AstrBot..."
            docker stop "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
            docker rm "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
            docker rmi "$ASTRBOT_IMAGE" 2>/dev/null || true
            info "AstrBot 已卸载（数据目录 $ASTRBOT_DATA_DIR 已保留）"
            ;;
        2)
            info "卸载 NapCat..."
            docker stop "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
            docker rm "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
            docker rmi "$NAPCAT_IMAGE" 2>/dev/null || true
            info "NapCat 已卸载（数据目录 $NAPCAT_DATA_DIR 已保留）"
            ;;
        3)
            info "全部卸载..."
            # AstrBot
            docker stop "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
            docker rm "$ASTRBOT_CONTAINER_NAME" 2>/dev/null || true
            docker rmi "$ASTRBOT_IMAGE" 2>/dev/null || true
            # NapCat
            docker stop "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
            docker rm "$NAPCAT_CONTAINER_NAME" 2>/dev/null || true
            docker rmi "$NAPCAT_IMAGE" 2>/dev/null || true
            info "AstrBot 和 NapCat 已全部卸载（数据目录已保留）"
            ;;
        4)
            return 0
            ;;
        *)
            warn "无效选择"
            ;;
    esac
}

# 更新所有服务
update_all_services() {
    print_separator
    echo -e "${CYAN}[更新所有服务]${NC}"
    print_separator

    if docker ps -a --format '{{.Names}}' | grep -q "^${ASTRBOT_CONTAINER_NAME}$"; then
        update_astrbot
    else
        warn "AstrBot 容器不存在，跳过更新"
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${NAPCAT_CONTAINER_NAME}$"; then
        update_napcat
    else
        warn "NapCat 容器不存在，跳过更新"
    fi
}

# ============================== 主菜单 ==============================

main_menu() {
    while true; do
        print_separator
        echo -e "${GREEN}  AstrBot 一键部署脚本 v${VERSION} — 主菜单${NC}"
        print_separator
        echo -e "  ${CYAN}—— 部署 ——${NC}"
        echo -e "  ${YELLOW}1${NC}  - 一键部署（Docker + 镜像加速 + AstrBot + NapCat + 防火墙）"
        echo -e "  ${YELLOW}2${NC}  - 安装/更新 Docker"
        echo -e "  ${YELLOW}3${NC}  - 配置 Docker 镜像加速"
        echo -e "  ${YELLOW}4${NC}  - 部署 AstrBot"
        echo -e "  ${YELLOW}5${NC}  - 部署 NapCat"
        echo -e "  ${YELLOW}6${NC}  - Docker Compose 部署（生成 compose 文件并启动）"
        echo -e "  ${CYAN}—— 管理 ——${NC}"
        echo -e "  ${YELLOW}7${NC}  - 更新所有服务"
        echo -e "  ${YELLOW}8${NC}  - 查看容器状态"
        echo -e "  ${YELLOW}9${NC}  - 启动服务"
        echo -e "  ${YELLOW}10${NC} - 停止服务"
        echo -e "  ${YELLOW}11${NC} - 重启服务"
        echo -e "  ${YELLOW}12${NC} - 查看日志"
        echo -e "  ${YELLOW}13${NC} - 卸载服务"
        echo -e "  ${CYAN}—— 运维 ——${NC}"
        echo -e "  ${YELLOW}14${NC} - 备份数据"
        echo -e "  ${YELLOW}15${NC} - 恢复数据"
        echo -e "  ${YELLOW}16${NC} - 配置防火墙"
        echo -e "  ${YELLOW}17${NC} - Docker 资源清理"
        echo -e "  ${YELLOW}18${NC} - 检查端口占用"
        echo -e "  ${CYAN}—— 其他 ——${NC}"
        echo -e "  ${YELLOW}19${NC} - 更新脚本（自更新）"
        echo -e "  ${YELLOW}0${NC}  - 退出"
        print_separator
        read -p "  请输入序号 (0-19): " CHOICE

        case "$CHOICE" in
            1)
                # 一键部署
                check_network
                check_ports
                install_docker
                configure_docker_mirror
                configure_firewall
                deploy_astrbot
                deploy_napcat
                show_status
                print_separator
                info "一键部署完成！"
                local server_ip=$(get_server_ip)
                tip "AstrBot：http://${server_ip}:${ASTRBOT_PORT}"
                tip "NapCat：http://${server_ip}:${NAPCAT_PORT}"
                tip "数据目录：$ASTRBOT_DATA_DIR, $NAPCAT_DATA_DIR"
                print_separator
                ;;
            2)
                install_docker
                ;;
            3)
                configure_docker_mirror
                ;;
            4)
                deploy_astrbot
                ;;
            5)
                deploy_napcat
                ;;
            6)
                deploy_via_compose
                ;;
            7)
                if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                    update_via_compose
                else
                    update_all_services
                fi
                ;;
            8)
                show_status
                ;;
            9)
                if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                    start_via_compose
                else
                    start_services
                fi
                ;;
            10)
                if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                    stop_via_compose
                else
                    stop_services
                fi
                ;;
            11)
                if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                    restart_via_compose
                else
                    restart_services
                fi
                ;;
            12)
                show_logs
                ;;
            13)
                if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                    uninstall_via_compose
                else
                    uninstall_services
                fi
                ;;
            14)
                backup_data
                ;;
            15)
                restore_data
                ;;
            16)
                configure_firewall
                ;;
            17)
                docker_cleanup
                ;;
            18)
                check_ports
                ;;
            19)
                self_update
                ;;
            0)
                print_separator
                info "感谢使用 AstrBot 一键部署脚本！"
                if [ $ERROR_COUNT -gt 0 ]; then
                    warn "本次运行共发生 $ERROR_COUNT 个错误"
                fi
                echo -e "  作者：${AUTHOR}"
                echo -e "  官网：https://www.asoe.cn"
                echo -e "  文档：https://docs.asoe.cn"
                echo -e "  GitHub：https://github.com/techjiang/"
                echo -e "  哔哩哔哩：https://space.bilibili.com/1768832152"
                echo -e "  玲珑：https://forums.asoe.cn/"
                echo -e "  QQ群：291974598 | 474819022 | 631167288"
                print_separator
                exit 0
                ;;
            *)
                warn "无效选择，请重新输入"
                ;;
        esac

        echo ""
        read -p "按回车键返回主菜单..."
    done
}

# ============================== 自更新 ==============================

# 脚本自更新
self_update() {
    print_separator
    echo -e "${CYAN}[脚本自更新]${NC}"
    print_separator

    local script_path=$(readlink -f "$0" 2>/dev/null || echo "$0")
    local tmp_path="/tmp/astrbot-install-new.sh"

    info "当前版本：v${VERSION}"
    info "正在从远程获取最新版本..."

    if ! wget -q -O "$tmp_path" "$SCRIPT_URL" 2>/dev/null; then
        error "下载最新脚本失败！请检查网络连接。"
        rm -f "$tmp_path" 2>/dev/null
        return 1
    fi

    # 检查下载的文件是否为有效脚本
    if ! head -n 1 "$tmp_path" | grep -q "bash"; then
        error "下载的文件不是有效的脚本！"
        rm -f "$tmp_path" 2>/dev/null
        return 1
    fi

    # 提取远程版本号
    local remote_version=$(grep 'VERSION=' "$tmp_path" 2>/dev/null | head -1 | awk -F'"' '{print $2}')
    if [ -z "$remote_version" ]; then
        remote_version="未知"
    fi

    info "远程版本：v${remote_version}"

    if [ "$remote_version" = "$VERSION" ]; then
        info "已是最新版本，无需更新。"
        rm -f "$tmp_path" 2>/dev/null
        return 0
    fi

    if confirm "发现新版本 v${remote_version}，是否更新？" "y"; then
        chmod +x "$tmp_path"
        if cp "$tmp_path" "$script_path"; then
            info "脚本已更新到 v${remote_version}！"
            info "请重新运行脚本以加载新版本。"
            rm -f "$tmp_path" 2>/dev/null
            exit 0
        else
            error "更新失败！请检查文件权限。"
            rm -f "$tmp_path" 2>/dev/null
            return 1
        fi
    else
        info "取消更新"
        rm -f "$tmp_path" 2>/dev/null
    fi
}

# ============================== 命令行参数解析 ==============================

# 显示帮助信息
show_help() {
    cat <<HELP
AstrBot 一键部署脚本 v${VERSION}

用法: $0 [选项] [命令]

命令:
  install          一键安装（Docker + 镜像加速 + AstrBot + NapCat + 防火墙）
  update           更新所有服务
  start            启动服务
  stop             停止服务
  restart          重启服务
  status           查看容器状态
  logs             查看日志（需要 -t astrbot|napcat）
  uninstall        卸载服务
  backup           备份数据
  restore          恢复数据
  firewall         配置防火墙
  cleanup          清理 Docker 无用资源
  self-update       更新脚本自身
  help             显示此帮助信息

选项:
  -y, --yes             非交互模式（自动确认所有提示）
  -m, --method METHOD   部署方式：docker 或 compose（默认: docker）
  -v, --version         显示版本号
  -h, --help            显示帮助信息

示例:
  # 一键安装（非交互模式）
  $0 -y install

  # 使用 Docker Compose 方式部署
  $0 -m compose install

  # 启动所有服务
  $0 start

  # 备份数据
  $0 backup

HELP
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                NON_INTERACTIVE=true
                shift
                ;;
            -m|--method)
                DEPLOY_METHOD="$2"
                shift 2
                ;;
            docker|compose)
                DEPLOY_METHOD="$1"
                shift
                ;;
            -v|--version)
                echo "AstrBot 一键部署脚本 v${VERSION}"
                echo "作者：${AUTHOR}"
                exit 0
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            install)
                RUN_COMMAND="install"
                shift
                ;;
            update)
                RUN_COMMAND="update"
                shift
                ;;
            start)
                RUN_COMMAND="start"
                shift
                ;;
            stop)
                RUN_COMMAND="stop"
                shift
                ;;
            restart)
                RUN_COMMAND="restart"
                shift
                ;;
            status)
                RUN_COMMAND="status"
                shift
                ;;
            logs)
                RUN_COMMAND="logs"
                shift
                ;;
            uninstall)
                RUN_COMMAND="uninstall"
                shift
                ;;
            backup)
                RUN_COMMAND="backup"
                shift
                ;;
            restore)
                RUN_COMMAND="restore"
                shift
                ;;
            firewall)
                RUN_COMMAND="firewall"
                shift
                ;;
            cleanup)
                RUN_COMMAND="cleanup"
                shift
                ;;
            self-update)
                RUN_COMMAND="self-update"
                shift
                ;;
            *)
                warn "未知参数：$1（使用 -h 查看帮助）"
                shift
                ;;
        esac
    done
}

# 执行命令行命令
run_command() {
    local cmd="$1"
    case "$cmd" in
        install)
            check_network
            check_ports
            install_docker
            configure_docker_mirror
            configure_firewall
            if [ "$DEPLOY_METHOD" = "compose" ]; then
                deploy_via_compose
            else
                deploy_astrbot
                deploy_napcat
            fi
            show_status
            local server_ip=$(get_server_ip)
            print_separator
            info "一键部署完成！"
            tip "AstrBot：http://${server_ip}:${ASTRBOT_PORT}"
            tip "NapCat：http://${server_ip}:${NAPCAT_PORT}"
            print_separator
            ;;
        update)
            if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                update_via_compose
            else
                update_all_services
            fi
            ;;
        start)
            if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                start_via_compose
            else
                start_services
            fi
            ;;
        stop)
            if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                stop_via_compose
            else
                stop_services
            fi
            ;;
        restart)
            if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                restart_via_compose
            else
                restart_services
            fi
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        uninstall)
            if [ "$DEPLOY_METHOD" = "compose" ] && [ -f "$COMPOSE_FILE" ]; then
                uninstall_via_compose
            else
                uninstall_services
            fi
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data
            ;;
        firewall)
            configure_firewall
            ;;
        cleanup)
            docker_cleanup
            ;;
        self-update)
            self_update
            ;;
        *)
            return 0
            ;;
    esac
}

# ============================== 入口 ==============================

main() {
    check_root
    print_banner

    # 解析命令行参数
    local run_cmd=""
    if [ $# -gt 0 ]; then
        parse_args "$@"
        run_cmd="${RUN_COMMAND:-}"
    fi

    check_system

    # 如果有命令行命令，执行后退出
    if [ -n "$run_cmd" ]; then
        run_command "$run_cmd"
        exit 0
    fi

    # 否则进入交互菜单
    main_menu
}

main "$@"
