# bytedcli Auth 业务逻辑梳理

## 1. 范围

本文聚焦仓库里的授权与认证逻辑，重点覆盖：

- CLI 对外入口：`src/cli/commands/auth/index.ts`
- CLI handler：`src/cli/handlers/auth/*`
- 主认证门面：`src/auth/index.ts`
- SSO / Session / JWT / PAT / 本地凭据存储：`src/auth/*`
- 依赖主认证链路的二级授权：`codebase`、`grafana`、`security_platform`、`feishu`、`meego`

不展开具体业务 API 的字段语义，重点看“凭据怎么来、怎么续、怎么落盘、谁依赖谁”。

## 2. 总体分层

auth 相关逻辑基本按下面几层组织：

1. `src/cli/commands/auth/index.ts`
   只负责声明命令、参数、帮助信息，把请求路由到 handler。
2. `src/cli/handlers/auth/*`
   负责 CLI 入参解释、输出格式、JSON 事件、成功/失败提示。
3. `src/auth/index.ts`
   作为 auth 门面，向上暴露统一能力：
   - 登录 / 登出 / 状态
   - userinfo
   - SSO token
   - ByteCloud JWT
   - Codebase JWT
   - Grafana session
4. `src/auth/sso.ts`
   是主认证引擎，负责：
   - Device Code flow
   - access token / refresh token 管理
   - userinfo 查询
   - ByteCloud JWT 获取与缓存
5. `src/auth/session.ts`
   负责浏览器态 SSO session：
   - 二维码会话登录
   - SSO cookie 校验与落盘
   - 借浏览器 session 自动批准 device login
6. `src/auth/*storage*` 与 `src/utils/paths.ts`
   负责敏感凭据的本地文件存储位置、权限和兼容旧文件名。

一句话概括：

- `auth login` 解决“拿到 SSO 身份”
- `SSOClient.getBytecloudJwt()` 解决“把 SSO 身份转成业务侧通用 JWT”
- 各 domain 再在此基础上做自己的二次派生或专有存储

## 3. 主认证链路

### 3.1 `auth login` 的两种模式

`bytedcli auth login` 实际支持两条主线：

- `device_code` 模式
  - 默认模式
  - 由 `auth.beginLogin()` 调 `SSOClient.requestDeviceCode()`
  - 用户扫码授权后，`auth.completeLogin()` 通过 `SSOClient.pollForToken()` 轮询换取 token
  - 成功后把 token 存入 `TokenStorage`
- `session` 模式
  - 命令：`bytedcli auth login --session`
  - 由 `auth.beginBrowserSessionLogin()` 走 `src/auth/session.ts`
  - 登录结果不是 access token，而是可复用的浏览器 SSO cookie session
  - 适合 webshell、浏览器态功能、Grafana、部分 CAS 场景

### 3.2 阻塞式与非阻塞式登录

`src/cli/handlers/auth/login.ts` 额外封装了 agent 友好的两阶段模式：

- `--begin`
  - 生成 challenge
  - 把 challenge 落盘到 `auth_login_challenges/`
  - 返回 `complete_token` 和 `complete_command`
- `--complete <token>`
  - 读取 challenge 文件
  - 尝试完成轮询
  - 返回 `pending` / `expired` / `success`

这个设计的业务价值：

- 避免 agent 或非 TTY 进程阻塞等待扫码
- 允许外层编排把“发起登录”和“轮询完成”拆开
- 配合 `--json` + `qr_image_ready` 事件，外层可以拿二维码文件路径做异步扫码流程

### 3.3 登录后的核心产物

主登录成功后，仓库里有两类核心产物：

- SSO access token / refresh token
  - 落在 `token*.json`
  - 给 `userinfo`、`get-sso-token`、ByteCloud JWT 获取流程使用
- SSO session cookies
  - 落在 `sso_session*.json`
  - 给 `--session` 相关能力、Grafana、Security Platform、自动批准 device login 使用

两者不是互斥关系：

- 纯 `auth login` 主要得到 token
- `auth login --session` 主要得到 cookie session
- 在非 JSON 场景下，`--session` 登录成功后，handler 还会尝试 `autoLoginWithBrowserSession()`，自动补一次 CLI device login，把浏览器态会话再转换成 CLI token

## 4. 主命令的业务语义

### 4.1 `auth status`

调用 `auth.status()`：

- 如果在 `byteclaw` 环境，直接视为已登录
- 否则读取本地 token
- 若 token 临近过期，会优先尝试 refresh
- 有效则返回 `authenticated=true`
- 无效或 refresh 失败则返回未登录

### 4.2 `auth userinfo`

调用 `auth.userinfo()`，但底层有两条路径：

- 若存在有效 ByteCloud JWT override，则优先调用 ByteCloud userinfo
- 否则走标准 SSO userinfo

