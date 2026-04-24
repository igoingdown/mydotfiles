# bytedcli Agent 开发指南

本文件面向编码 Agent 与协作者，定义仓库约束、分层边界与交付流程。版本历史与决策时间线不写在这里，请直接查看 `git log`。新增 domain、设计 UI API 到 CLI 的映射、确定命名或分层模式时，请同时参考 `docs/CONTRIBUTOR_PATTERNS.md`。

## 1. 文档

### 1.1 对外文档原则

- 仓库主文档只保留 2 份：`README.md`、`AGENTS.md`。
- 以下内容不算“仓库主文档”，允许按约定保留：
  - `CLAUDE.md`：Claude 兼容入口文件，只保留指向 `AGENTS.md` 的短说明，不单独维护正文。
  - `CONTRIBUTING.md`：模块维护范围与官方维护者说明。
  - `skills/*/SKILL.md`：对外发布的 skill 说明。
  - `.agents/skills/*`：本地 agent 开发/评测技能及附属材料。
  - `docs/*`：研发资料、接口快照与附属材料。
- `README.md` 是仓库内对外使用说明的单一事实来源（SSOT）。
- `website/`、`skills/*`、命令 help、示例输出都视为对外说明的一部分，要求与当前分支最终结果一致。

### 1.2 文案写法原则

- 所有对外文案都基于“当前分支最终相对 `master` 的结果”来写，不写开发过程中的中间态、临时方案或先删后改的过程。
- 避免使用依赖上下文的过程性表述，例如“只保留”“改回”“移除旧模式”等；除非 `master` 上确实存在对应旧能力，否则改写为“新增了什么”“支持什么”“推荐怎么用”。
- 判断文案是否合格时，以“未看过本分支 commit 历史、只了解 `master` 当前能力的读者能否直接看懂”为准。
- 文档、website、skills、命令 help、示例输出、测试 fixture、mock 数据与断言中，都不要使用真实线上服务、项目、PSM、namespace、URL 或租户。
- 需要具体示例值时，统一使用 `example.*`、`demo-*`、`sample-*` 这类占位值。
- 研发资料或接口证据中不要写本地详细路径（如 `/home/...`）；对外只写资料来源类型与标识。

### 1.3 文档同步要求

出现以下任一情况时，除了代码本身，还必须检查对外说明是否同步：

- 命令名、子命令结构、参数、默认值、输出格式变化。
- 新增或移除能力、认证方式、接入方式、安装方式、示例。
- 某个 domain 的推荐调用方式、skill 路由引用、MCP 暴露方式变化。

同步范围如下：

- `README.md`：必须更新用法、参数、示例或行为说明。
- `website/`：至少检查并按需更新 `website/src/content.ts`、`website/src/render.ts`、`website/guide.md`。
- `skills/*/SKILL.md` 与 `skills/*/references/*`：若某个 domain 的命令名、参数、认证方式或推荐调用方式变了，必须同步更新。
- `skills/bytedance-tools/references/*`：若总路由示例受影响，也必须同步更新。
- 若同一 domain 下不同子能力走不同网关或 host（例如 search/list 与 detail 不同），对外说明里要明确写清差异，并补离线测试覆盖各路由分支。

以下情况通常不需要同步对外文档：

- 仅修改实现细节、review 迭代、中间重构、局部修正。
- 仅修改仓库协作规则、研发资料或内部说明。

判断原则只有一条：只有当外部使用者可见的行为发生变化时，才要求同步对外文档。

## 2. 目录与边界

所有业务代码按 domain 拆分为文件夹模块，每个文件夹包含 `index.ts` barrel 文件。更细的层级约束见对应目录下的 `AGENTS.md`。

