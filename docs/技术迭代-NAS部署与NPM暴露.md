# 技术迭代：subconverter — NAS 部署与 NPM `/subapi` 暴露

> **本仓库职责**：subconverter 服务在 NAS 上监听、Docker 运行、API 路径约定。  
> **本次无 C++ 源码改动**：上游 API 已是 `/sub?`、`/version`，无需改程序。  
> **反代配置**：见 `nginx-proxy-manager` 仓库 `scripts/nas-qnap-npm-phase1-final.mjs`。  
> **前端**：见 `sub-web` 仓库（`DEFAULT_BACKEND` 指向 `/subapi/sub?`）。  
> **版本**：2026-05-16

## 1. 服务角色

subconverter 提供订阅转换 HTTP API，默认端口 **25500**。

| 端点 | 用途 |
|------|------|
| `GET /version` | 版本信息（sub-web 页眉、健康检查） |
| `GET /sub?target=...&url=...` | 转换订阅 |

外网不直接暴露 `25500`，由 NPM 映射为：

- `https://<你的域名>:<HTTPS端口>/subapi` → `/version`
- `https://<你的域名>:<HTTPS端口>/subapi/sub?...` → `/sub?...`

## 2. NAS 现状（参考）

| 项 | 值 |
|----|-----|
| 容器名 | `subconverter` |
| 端口 | `0.0.0.0:25500→25500` |
| 内网访问 | `http://<NAS内网IP>:25500/` |

## 3. 配置检查

### 3.1 监听地址

`pref.toml`（或运行时目录下）应允许 NAS 内网访问：

```toml
[common]
api_mode = true
port = 25500
```

容器网络下一般为 `0.0.0.0:25500`；仅本机调试可用 `127.0.0.1`。

### 3.2 与 sub-web 的 URL 关系

#### 这是示例还是部署必填？

| 内容 | 性质 | 说明 |
|------|------|------|
| 路径 `/subapi`、`/subapi/sub?`、`/subapi/version` | **固定约定** | NPM 反代与 sub-web 代码写死的路径规则，**不能改** |
| `https://<你的域名>:<HTTPS端口>` | **部署时必填（每环境不同）** | 你的公网域名 + HTTPS 端口，**不是**文档里的占位符 |
| 下文整行 URL | **配置完成后的示例** | 展示 sub-web 生成给终端用户的链接**长什么样**，便于联调对照 |

**本仓库（subconverter）部署本身不写入该 URL**；只需保证容器 `:25500` 与 NPM 的 `/subapi` 映射正确。

**sub-web 部署时必须配置真实后端**（见 `sub-web` 仓库 `.env`）：

```bash
# 勿带末尾 /sub?；sub-web 会自动拼接
VITE_SUBCONVERTER_DEFAULT_BACKEND=https://<你的域名>:<HTTPS端口>/subapi
```

部署 sub-web 前，向使用方确认并填入：

1. 公网 **域名**（或 DDNS 主机名）
2. **HTTPS 端口**（NPM 对外端口，如 `443`、`8443`）
3. NPM 是否已将 `/subapi` → NAS `subconverter:25500`（路径与上表一致）

配置完成后，sub-web「定制订阅」等入口生成的链接**形如**（域名端口换成你确认的实值）：

```text
https://<你的域名>:<HTTPS端口>/subapi/sub?target=clash&url=...
```

版本检测逻辑（sub-web）：运行时 `DEFAULT_BACKEND` = 上式中的 `VITE_SUBCONVERTER_DEFAULT_BACKEND` + `/sub?`，必须以 **`sub?` 结尾**；页眉版本请求会对 `sub?` 做 `slice(0,-5)+'/version'`，即访问 `/subapi/version`。

## 4. 本仓库可选交付（按需）

| 项 | 说明 |
|----|------|
| `runtime/subconverter/pref.toml` | 若使用仓库内 runtime 布局，确认 `port`、规则路径 |
| `deploy/docker-compose.nas.example.yml` | 可选示例编排（见同目录） |

**不要求**修改 `src/` 下 C++ 代码即可完成本次 NPM 联调。

## 5. 部署 / 升级

```bash
# 示例：官方镜像
docker run -d --name subconverter --restart always \
  -p 25500:25500 \
  -v /path/to/profiles:/base \
  tindy2013/subconverter:latest
```

更新镜像后确认：

```bash
curl -s http://127.0.0.1:25500/version
curl -s "http://127.0.0.1:25500/sub?target=clash&url=<URLEncode后的订阅链接>" | head
```

## 6. 验收（subconverter 视角）

- [ ] 内网 `25500/version` 有版本字符串
- [ ] 内网 `/sub?` + 真实 `url` 返回订阅内容（非 `No nodes were found!`）
- [ ] 经 NPM `/subapi/version`、`/subapi/sub?` 与内网结果一致
- [ ] 无需开放公网 25500 端口

## 7. 外部配置 `config=` 与 `max_allowed_rulesets`

上游 subconverter 在 `[advanced]` 中默认 **`max_allowed_rulesets = 64`**，用于限制单次外部 INI/TOML 中的 `ruleset=` 条数，避免公网开放实例被超大配置拖垮（内存、并发拉取远程规则、单次请求耗时）。**0 表示不限制**（见 `README-cn.md`）。

| 情况 | 表现 |
|------|------|
| 外部 INI 规则集 **> max_allowed_rulesets** | 日志 `Ruleset count in external config has exceeded limit.`，**整份** `config=` 不生效 |
| **`config=` 指向 GitHub raw 且 NAS 拉取失败** | 日志 `Load external configuration failed. Reason: line 0: Empty document`（**不是超限**），表现同为回退 `🔰 节点选择` |
| 自建 NAS | `max_allowed_rulesets = 256`；`config=` 优先用镜像内 `config/houjia-template.ini` 或 jsDelivr，避免 `raw.githubusercontent.com` |

本仓库分支 `fix/max-allowed-rulesets-default`：

- 编译默认值改为 `256`（`src/handler/settings.h`）
- `deploy/nas/pref.toml` + `deploy/nas/Dockerfile` 构建镜像 `subconverter:nas-amd64`

NAS 部署：在仓库根目录 `docker buildx build -f deploy/nas/Dockerfile -t subconverter:nas-amd64 --load .`，将镜像导入 QNAP 后 `docker run` 替换原容器（见 `deploy/docker-compose.nas.example.yml`）。

## 8. 常见现象

| 现象 | 说明 |
|------|------|
| `No nodes were found!` | API 已通；`url` 参数无效或无法拉取节点，**不是** NPM 404 |
| `/subc` | 已由 NPM 301 到 `/subapi`，subconverter 本身无 `/subc` 路径 |
| 未用自己写的策略组名 | 查日志是否 `exceeded limit`；见上文 §7 |

## 9. 跨项目依赖

| 项目 | 分支（建议） |
|------|----------------|
| subconverter | `feature/npm-subapi-expose`（文档 / 部署示例） |
| nginx-proxy-manager | `feature/nas-qnap-phase1-proxy` |
| sub-web | `feature/npm-subpath-subw` |

## 10. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-05-16 | 初版：明确无源码改动，文档化 NAS + NPM `/subapi` |
| 2026-05-16 | §7：`max_allowed_rulesets` 与 `deploy/nas/pref.toml` 挂载说明 |