这意味着 `userinfo` 不只是“看 SSO 当前用户”，它会受当前 ByteCloud JWT override 影响。

### 4.3 `auth logout`

调用 `auth.logout()` 后会清理：

- SSO token
- 所有 SSO session cookies
- Grafana session cache
- ByteCloud JWT override
- ByteCloud JWT 本地缓存

所以 `logout` 是“全量清掉主 auth 链路上的本地状态”，不是只删一个 access token。

### 4.4 `auth get-sso-token`

直接返回当前有效 SSO token：

- 没登录则抛 `AUTH_REQUIRED`
- token 快过期会先 refresh

### 4.5 `auth set-bytecloud-jwt-token`

这是一个“人工覆盖”能力：

- handler 收到 JWT 后，调用 `auth.setBytecloudJwtOverride()`
- 先按当前 `cloudSite` 算出目标 ByteCloud host
- 再调用 `validateBytecloudJwt()` 去目标 host 校验这个 JWT 是否可用
- 只有校验通过才会落盘

业务意图很明确：

- 允许外部系统、浏览器抓包或人工流程把 JWT 注入 CLI
- 但不能盲存，必须先验证可用性

### 4.6 `auth get-bytecloud-jwt-token`

这是仓库里非常关键的一层派生凭据，很多 API client 实际依赖它，不直接依赖 SSO access token。

优先级如下：

1. `byteclaw` mock JWT
2. host 级别的 ByteCloud JWT override
3. 环境变量 JWT
4. 当前有效 SSO token 换取 ByteCloud JWT
5. 取到后做内存 + 磁盘缓存

### 4.7 `auth get-codebase-jwt-token`

它不是独立登录，而是二次派生：

1. 先拿 ByteCloud JWT
2. 再调用转换接口把 ByteCloud JWT 换成 Codebase JWT

所以 Codebase JWT 依赖链是：

`SSO / override / env -> ByteCloud JWT -> Codebase JWT`

## 5. `SSOClient` 的核心业务规则

`src/auth/sso.ts` 是 auth 逻辑最核心的文件，主规则如下。

### 5.1 site 到环境/host/clientId 的映射

`SSOClient` 初始化时不直接写死站点，而是从 `getConfig().cloudSite` 派生：

- `bytessoEnvForSite(site)`
- `bytessoClientIdForSite(site)`
- `bytecloudHostForSite(site)`
- `ssoHost(env)`

所以 `--site` 不只是影响业务 API 域名，也会影响 auth 侧：

- SSO 环境
- client id
- ByteCloud host
- 本地 token/session 文件名

### 5.2 token 获取与刷新

`getValidToken()` 的顺序是：

1. 从 `TokenStorage` 读 token
2. 未过期则直接用
3. 若临近过期且有 refresh token，提前 refresh
4. 若已过期但有 refresh token，也尝试 refresh
5. refresh 失败则清空本地 token，视为未登录

业务上的关键点：

- 这里把“续期”集中在 auth 层，调用方不需要自己判断 refresh
- refresh 失败会主动清本地状态，避免反复使用坏 token

### 5.3 ByteCloud JWT 的缓存和覆盖

ByteCloud JWT 是仓库里的“业务通用 JWT”，处理比 SSO token 更复杂：

- 支持 host 级 override 文件
- 支持旧版单文件 override 兼容
- 支持 env fallback
- 支持按 host 分开的 JWT cache 文件
- cache TTL 是 10 分钟

这里的 host 维度非常重要，因为不同 `cloudSite` 实际对应不同 ByteCloud host，JWT 不能简单全局复用。

### 5.4 userinfo 的特殊分支

`getUserInfo()` 先检查 override/mocked JWT：

- 有 JWT 时，走 ByteCloud userinfo
- 无 JWT 时，才走 SSO userinfo

这让 `userinfo` 具备“按业务站点查看身份”的能力，但也意味着覆盖 JWT 后，userinfo 的数据源会切换。

## 6. 浏览器 Session 链路

`src/auth/session.ts` 负责浏览器态认证，适合需要 cookie 的能力。

### 6.1 `--session` 登录做了什么

1. 向 SSO 申请二维码 token
2. 生成 `qr_url`
3. 轮询检查扫码结果
4. 扫码通过后，尝试把 cookie jar “水合”为可复用 session
5. 校验 session 是否真的可用
6. 成功后把 cookies 落盘到 `sso_session*.json`

### 6.2 为什么还要校验和水合

不是扫码成功就一定拿到了可复用 cookie。代码里专门做了：

- `validateSsoSessionJar()`
- `hydrateApprovedSession()`

业务上是在解决这个问题：

- 某些 SSO 场景下，二维码批准成功了，但 cookie 还没完成最终跳转链
- 需要再走几跳导航才能把浏览器态 session cookie 补齐

### 6.3 session 的复用场景

