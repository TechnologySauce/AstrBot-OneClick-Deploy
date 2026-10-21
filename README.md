# AstrBot 一键部署脚本

> 一键安装 Docker 并部署 AstrBot / Napcat 服务。

## 功能特点

1. **自动安装 Docker** — 自动检测系统环境，安装 Docker CE 及相关组件
2. **Docker 镜像加速** — 自动配置国内镜像加速源，提升拉取速度
3. **容器自启动策略** — 所有容器均设置 `--restart=always`，开机即启动
4. **数据卷持久化存储** — 数据独立于容器，升级不丢失配置
5. **兼容性** — 支持 Ubuntu 20.04+ / Debian 11+ 系统
6. **选择性安装** — 支持按需选择部署 AstrBot 或 NapCat
7. **容器更新** — 一键拉取最新镜像并重建容器
8. **完整管理功能** — 启动、停止、重启、查看状态、查看日志、卸载等

## 使用方法

下载并执行脚本：

```bash
wget -O astrbot-install.sh https://gitee.com/einternet/AstrBot-OneClick-Deploy/raw/main/astrbot-install.sh && chmod +x astrbot-install.sh && ./astrbot-install.sh
```

## 脚本菜单功能

| 序号 | 功能 | 说明 |
|------|------|------|
| 1 | 一键部署 | Docker + 镜像加速 + AstrBot + NapCat 全套部署 |
| 2 | 安装/更新 Docker | 安装或更新 Docker CE |
| 3 | 配置镜像加速 | 配置国内 Docker 镜像加速源 |
| 4 | 部署 AstrBot | 单独部署 AstrBot 容器 |
| 5 | 部署 NapCat | 单独部署 NapCat 容器 |
| 6 | 更新所有服务 | 拉取最新镜像并重建容器 |
| 7 | 查看容器状态 | 查看所有容器运行状态 |
| 8 | 启动服务 | 启动所有已部署的容器 |
| 9 | 停止服务 | 停止所有已部署的容器 |
| 10 | 重启服务 | 重启所有已部署的容器 |
| 11 | 查看日志 | 实时查看容器日志 |
| 12 | 卸载服务 | 删除容器和镜像（保留数据） |

## 容器配置信息

| 项目 | 容器名 | 镜像 | 端口 | 数据目录 |
|------|--------|------|------|----------|
| AstrBot | astrbot | snowykami/astrbot:latest | 6185 | /home/astrbot/data |
| NapCat | napcat | mlikiowa/napcat-docker:latest | 6099 | /home/napcat/data |

## 部署后访问

- **AstrBot**：`http://你的服务器IP:6185`
- **NapCat WebUI**：`http://你的服务器IP:6099`

## 系统要求

- 操作系统：Ubuntu 20.04+ / Debian 11+（其他系统可能不完全兼容）
- 权限：root 用户或 sudo 权限
- 架构：x86_64 / ARM64

## AstrBot 官方文档

- 官网：https://astrbot.app

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
