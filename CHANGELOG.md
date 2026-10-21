# 更新日志

## [v2.1.0] - 2026-10-21

### Bug 修复

- **修复非交互模式兼容性** — `deploy_astrbot`、`deploy_napcat`、`show_logs`、`uninstall_services` 中的 `read -p` 交互提示在非交互模式下会卡住，现在非交互模式下自动选择默认操作
- **修复 NapCat QQ 数据卷缺失** — NapCat Docker 容器缺少 `/app/.config/QQ` 挂载，导致 QQ 登录数据无法持久化，已补充挂载 `${NAPCAT_DATA_DIR}/QQ:/app/.config/QQ`
- **修复端口检测精确度** — `check_port` 函数原先使用简单的 `grep` 匹配，可能误匹配（如端口 618 误匹配 6185），改用 `awk` + `grep -E` 精确匹配端口边界
- **修复镜像拉取失败未处理** — `deploy_astrbot`/`deploy_napcat` 中 `docker pull` 失败后继续执行 `docker run`，现在拉取失败时提前返回错误

### 增强改进

- **统一使用 `get_server_ip()`** — 所有部署成功提示统一使用 `get_server_ip()` 函数获取服务器 IP（优先公网 IP），替代原先直接调用 `hostname -I`
- **新增 `get_port_process()` 函数** — 封装端口占用进程信息获取逻辑，`check_ports` 中使用该函数
- **部署后容器健康检查** — `deploy_astrbot`/`deploy_napcat` 部署后使用 `wait_container_healthy()` 等待容器启动，避免容器刚创建还未运行就判定为成功
- **Compose 文件同步** — `docker-compose.yml` 中 NapCat 服务同步补充 QQ 数据卷挂载
- **`error()` 函数不再使用 `exit 1`** — 部署函数中的错误改用 `return 1`，避免在非关键路径上意外退出脚本

---

## [v2.0.0] - 2026-10-21

### 新增功能

- **Docker Compose 部署方式** — 支持通过 `docker compose` 部署，自动生成 `docker-compose.yml` 配置文件，包含网络配置
- **命令行参数解析** — 支持 `install`、`update`、`start`、`stop`、`restart`、`status`、`logs`、`uninstall`、`backup`、`restore`、`firewall`、`cleanup`、`self-update` 等命令
- **非交互模式** — 通过 `-y/--yes` 参数跳过所有确认提示，适合自动化部署脚本
- **数据备份与恢复** — 一键备份 AstrBot 和 NapCat 数据到 tar.gz 压缩包，支持从备份列表选择恢复，自动保留最近 5 个备份
- **防火墙配置** — 自动检测 UFW/firewalld 并开放所需端口（6185、6099），支持 UFW 启用提示
- **系统环境检查** — 新增 CPU 架构、内存大小、磁盘空间检查，不足时给出警告
- **网络连通性检查** — 部署前检查 gitee.com、download.docker.com、hub.docker.com 的可达性
- **端口占用检查** — 部署前检查 6185 和 6099 端口是否被占用，显示占用进程
- **Docker 资源清理** — 一键执行 `docker system prune` 清理无用镜像、容器、网络和卷
- **脚本自更新** — 检测远程最新版本，支持一键更新脚本自身
- **错误统计** — 运行结束时显示错误计数

### 增强改进

- Docker 安装增加阿里云镜像源作为备用，官方源失败时自动切换
- 镜像加速源从 5 个增加到 7 个（新增腾讯云、网易源）
- daemon.json 新增 `default-shm-size: 128M` 配置
- Docker 安装后增加守护进程运行状态验证
- 使用 `confirm()` 函数统一确认提示，支持非交互模式
- 横幅显示部署方式和运行模式信息
- `get_server_ip()` 函数优先获取公网 IP，内网 IP 作为后备
- 菜单分组显示（部署、管理、运维、其他），更清晰直观
- 交互提示使用 `[Y/n]` 和 `[y/N]` 格式，支持回车默认值

### 代码质量

- 移除 `set -e`，改为手动错误处理，提供更好的交互体验
- 新增 `step()`、`command_exists()`、`get_server_ip()`、`check_network()`、`check_port()` 等工具函数
- 横幅 ASCII Art 使用 heredoc，更易维护

---

## [v1.0.0] - 2026-10-21

### 初始版本

- 一键安装 Docker CE 及相关组件（docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin）
- Docker 镜像加速配置（5 个国内加速源）
- 部署 AstrBot 容器（snowykami/astrbot:latest，端口 6185）
- 部署 NapCat 容器（mlikiowa/napcat-docker:latest，端口 6099）
- 容器自启动策略（--restart=always）
- 数据卷持久化存储
- 支持 Ubuntu 20.04+ / Debian 11+ 系统
- 选择性安装（单独部署 AstrBot 或 NapCat）
- 容器更新功能（拉取最新镜像并重建）
- 完整管理功能：启动、停止、重启、查看状态、查看日志、卸载
- 交互式菜单，支持 12 个操作选项