目前主要用于：

- `auth login --session` 自身
- `autoLoginWithBrowserSession()` 自动批准 CLI device login
- Grafana session 交换
- Security Platform 的 CAS / 浏览器登录链路

## 7. 派生与专用授权模型

### 7.1 Codebase

Codebase 有三种鉴权来源，优先级在 `src/api/codebase/client.ts` 里明确写死：

1. 本地配置或环境变量里的 Codebase JWT
2. PAT
3. 通过当前 SSO 会话自动换取 Codebase JWT

也就是说，Codebase 不是单纯“依赖主 auth”：

- 它允许完全脱离 SSO，直接用 PAT 或显式配置 JWT
- 只有前两者都没有时，才回退到主 auth 派生链路

对应的本地文件：

- `codebase_auth.json`
- `codebase_pat.json`

### 7.2 Grafana

Grafana 不直接依赖 access token，而依赖浏览器 cookie：

1. 先查本地 `grafana_session` cache
2. 没有则读取本地 SSO session cookies
3. 访问 Grafana OAuth 登录入口，跟随跳转
4. 抓取 `grafana_session_v1`
5. 落盘缓存

所以它强依赖 `auth login --session` 这条链。

### 7.3 Security Platform

Security Platform 是另一套更独立的 JWT 模型，优先级为：

1. cached JWT
2. session cookie refresh
3. 基于 SSO cookie 的 CAS ticket 流程
4. browser login fallback

这条链说明它虽然最终也能借到 SSO session，但刷新逻辑不复用 `SSOClient.getBytecloudJwt()`，而是独立维护。

### 7.4 Feishu

Feishu 不是用主 `auth login`，而是独立的一套 device/OAuth 机制：

- 先创建 bot config（`app_id` / `app_secret`）
- 再用 device flow 换 user access token
- token 过期后支持 refresh
- scope 不足时直接抛 `AUTH_REQUIRED`，并提示强制重新授权

本地状态拆成两类：

- bot config
- bot token

### 7.5 Meego

Meego 也独立于主 auth：

- 先做 MCP client registration
- 再发起 OAuth device flow
- 成功后落地 client + token
- 失效时会自动判断是否需要重新注册 client

### 7.6 Starling / Volcano

这两类不是 OAuth/SSO，而是传统 AK/SK 凭据：

- `starling_credentials.json`
- `volcano_credentials.json`

特点是：

- 无派生逻辑
- 无自动刷新
- 纯本地私有文件存储

## 8. 本地存储布局

大部分 auth 状态都在 `~/.local/share/bytedcli/data/` 下，常见文件有：

- `token*.json`
- `sso_session*.json`
- `auth_login_challenges/*.json`
- `jwt_override*.json`
- `codebase_auth.json`
- `codebase_pat.json`
- `grafana_session*.json`
- `feishu_bot*.json`
- `feishu_bot_token*.json`
- `meego_auth.json`
- `starling_credentials.json`
- `volcano_credentials.json`

存储层的共同规则：

- 目录尽量设为 `0700`
- 文件尽量设为 `0600`
- 写入使用原子写临时文件再 rename
- 普遍保留 legacy 文件兼容逻辑

## 9. 错误与提示机制

auth 失败不只是抛异常，还会统一补“下一步怎么做”的提示。

关键逻辑在 `src/utils/error/converters.ts`：

- `AUTH_REQUIRED` 会被转换成标准 hint
- 普通用户默认提示 `bytedcli auth login [--begin]`
- agent 场景默认提示 `bytedcli --json auth login --begin`
- 若业务域自带专用 authCommand，也允许覆盖默认提示

这让上层 CLI、MCP、agent 都能拿到一致的“补救动作”。

## 10. 当前 auth 设计的几个关键结论

1. 主 auth 的真正根是 SSO，不是 ByteCloud JWT
   - ByteCloud JWT 是主业务 JWT 层
   - Codebase JWT、Grafana、Security Platform 都是在它之上再派生或旁路复用

2. `--session` 是一条独立且重要的会话链
   - 它不是 `auth login` 的附属参数而已
   - 实际承担了浏览器态能力、Grafana、CAS 场景的基础设施职责

3. 很多业务 API client 依赖的是 `getBytecloudJwt()`
   - 说明仓库已经把“SSO -> 业务 JWT”的转换集中收口
   - 新域接入时优先复用这一层，不要各自重复造轮子

4. Codebase、Feishu、Meego 都是“专用 auth 子系统”
   - 虽然放在同一个仓库里，但不应简单视为主 auth 的一个 option
   - 它们各自有独立存储、独立刷新策略、独立错误提示

5. 凭据文件管理是 auth 设计的一部分
   - 不是单纯的工具函数
   - host/site 维度隔离、旧文件兼容、文件权限控制，都直接影响可用性和安全性
