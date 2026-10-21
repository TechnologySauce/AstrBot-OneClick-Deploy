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

set -e

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
VERSION="1.0.0"

# 容器与数据卷配置
ASTRBOT_CONTAINER_NAME="astrbot"
NAPCAT_CONTAINER_NAME="napcat"
ASTRBOT_IMAGE="snowykami/astrbot:latest"
NAPCAT_IMAGE="mlikiowa/napcat-docker:latest"

# 数据卷路径（宿主机）
ASTRBOT_DATA_DIR="/home/astrbot/data"
NAPCAT_DATA_DIR="/home/napcat/data"

# 端口配置
ASTRBOT_PORT="6185"
NAPCAT_PORT="6099"

# 脚本下载地址
SCRIPT_URL="https://gitee.com/einternet/AstrBot-OneClick-Deploy/raw/main/astrbot-install.sh"

# 镜像加速器配置文件
DAEMON_JSON="/etc/docker/daemon.json"

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
}

# 打印提示
tip() {
    echo -e "${CYAN}[TIP]${NC} $1"
}

# 分隔线
print_separator() {
    echo -e "${BLUE}================================================================${NC}"
}

# 打印横幅
print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "  █████╗ ██╗   ██╗██████╗  ██████╗ ███████╗██╗   ██╗    ██████╗██╗  ██╗    ██████╗ "
    echo "  ██╔══██╗╚██╗ ██╔╝██╔══██╗██╔═══██╗██╔════╝██║   ██║   ██╔════╝██║  ██║   ██╔═══██╗"
    echo "  ███████║ ╚████╔╝ ██████╔╝██║   ██║███████╗██║   ██║   ██║     ███████║   ██║   ██║"
    echo "  ██╔══██║  ╚██╔╝  ██╔══██╗██║   ██║╚════██║██║   ██║   ██║     ██╔══██║   ██║   ██║"
    echo "  ██║  ██║   ██║   ██████╔╝╚██████╔╝███████║╚██████╔╝   ╚██████╗██║  ██║   ╚██████╔╝"
    echo "  ╚═╝  ╚═╝   ╚═╝   ╚═════╝  ╚═════╝ ╚══════╝ ╚═════╝     ╚═════╝╚═╝  ╚═╝    ╚═════╝ "
    echo -e "${NC}"
    print_separator
    echo -e "  ${GREEN}AstrBot 一键部署脚本 v${VERSION}${NC}"
    echo -e "  作者：${AUTHOR}"
    echo -e "  官网：https://www.asoe.cn"
    echo -e "  文档：https://docs.asoe.cn"
    echo -e "  项目：https://gitee.com/einternet/AstrBot-OneClick-Deploy"
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
            read -p "是否继续？(y/n): " CONTINUE
            case "$CONTINUE" in
                [yY]|[yY][eE][sS])
                    info "继续执行..."
                    ;;
                *)
                    info "用户取消，退出。"
                    exit 0
                    ;;
            esac
            ;;
    esac
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
        read -p "是否重新安装/更新 Docker？(y/n): " REINSTALL
        case "$REINSTALL" in
            [yY]|[yY][eE][sS])
                info "开始更新 Docker..."
                ;;
            *)
                info "跳过 Docker 安装。"
                return 0
                ;;
        esac
    else
        info "未检测到 Docker，开始安装..."
    fi

    # 更新 apt 并安装依赖
    info "更新系统包管理器并安装依赖..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        wget \
        software-properties-common \
        >/dev/null 2>&1

    # 安装 Docker GPG key
    info "添加 Docker 官方 GPG 密钥..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 添加 Docker apt 源
    info "添加 Docker apt 源..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    # 安装 Docker
    info "安装 Docker CE..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        >/dev/null 2>&1

    # 启动 Docker 并设置开机自启
    info "启动 Docker 服务..."
    systemctl start docker
    systemctl enable docker

    # 验证安装
    if check_docker; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        info "Docker 安装成功！版本：$DOCKER_VERSION"
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
        read -p "是否覆盖更新镜像加速配置？(y/n): " OVERWRITE
        case "$OVERWRITE" in
            [yY]|[yY][eE][sS])
                info "开始更新镜像加速配置..."
                ;;
            *)
                info "跳过镜像加速配置。"
                return 0
                ;;
        esac
    else
        info "未检测到镜像加速配置，开始配置..."
    fi

    # 写入镜像加速配置
    info "写入镜像加速源配置..."
    mkdir -p $(dirname "$DAEMON_JSON")
    cat > "$DAEMON_JSON" <<'EOF'
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.xuanyuan.me",
        "https://docker.m.daocloud.io",
        "https://dockerproxy.com",
        "https://docker.nju.edu.cn"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF

    # 重启 Docker 使配置生效
    info "重启 Docker 使配置生效..."
    systemctl daemon-reload
    systemctl restart docker

    info "镜像加速配置完成！"
    tip "已配置以下加速源："
    echo -e "    - https://docker.1ms.run"
    echo -e "    - https://docker.xuanyuan.me"
    echo -e "    - https://docker.m.daocloud.io"
    echo -e "    - https://dockerproxy.com"
    echo -e "    - https://docker.nju.edu.cn"
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
        echo -e "${GREEN}  请选择操作：${NC}"
        print_separator
        echo -e "  ${YELLOW}1${NC}  - 一键部署（Docker + 镜像加速 + AstrBot + NapCat）"
        echo -e "  ${YELLOW}2${NC}  - 安装/更新 Docker"
        echo -e "  ${YELLOW}3${NC}  - 配置 Docker 镜像加速"
        echo -e "  ${YELLOW}4${NC}  - 部署 AstrBot"
        echo -e "  ${YELLOW}5${NC}  - 部署 NapCat"
        echo -e "  ${YELLOW}6${NC}  - 更新所有服务"
        echo -e "  ${YELLOW}7${NC}  - 查看容器状态"
        echo -e "  ${YELLOW}8${NC}  - 启动服务"
        echo -e "  ${YELLOW}9${NC}  - 停止服务"
        echo -e "  ${YELLOW}10${NC} - 重启服务"
        echo -e "  ${YELLOW}11${NC} - 查看日志"
        echo -e "  ${YELLOW}12${NC} - 卸载服务"
        echo -e "  ${YELLOW}0${NC}  - 退出"
        print_separator
        read -p "  请输入序号 (0-12): " CHOICE

        case "$CHOICE" in
            1)
                # 一键部署
                install_docker
                configure_docker_mirror
                deploy_astrbot
                deploy_napcat
                show_status
                print_separator
                info "一键部署完成！"
                tip "AstrBot：http://$(hostname -I 2>/dev/null | awk '{print $1}'):${ASTRBOT_PORT}"
                tip "NapCat：http://$(hostname -I 2>/dev/null | awk '{print $1}'):${NAPCAT_PORT}"
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
                update_all_services
                ;;
            7)
                show_status
                ;;
            8)
                start_services
                ;;
            9)
                stop_services
                ;;
            10)
                restart_services
                ;;
            11)
                show_logs
                ;;
            12)
                uninstall_services
                ;;
            0)
                print_separator
                info "感谢使用 AstrBot 一键部署脚本！"
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

# ============================== 入口 ==============================

main() {
    check_root
    print_banner
    check_system
    main_menu
}

main