- `src/api/<domain>/`：API 客户端层。典型文件：`types.ts`、`client.ts`、`parsers.ts`、`api.ts`、`index.ts`。详见 `src/api/AGENTS.md`
- `src/cli/commands/<domain>/`：Commander 命令注册层，只定义参数与路由，不写业务逻辑。详见 `src/cli/commands/AGENTS.md`
- `src/cli/handlers/<domain>/`：CLI 业务入口，负责参数校验、调用 services/api、组装输出。详见 `src/cli/handlers/AGENTS.md`
- `src/services/<domain>/`：能力编排层，沉淀跨 API 流程复用，不直接输出终端内容。详见 `src/services/AGENTS.md`
- `src/auth/*`：认证与凭据存储（SSO、PAT、JWT override、本地存储），不要散落到 handlers 或 api。
- `src/presenters/*`：输出模板层，负责表格与摘要渲染，由 handlers 调用。
- `src/utils/*`：基础设施，如 config、http、error、cache、logger、time、struct、record。
- `src/mcp/*`：MCP server，尽量复用 CLI 命令树与 handlers，保证新增 CLI 命令可低成本暴露为 MCP tools。MCP tool name 统一采用下划线格式，不带 `bytedcli_` 前缀，当长度超过 60 字符时自动按首字母缩写。
- `skills/*`：Agent Skills，按域拆分；路由 skill 负责渐进式加载与引用子技能。纯 skill（无对应 CLI 代码层实现）也归入此目录，通过组合已有 CLI 命令编排测试或辅助流程。
- `.agents/skills/*`：仓库内维护的本地 agent 开发技能源码；需要兼容其他客户端时，优先复用这里的实现。
- `.claude/skills/*`、`.trae/skills/*`：兼容性软链或映射层，不要重复维护正文。
- `tools/*`：研发辅助脚本，例如 skill 引用同步；不承载 CLI 业务逻辑。
- `docs/*`：研发资料、接口快照等附属内容；不要在这里新增面向使用者的说明文档。贡献模式、命名约定与 UI API 到 CLI 的设计决策，统一沉淀在 `docs/CONTRIBUTOR_PATTERNS.md`。
- `src/cli/helpers.ts` 只放 CLI/命令侧复用逻辑，例如 option 聚合、终端展示辅助、文件入参读取；纯数据解析、record 搜索、时间/字符串处理不要继续堆在这里。
- `src/services/*` 严禁反向依赖 `src/cli/*` 或 `src/presenters/*`；如果 service 需要复用某段纯逻辑，优先下沉到 `src/utils/*`、`src/api/<domain>/parsers.ts` 或当前 domain 的 `helpers.ts`。

## 3. 新增或修改命令的落地流程

### 3.1 标准落点

- 命令定义放在 `src/cli/commands/<domain>/index.ts`，参数必须使用 `--xxx` 这类 option 形式传递，不使用位置参数。
- 需要唯一标识、名称、路径、时间范围等业务入参时，统一设计为显式 option，例如 `--id xx`、`--name demo-name`；不要设计成 `mr list repo-id` 这类位置参数形式。
- CLI 入口放在 `src/cli/handlers/<domain>/`，只做输入输出组装，不在这里堆跨 API 流程。
- 跨 API 编排放在 `src/services/<domain>/`。
- API 访问放在 `src/api/<domain>/api.ts`，配合明确的 TypeScript 接口与 schema 校验解析。
- handler 或 service 引用 API 类型时，使用 `import type { TypeName } from "@/api/<domain>"`，不要使用 `api.xxx.TypeName`。
- 含子命令的父命令（如 `bfo`、`bfo tree`、`bfo cpu-spec`）必须显式添加 `.action(() => { cmd.outputHelp(); })`，确保不带子命令执行时打印帮助信息且 exit code 为 0。Commander 默认在无 action 时 exit code 为 1。

### 3.2 认证与扫码登录命令约定

- 支持二维码登录的命令，默认展示终端二维码。
- 关闭终端二维码输出统一使用 `--no-terminal-qr`。
- 若关闭终端二维码时未显式传入 `--qr-image`，则自动启用 `--qr-image`，并生成系统临时目录下的临时文件路径。
- 二维码图片导出统一使用 `--qr-image [path]`；传参不带值时，默认生成系统临时目录下的临时文件路径。
- `-j/--json` 模式下，二维码登录命令应默认关闭终端二维码，并自动启用 `--qr-image`，确保外层流程可直接消费二维码图片路径。
- 若命令同时支持终端二维码与图片二维码，在 JSON 或 agent 场景下，二维码图片生成后应额外输出 `qr_image_ready` 事件，方便外层异步扫码流程消费。
- 只要命令存在“终端打印二维码”行为，关闭参数名都统一使用 `--no-terminal-qr`，以兼容 OpenClaw 等非 TTY 场景。
- 新增鉴权能力时，优先复用 `src/auth/index.ts` 及其下沉模块：SSO access token 是一级身份，ByteCloud JWT / Codebase JWT / Grafana / Security Platform 属于派生凭据或旁路会话；不要在各个 API client 里重复实现 token 刷新、cookie 落盘或 JWT 缓存逻辑。
- 需要新增本地凭据文件时，统一复用 `src/auth/storage/base.ts` 或既有 private-file helper，保持原子写、`0700/0600` 权限和 site/host 维度隔离；不要在 handler 或 service 中直接手写敏感文件存取。

### 3.3 输出、错误与配置约定

