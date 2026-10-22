# AstrBot 一键部署脚本

> 一键安装 Docker 并部署 AstrBot / Napcat 服务，支持 Docker Compose、数据备份恢复、防火墙配置等。

## 功能特点

### 核心功能
1. **自动安装 Docker** — 自动检测系统环境，安装 Docker CE 及相关组件，支持阿里云镜像源兜底
2. **Docker 镜像加速** — 自动配置 7 个国内镜像加速源，提升拉取速度
3. **容器自启动策略** — 所有容器均设置 `--restart=always`，开机即启动
4. **数据卷持久化存储** — 数据独立于容器，升级不丢失配置
5. **兼容性** — 支持 Ubuntu 20.04+ / Debian 11+ 系统
6. **选择性安装** — 支持按需选择部署 AstrBot 或 NapCat
7. **容器更新** — 一键拉取最新镜像并重建容器

### v2.0 新增功能
8. **Docker Compose 部署** — 支持 `docker compose` 方式部署，自动生成 `docker-compose.yml`
9. **命令行参数** — 支持非交互模式，一条命令完成部署，适合自动化脚本
10. **数据备份与恢复** — 一键备份/恢复 AstrBot 和 NapCat 数据，自动清理旧备份
11. **防火墙配置** — 自动检测并配置 UFW/firewalld，开放所需端口
12. **系统环境检查** — 检查 CPU 架构、内存、磁盘空间、网络连通性、端口占用
13. **Docker 资源清理** — 一键清理无用镜像、容器、网络和卷
14. **脚本自更新** — 检测并更新到最新版本
15. **错误统计** — 运行结束显示错误计数

### v2.1 新增功能
16. **系统信息查看** — 一键查看操作系统、CPU、内存、磁盘、Docker 运行状态、网络信息
17. **服务健康检查** — 检查容器运行状态和 HTTP 可达性，快速诊断服务异常

## 使用方法

### 交互模式

下载并执行脚本：

```bash
wget -O astrbot-install.sh https://gitee.com/einternet/AstrBot-OneClick-Deploy/raw/main/astrbot-install.sh && chmod +x astrbot-install.sh && ./astrbot-install.sh
```

### 非交互模式（命令行参数）

```bash
# 一键安装（非交互模式，自动确认所有提示）
./astrbot-install.sh -y install

# 使用 Docker Compose 方式部署
./astrbot-install.sh -m compose install
# 或者
./astrbot-install.sh compose -y install

# 更新所有服务
./astrbot-install.sh update

# 启动 / 停止 / 重启服务
./astrbot-install.sh start
./astrbot-install.sh stop
./astrbot-install.sh restart

# 查看容器状态
./astrbot-install.sh status

# 备份 / 恢复数据
./astrbot-install.sh backup
./astrbot-install.sh restore

# 配置防火墙
./astrbot-install.sh firewall

# 清理 Docker 无用资源
./astrbot-install.sh cleanup

# 查看系统信息
./astrbot-install.sh info

# 服务健康检查
./astrbot-install.sh health

# 更新脚本自身
./astrbot-install.sh self-update

# 查看帮助
./astrbot-install.sh help
```

### 命令行参数说明

| 参数 | 说明 |
|------|------|
| `-y, --yes` | 非交互模式，自动确认所有提示 |
| `-m, --method METHOD` | 部署方式：`docker` 或 `compose`（默认: docker） |
| `-v, --version` | 显示版本号 |
| `-h, --help` | 显示帮助信息 |

## 脚本菜单功能

### 部署菜单
| 序号 | 功能 | 说明 |
|------|------|------|
| 1 | 一键部署 | Docker + 镜像加速 + AstrBot + NapCat + 防火墙全套部署 |
| 2 | 安装/更新 Docker | 安装或更新 Docker CE |
| 3 | 配置镜像加速 | 配置国内 Docker 镜像加速源 |
| 4 | 部署 AstrBot | 单独部署 AstrBot 容器 |
| 5 | 部署 NapCat | 单独部署 NapCat 容器 |
| 6 | Compose 部署 | 生成 docker-compose.yml 并启动 |

