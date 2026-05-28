# 技术迭代：subconverter — NAS 部署与 NPM `/subapi` 暴露

> **本仓库职责**：subconverter 服务在 NAS 上监听、Docker 运行、API 路径约定。  
> **基线（2026-05-28）**：`hjsmaster` 基于 **SubConverter-Extended**（含 mihomo bridge、HTML `/version` 页等）。  
> **反代配置**：见 `nginx-proxy-manager` 仓库 `scripts/nas-qnap-npm-phase1-final.mjs`。  
> **前端**：见 `sub-web` 仓库（`DEFAULT_BACKEND` 指向 `/subapi/sub?`）。  
> **版本**：2026-05-28

## 目录

- [1. 服务角色](#1-服务角色)
- [2. NAS 现状（参考）](#2-nas-现状参考)
- [3. 配置检查](#3-配置检查)
- [4. 本仓库交付物](#4-本仓库交付物)
- [5. 部署 / 升级](#5-部署--升级)
- [6. 验收（subconverter 视角）](#6-验收subconverter-视角)
- [7. 外部配置与 max_allowed_rulesets](#7-外部配置与-max_allowed_rulesets)
- [8. 常见现象](#8-常见现象)
- [9. 跨项目依赖](#9-跨项目依赖)
- [10. 变更记录](#10-变更记录)

## 1. 服务角色

subconverter 提供订阅转换 HTTP API，默认端口 **25500**。

| 端点 | 用途 |
|------|------|
| `GET /version` | Extended 版本信息页（HTML，浏览器访问） |
| `GET /version.txt` | 纯文本版本（**sub-web 页眉**、脚本健康检查） |
| `GET /sub?target=...&url=...` | 转换订阅 |
| `GET /dashboard` | Extended 统计面板（需在 pref 中启用 statistics） |

外网不直接暴露 `25500`，由 NPM 映射为：

- `https://<你的域名>:<HTTPS端口>/subapi/version` → `/version`
- `https://<你的域名>:<HTTPS端口>/subapi/version.txt` → `/version.txt`
- `https://<你的域名>:<HTTPS端口>/subapi/sub?...` → `/sub?...`

### 1.1 NPM `/subapi` 与静态资源

Extended 的 `/version` 页引用同路径下的 `favicon-*.svg`（如 `/subapi/version/favicon-light.svg`）。NPM 需将整个 `/subapi/` 前缀剥掉后反代到容器根路径，例如：

```nginx
location ^~ /subapi/ {
    proxy_pass http://<NAS_IP>:25500/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Prefix /subapi;  # 可选，服务端 HTML 亦可按 pathname 推断
}
```

**勿**只反代 `/subapi/version` 单条路径而不覆盖 `/subapi/version/favicon-*.svg`，否则版本页图标 404。

## 2. NAS 现状（参考）

| 项 | 值 |
|----|-----|
| 容器名 | `subconverter` |
| 镜像 | `subconverter:nas-amd64`（Extended 根 `Dockerfile` + NAS overlay） |
| 端口 | `0.0.0.0:25500→25500` |
| 内网访问 | `http://<NAS内网IP>:25500/` |
| 部署脚本 | `deploy/nas/deploy-to-qnap.sh` |

## 3. 配置检查

### 3.1 监听地址

NAS 叠加配置见 `deploy/nas/pref.toml`（构建时 COPY 进镜像 `/base/pref.toml`）：

```toml
[server]
listen = "0.0.0.0"
port = 25500

[advanced]
max_allowed_rulesets = 256
```

### 3.2 与 sub-web 的 URL 关系

| 内容 | 性质 | 说明 |
|------|------|------|
| 路径 `/subapi`、`/subapi/sub?`、`/subapi/version.txt` | **固定约定** | NPM 与 sub-web 写死，**不能改** |
| `https://<你的域名>:<HTTPS端口>` | **部署时必填** | 公网域名 + HTTPS 端口 |
| 下文整行 URL | **示例** | 联调对照用 |

**sub-web 部署时必须配置真实后端**（见 `sub-web` 仓库 `.env`）：

```bash
VITE_SUBCONVERTER_DEFAULT_BACKEND=https://<你的域名>:<HTTPS端口>/subapi
```

页眉版本检测：sub-web 请求 **`/subapi/version.txt`**（纯文本），**不再**解析 HTML 版 `/version`（Extended 迁移后 `/version` 为完整网页）。

## 4. 本仓库交付物

| 项 | 说明 |
|----|------|
| 根 `Dockerfile` | Extended 官方多阶段构建（含 Go mihomo bridge） |
| `deploy/nas/Dockerfile` | 薄 overlay：叠加 `pref.toml`、`config/houjia-template.ini` |
| `deploy/nas/deploy-to-qnap.sh` | 本机构建 linux/amd64 → save/load → 重建 NAS 容器 |
| `deploy/docker-compose.nas.example.yml` | 可选编排示例 |
| `deploy/nas/pref.toml` | NAS 生产偏好（`max_allowed_rulesets=256` 等） |

## 5. 部署 / 升级

```bash
# 在 subconverter 仓库根目录（需本机 Docker 可用）
./deploy/nas/deploy-to-qnap.sh
```

脚本两阶段：① 根 `Dockerfile` → `subconverter-extended-build`；② `deploy/nas/Dockerfile` → `subconverter:nas-amd64`；③ SSH 到 `nas-qnap` 替换容器。

更新后确认：

```bash
curl -s http://127.0.0.1:25500/version.txt
curl -s "http://127.0.0.1:25500/sub?target=clash&url=<URLEncode后的订阅链接>" | head
```

## 6. 验收（subconverter 视角）

- [ ] 内网 `25500/version.txt` 返回纯文本版本行
- [ ] 内网 `/sub?` + 真实 `url` 返回订阅内容
- [ ] 经 NPM `/subapi/version.txt`、`/subapi/sub?` 与内网一致
- [ ] 经 NPM `/subapi/version` 页面图标正常（非破损图）
- [ ] 无需开放公网 25500 端口

## 7. 外部配置与 max_allowed_rulesets

上游默认 **`max_allowed_rulesets = 64`**。自建 NAS 镜像使用 **256**（`src/handler/settings.h` 编译默认 + `deploy/nas/pref.toml`）。

| 情况 | 表现 |
|------|------|
| 外部 INI 规则集 **> max_allowed_rulesets** | 整份 `config=` 不生效 |
| **`config=` 指向 GitHub raw 且 NAS 拉取失败** | 回退默认策略组 |
| 自建 NAS | `default_external_config = "config/houjia-template.ini"`（镜像内路径） |

## 8. 常见现象

| 现象 | 说明 |
|------|------|
| `No nodes were found!` | API 已通；`url` 无效或无法拉取节点 |
| `/subapi/version` 图标破损 | 浏览器请求了 `/version/favicon-*.svg`（缺 `/subapi` 前缀）；检查 NPM 是否覆盖 `/subapi/` 全路径；升级含 favicon 修复的镜像 |
| sub-web 页眉铺满 HTML 源码 | 误用 `/version`（HTML）作版本 API；sub-web 应改用 `/version.txt` |
| `/subc` | NPM 301 到 `/subapi` |

## 9. 跨项目依赖

| 项目 | 分支（建议） |
|------|----------------|
| subconverter | **`hjsmaster`**（交付主分支） |
| nginx-proxy-manager | `feature/nas-qnap-phase1-proxy` |
| sub-web | `feature/npm-subpath-subw` |

## 10. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-05-16 | 初版：NAS + NPM `/subapi` |
| 2026-05-16 | §7：`max_allowed_rulesets` 与 `deploy/nas/pref.toml` |
| 2026-05-28 | Extended 基线、两阶段 Docker、`/version.txt`、sub-web 版本 API、NPM favicon 说明 |