- 默认输出文本；`-j/--json` 时仅输出 JSON。
- 日志类命令默认输出纯文本，不输出表格。
- JSON 输出统一走 `src/utils/output.ts`，不要在各层散落 `console.log`。
- 配置统一走 `src/utils/config.ts`，优先级为 CLI > ENV > 默认值。
- HTTP 统一走 `src/utils/http.ts`，负责超时、重试、错误结构与可注入 fetch。
- 全局 HTTP 参数统一复用：
  - `--socks5-proxy`
  - `--http-proxy`
  - `--tls1.2`
  - `--http-timeout-ms`
  - `--http-retry-count`
  - `--http-retry-base-delay-ms`
  - `--http-retry-max-delay-ms`
- 错误统一抛结构化错误（`AppError`、`HttpError`），避免直接 `throw new Error(...)` 丢失上下文。

## 4. 测试策略

### 4.1 测试目录

- `test/`：单元测试与离线业务测试，可并发执行。
- `test/api/<domain>/`：API 层测试。
- `test/cli/handlers/<domain>/`：Handler 层测试。
- `test/cli/commands/<domain>/`：Command 层测试。
- `test/services/<domain>/`：Service 层测试。
- `integration/`：按需新增的手动集成测试目录；默认不进 CI，也不进 `npm test`，用于本地联调鉴权或内网能力。

### 4.2 测试要求与约定

- 改命令时，至少补齐 handler 与 cli 层测试，要求可在无鉴权、无内网条件下运行。
- 若改动涉及 schema 解析、auth、services 编排或 MCP 暴露，同时补对应 `api/*`、`auth/*`、`services/*`、`mcp/*` 的离线测试。
- 按域运行测试：
  `node --test -r ts-node/register -r tsconfig-paths/register test/api/<domain>/*.test.ts`
- 本地开发默认按修改范围运行测试，使用 `npm test` 作为验证入口；全量测试由云端 CI 执行。
- mock API 函数时，通过 barrel `require("@/api/index")` 获取 `api.xxx` 对象后直接替换属性。
- mock fetch 时，优先使用 `require("@/utils/http").setFetch(...)`，避免直接改 `global.fetch`。
- 测试中引用 API 模块时，使用 `require("@/api/<domain>")`，不要带 `.ts` 后缀。

## 5. 工程工作流

### 5.1 本地开发

- 入口点是 `dist/bytedcli.js`；本地运行命令使用 `node dist/bytedcli.js <command>`。
- 仓库经常通过 `git worktree` 在新目录下开发；Agent（包括 Claude、Codex）进入新 worktree 后，若发现缺少 `node_modules`、本地依赖命令不可用，或尚未执行过依赖安装，应先在仓库根目录自动执行 `npm install`（可直接使用 `npm i`），再继续后续分析、构建、测试或命令调试，无需先等待用户确认。
- 若 `package-lock.json`、`package.json` 或其他依赖相关文件发生变化，且当前环境依赖状态可能已过期，Agent 应先重新执行一次 `npm install`（或 `npm i`）再继续验证，避免把“未安装依赖”误判为代码问题。
- 常规自检命令：`npm run lint && npm run build && npm test`
- 提交前 Husky 会强制执行 `npm run lint`，且 `warning=0`。

### 5.2 分支与 MR

- 默认走分支开发与 MR 流程，不要直接 `commit + push` 到主分支。
- 仅“版本发布动作”可直接在主分支提交，包括 `package.json`、`package-lock.json` 的版本归档与 tag。
- 通过功能分支发起 MR，不要直接推主分支。推荐先将分支推到远端，再执行 `bytedcli codebase mr create`。
- 需要沉淀方案或结论时，优先写到 MR 描述或 MR comment，不要把流程性信息固化到仓库文档。
- MR 标题规范：`type(<scope>): description`
- 示例：`feat(aeolus): support access workflow submission`
- MR 描述默认只要求 `## Summary`。
- `## Summary` 需要说明改了什么、影响范围、是否有兼容性或迁移点，避免只重复标题。

### 5.3 提交前自查

提交前至少自查以下内容：

- 代码是否放在正确层级，没有把业务流程塞进 commands，也没有把终端输出塞进 services。
- 本次新增或修改的命令是否全部使用 option 参数，未引入新的位置参数。
- 若行为、命令、参数、输出或示例变化，对应的 `README.md`、`website/`、`skills/` 是否已同步。
- 示例、fixture、mock 数据是否仍使用占位值，而非真实线上信息。
- 测试是否覆盖到本次改动触达的层级。
- 是否已执行 `npm run lint && npm run build && npm test`。
- 是否通过功能分支提交，并准备走 MR 流程交付。

### 5.4 发版流程

- 如需发布新版本，运行 `npm run release`。
- 发版时不要手动执行 `npm publish` 或 `bnpm publish`；包发布由 release 流程自动完成。
- 完成版本发布相关改动后，额外执行 `npm --prefix website run deploy` 发布 bytedcli website。
- 版本号规则：
  - 新增接口、命令或能力：`+0.1.0`
  - bug fix：`+0.0.1`