### 管理菜单
| 序号 | 功能 | 说明 |
|------|------|------|
| 7 | 更新所有服务 | 拉取最新镜像并重建容器 |
| 8 | 查看容器状态 | 查看所有容器运行状态 |
| 9 | 启动服务 | 启动所有已部署的容器 |
| 10 | 停止服务 | 停止所有已部署的容器 |
| 11 | 重启服务 | 重启所有已部署的容器 |
| 12 | 查看日志 | 实时查看容器日志 |
| 13 | 卸载服务 | 删除容器和镜像（保留数据） |

### 运维菜单
| 序号 | 功能 | 说明 |
|------|------|------|
| 14 | 备份数据 | 备份 AstrBot 和 NapCat 数据（自动保留最近 5 个备份） |
| 15 | 恢复数据 | 从备份中恢复数据 |
| 16 | 配置防火墙 | 自动配置 UFW/firewalld 开放端口 |
| 17 | Docker 清理 | 清理无用镜像、容器、网络和卷 |
| 18 | 检查端口占用 | 检查所需端口是否被占用 |
| 19 | 系统信息 | 查看操作系统、CPU、内存、磁盘、Docker 运行状态 |
| 20 | 服务健康检查 | 检查容器运行状态和 HTTP 可达性 |

### 其他
| 序号 | 功能 | 说明 |
|------|------|------|
| 21 | 更新脚本 | 检测并更新到最新版本 |
| 0 | 退出 | 退出脚本 |

## 容器配置信息

| 项目 | 容器名 | 镜像 | 端口 | 数据目录 |
|------|--------|------|------|----------|
| AstrBot | astrbot | snowykami/astrbot:latest | 6185 | /home/astrbot/data |
| NapCat | napcat | mlikiowa/napcat-docker:latest | 6099 | /home/napcat/data |

### NapCat 数据卷挂载

| 宿主机路径 | 容器路径 | 说明 |
|------------|----------|------|
| /home/napcat/data | /app/napcat/config | NapCat 配置文件 |
| /home/napcat/data/QQ | /app/.config/QQ | QQ 登录数据（持久化） |

### 备份目录

| 路径 | 说明 |
|------|------|
| /home/astrbot/backup/ | 数据备份目录（保留最近 5 个） |
| /home/astrbot/docker-compose.yml | Docker Compose 配置文件 |

## 部署后访问

- **AstrBot**：`http://你的服务器IP:6185`
- **NapCat WebUI**：`http://你的服务器IP:6099`

## 系统要求

- 操作系统：Ubuntu 20.04+ / Debian 11+（其他系统可能不完全兼容）
- 权限：root 用户或 sudo 权限
- 架构：x86_64 / ARM64
- 内存：建议 512MB 以上
- 磁盘：建议 1GB 以上可用空间

## 镜像加速源

| 序号 | 加速源 |
|------|--------|
| 1 | https://docker.1ms.run |
| 2 | https://docker.xuanyuan.me |
| 3 | https://docker.m.daocloud.io |
| 4 | https://dockerproxy.com |
| 5 | https://docker.nju.edu.cn |
| 6 | https://mirror.ccs.tencentyun.com |
| 7 | https://hub-mirror.c.163.com |

## AstrBot 官方文档

- 官网：https://astrbot.app

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

## 作者信息

- **作者**：科技酱
- **官网**：https://www.asoe.cn
- **技术文档**：https://docs.asoe.cn
- **GitHub**：https://github.com/techjiang/
- **哔哩哔哩**：https://space.bilibili.com/1768832152
- **玲珑**：https://forums.asoe.cn/
- **QQ群**：291974598
- **QQ群②**：474819022
- **QQ群③**：631167288

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
