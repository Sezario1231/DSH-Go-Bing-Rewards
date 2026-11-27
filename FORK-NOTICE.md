# 来源与开源协议声明（Fork Notice）

本项目（下称「本仓库」）是一个**个人定制分支**，在以下三个开源项目的基础上修改而成。
本文件依据各上游项目的许可证要求，说明来源、协议与本地改动。发布、再分发本项目时请一并保留本文件与上游 `LICENSE`。

---

## 1. 来源项目（三个）

### 项目 A — 原始上游：TheNetsky / Microsoft-Rewards-Script

- 仓库：https://github.com/TheNetsky/Microsoft-Rewards-Script
- 使用分支：`v4`（新版 dashboard 架构）
- 作者：Netsky
- 协议：**GPL-3.0-or-later**（GNU General Public License v3.0 或更高版本）

### 项目 B — 直接 fork：chiihero / Microsoft-Rewards-Script（`V4-china` 分支）

- 仓库：https://github.com/chiihero/Microsoft-Rewards-Script
- 使用分支：`V4-china`，基线提交 `d7587bd`（版本 4.3.6）
- 维护者：chiihero
- 协议：**GPL-3.0-or-later**（随项目 A 的许可证）
- 项目 B 本身是项目 A 的 fork，针对中国大陆做了本地化：中国热搜查询源、PushPlus / 微信推送渠道、国内默认值调优、中文词库与日志中文化等。

### 项目 C — 运行平台与插件接口：ccch1mneyyy / dsh-Go

- 仓库：https://github.com/ccch1mneyyy/dsh-Go
- 说明：本仓库中的 DSH 插件（`local-msr-start`）与本地脚本依托 **DSH Go** 的公开插件 API（`ctx.inject(['dshGo'])`、`panel`、`composer.actions`）在 Android 手机上的 Ubuntu proot 环境中运行，并通过 `execFileSync` 调用本仓库自带的 shell 脚本。
- 协议：**AGPL-3.0**（GNU Affero General Public License v3.0）
- **重要边界**：本仓库**未复制、未修改、未内嵌**任何 dsh-Go 的源代码，仅通过其公开插件接口集成。因此本仓库是独立作品，**不**因平台关系而继承 AGPL-3.0；dsh-Go 的 AGPL-3.0 仅适用于 dsh-Go 项目本身。此处标注是为尊重并明确上游平台与其许可证。

---

## 2. 本仓库的许可证

本仓库整体沿用项目 A / B 的许可证：**GPL-3.0-or-later**，完整正文见仓库根目录 [`LICENSE`](LICENSE)。

依据 GPL-3.0 的要求，本仓库：

1. **保留**上游的 LICENSE 文件与版权声明，不做删除或修改；
2. 以**相同许可证（GPL-3.0-or-later）**发布所有派生源码；
3. 在下文「本地改动」中**标注**本仓库相对上游所做的修改；
4. 随源码一并提供本声明文件，便于下游再分发者履行同样的标注义务。

> 注：GPL-3.0 的 copyleft 只作用于**本仓库自身**（源自项目 A/B 的代码）。项目 C（dsh-Go）是独立且通过公开接口集成的平台，其 AGPL-3.0 不传染到本仓库。

---

## 3. 本地改动（相对项目 B `V4-china` @ `d7587bd`）

本仓库在手机端（Android / Ubuntu proot / 无 systemd）做了以下适配，改动文件均在上述 GPL-3.0 框架内：

### 3.1 网络与运行稳定性（源码）

- `src/browser/ResolverPin.ts`（新增）：为 `rewards.bing.com` 解析并提供可用 IP 映射，规避连接重置；可通过 `MSR_DISABLE_PINNED_IP=1` 关闭。
- `src/browser/Browser.ts`：接入上述 resolver 参数；修正 native UA 中的 `HeadlessChrome/` 标识。
- `src/browser/BrowserFunc.ts`：仪表板主接口失败时的 Bing flyout 兜底与快照缓存，缓解 `ECONNRESET` 导致的任务列表获取失败。
- `src/browser/auth/Login.ts`：将部分 `networkidle` 等待改为 `domcontentloaded`，适配国内网络。
- `src/index.ts`：
  - 将 `gapBetweenWorkers()` 的大任务间隔由 60–240 秒调整为 15–45 秒；
  - 保留账号串行与账号间隔逻辑（本仓库配置为 10 分钟）。
- `scripts/main/browserSession.js`、`scripts/main/manualLogin.js`、`scripts/utils.js`：本地登录 / 会话辅助脚本的调整。

### 3.2 本仓库新增文件

- `config.json`（由 `config.example.json` 生成，未纳入版本库）：本仓库实际使用配置。相对示例的改动：`headless=true`、`accountDelay=10m`、`searchDelay=1min–3min`、`readDelay=1min–2min`；其余保持示例默认（含 `clusters=1`、`GEO_LOCALE=CN`、`LANG_CODE=zh-CN`）。
- `scripts/local/`：`start.sh`、`daily-run.sh`、`daily-report.sh`、`stop-scheduler.sh`、`run-account2.sh`、`doctor.sh`、`points-json.sh`、`points-parse.awk`、`points-summary.sh`、`points-summary.awk` 等本地运行 / 统计 / 看板数据脚本（不依赖 systemd / cron）。
- `runbook.md`：本机部署与排障手册（发布版已对账号邮箱脱敏）。
- DSH Go 本地插件 `local-msr-start`：输入框胶囊「启动积分」+「全部功能」中的积分明细面板，通过 DSH Go 公开插件 API 实现，源码随本仓库附带于 `dsh-plugin/local-msr-start/`。

### 3.3 明确未做的事

- 未修改 `.env`（凭据文件，从未纳入版本库）；
- 未引入代理、指纹伪造或多实例等绕过措施；
- 未上传任何账号邮箱、密码、验证码、会话数据库（`sessions/`）或运行日志（`logs/`）。

---

## 4. 免责声明

本项目仅供学习与个人研究使用。使用自动化脚本可能导致 Microsoft Rewards 账户被暂停或封禁，风险自负。本仓库与原作者及上述上游项目 maintainers 无隶属关系；如有侵权请联系删除。

---

*本声明依据 GPL-3.0 第 4 节（修改版的标注义务）编写；dsh-Go 部分依据 AGPL-3.0 第 13 节的尊重性标注处理（本仓库不构成其修改版）。*
