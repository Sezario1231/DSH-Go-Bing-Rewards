# Microsoft Rewards 脚本 · 手机部署运行手册（Runbook）

> 部署位置：DSH Go 内置 Ubuntu 容器（proot / arm64 / Android）
> 项目目录：`/root/workspace/microsoft-rewards-script`
> 项目来源：`chiihero/Microsoft-Rewards-Script`，分支 `V4-china`，版本 **4.3.6**
> 本文写作时间：2026-11-24

---

## 1. 一分钟速查

| 我要做什么 | 命令 |
|---|---|
| **一键启动（不调 AI）** | 输入框上方胶囊「启动积分」（插件 `local-msr-start`），点一下即跑；或在终端执行 `bash scripts/local/start.sh` |
| **实时积分明细面板** | App「全部功能 › 积分明细」（插件面板，每 15 秒自动刷新）。抽屉式分区：账号一 / 账号二 / 最近得分 / 近几天日明细 / 月明细 / 风控情况 / 运行状态；量化指标含余额、今日新增、搜索、阅读、签到、其他、错误数；风控记录疑似受限/bot标记/活动折叠/用户警告/登录验证/错误数（仅记录不阻断）；数据来自 `bash scripts/local/points-json.sh` 与 `bash scripts/local/points-summary.sh`（均只读日志） |
| 立即手动跑一轮 | `cd /root/workspace/microsoft-rewards-script && /bin/bash scripts/local/daily-run.sh` |
| 看今天的运行日志 | `tail -f logs/cron-$(date +%F).log` |
| 看脚本自己的详细日志 | `tail -f logs/$(date +%F).log` |
| 改定时时间 | 在 DSH App「定时任务」里改（当前 09:00 启动 / 15:30 检查），容器调度器已停用 |
| 看今天积分汇报 | `bash scripts/local/daily-report.sh` |
| 自检 | `bash scripts/local/doctor.sh`（只读检查，不拉起任何调度器） |
| 全部停止 | `bash scripts/local/stop-scheduler.sh` |
| 停掉正在跑的一轮 | `bash scripts/local/stop-scheduler.sh`（比 pkill 更安全，会跳过自身/父进程） |
| 检查登录态是否还有效 | 看日志里 `[SESSION] 正在恢复已保存的浏览器会话` + `当前状态: LOGGED_IN` |

> **调度方式（重要）**：每日唤醒由 **DSH App 定时任务**负责（见第 5.6 节），容器内的 `scheduler.sh` / `cron` 均已停用，不要再手动拉起，否则会和 DSH 定时冲突、导致重复运行。

---

## 2. 环境事实（实测）

```
系统      Ubuntu 24.04.5 LTS (proot, aarch64)
内核      Android 15 / 6.6.118
Node      v24.22.1（系统自带，满足 >=24，未改动）
npm       11.19.1（registry 已指向 registry.npmmirror.com）
CPU       8 核
内存      整机 15Gi，脚本运行时实测峰值 used 12.4Gi（含手机其他应用）
磁盘      可用 222G
浏览器    Patchright Chromium 149.0.7827（arm64，装在 ~/.cache/ms-playwright）
调度      DSH App 定时任务（09:00 启动 / 15:30 检查）；cron 和容器 scheduler.sh 均已停用，见第 5 节
```

**重要**：`free -h` 显示的是**整机内存**，不是容器独享。脚本自身占用见第 6 节。

---

## 3. 首次部署做了什么（供重建时参考）

```bash
# 1. 克隆（GitHub 直连慢，可加 gh-proxy.com 前缀）
cd /root/workspace
git clone -b V4-china https://github.com/chiihero/Microsoft-Rewards-Script.git microsoft-rewards-script
cd microsoft-rewards-script

# 2. 装依赖（npmmirror 源）
npm install

# 3. 装 Chromium（走国内镜像下载二进制）
PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright npx patchright install chromium

# 4. 补系统运行库（首次必须，否则 Chromium 起不来）
apt-get update
npx patchright install-deps chromium

# 5. 构建
npm run build

# 6. 配置文件
cp env.example .env && chmod 600 .env   # 填 ACCOUNT_1_* / ACCOUNT_2_*
cp config.example.json config.json

# 7. 配置每日定时（不用 cron / 容器调度器，原因见第 5 节）
#    在 DSH App「定时任务」里建立两条：09:00 启动、15:30 检查补跑
#    详见第 5.6 节。容器 scheduler.sh 已停用，不要再启动。
```

重建后先手动验证一轮：`bash scripts/local/daily-run.sh`。

---

## 4. 配置文件说明

### 4.1 `.env`（账号，权限 600，勿外传）

路径：`/root/workspace/microsoft-rewards-script/.env`

```dotenv
ACCOUNT_1_EMAIL=...
ACCOUNT_1_PASSWORD=...
ACCOUNT_1_LANG_CODE=zh-CN
ACCOUNT_1_GEO_LOCALE=CN

ACCOUNT_2_EMAIL=...
ACCOUNT_2_PASSWORD=...
ACCOUNT_2_LANG_CODE=zh-CN
ACCOUNT_2_GEO_LOCALE=CN
```

- 账号编号必须从 1 开始连续或按升序，脚本按编号升序依次执行
- 若某账号有 TOTP 二次验证，填 `ACCOUNT_N_TOTP_SECRET=`
- **`.env` 已被 `.gitignore` 忽略**；任何情况下不要提交、不要截图外发

### 4.2 `config.json`（行为，与官方默认只差 3 处）

```jsonc
{
  "headless": true,                    // ← 改动 1：容器无显示器，必须 true
  "clusters": 1,                       // 1 = 两账号串行
  "accountDelay": { "min": "1h", "max": "2h" },   // ← 改动 2：账号间隔 1-2 小时随机
  ...
  "searchSettings": {
    "searchDelay": { "min": "6min", "max": "12min" },  // 官方默认值，未改
    "queryEngines": ["china", "local"]                 // 官方默认值，未改
  }
}
```

其余全部保持 `config.example.json` 默认值。**未做任何指纹伪装、代理、多开、并发调参。**

> ⚠️ `config.json` 是严格 schema（`src/util/Validator.ts` 用 zod 校验），
> 不能只写几个字段，必须整份复制 `config.example.json` 再改。

---

## 5. 定时调度

### 5.1 ⚠️ 重要：cron 在本容器不可用

**实测结论：Debian 版 cron 能装上、能启动，但任务永远不会触发。**

原因（实测证据）：

```
CapEff: 0000000000000000        ← 容器内没有任何 Linux capability
Seccomp: 2                      ← Seccomp 过滤器生效
```

proot 环境下 cron 依赖的 fork/setuid 隔离被拦截。实测装了分钟级任务，等待 75 秒 **完全没有任何触发**，也没有系统日志。

另外 `CRON_TZ` 是 Vixie cron 的特性，Debian 的 `cron 3.0pl1` **不支持**，写了也会被忽略。

**所以本项目不用 cron。**

### 5.2 历史方案：自研常驻调度器（已停用）

曾写过 `scheduler.sh` 常驻进程自己算时间（每 60 秒检查、到点执行 `daily-run.sh`）。它和 cron 有同样的致命问题：**proot 容器没有 systemd，App 退出或系统回收后调度器被一起终止，且没有提示**。因此该方案已停用，`scheduler.sh` 不要再启动。

`daily-run.sh`（flock 防重入 + 清理残留 + 日志落盘 + `npm start`）仍在使用，但**只由 DSH 定时任务或手动调用**，不再由常驻调度器触发。

### 5.6 ✅ 当前采用：DSH 定时任务（容器调度器已停用）

**2026-11-25 起改用 DSH App 的定时任务唤醒 AI，由 AI 启动和检查，不再用容器内的 scheduler.sh。**

原因：容器调度器仍会随 App 退出而消失；改用 DSH 定时任务后，唤醒由 App 层负责，AI 起来后能立即排查异常。

两个定时任务（在本会话用 schedule_create 建立，target=this_session）：

| 时间 | 任务 | AI 做什么 |
|---|---|---|
| 每天 09:00 | 启动微软奖励脚本 | doctor.sh 自检 → 清理残留 → 启动 daily-run.sh → 确认登录 |
| 每天 15:30 | 检查奖励积分并补跑 | daily-report.sh 汇报 → 读日志判断完整性 → 失败则补跑 → dsh-ui 卡片汇报 |

配套脚本：

- `scripts/local/doctor.sh` — 只读自检（调度方式/运行状态/会话/配置/残留），**不会拉起任何调度器或实例**
- `scripts/local/daily-report.sh` — 每日积分汇报（只读，提取余额变化、错误、风控信号；风控信号只记录不阻断，保持无人值守）

容器内 scheduler.sh / crontab 均已停用，doctor.sh 也不会重新启动它们。如需手动跑一轮：`bash scripts/local/daily-run.sh`。

## 6. 实测性能数据（2026-11-24 单账号验证轮）

| 指标 | 数值 |
|---|---|
| 单账号登录（会话复用时） | **12-15 秒** 到 `LOGGED_IN` |
| 阅读任务 8 篇耗时 | **约 5 分钟**（间隔被临时调成 5-15 秒） |
| 阅读任务得分 | **+27 分**（8 篇 × 3 分） |
| 脚本自身内存（node 主进程） | 峰值 **279 MiB** |
| Chromium 进程组内存 | 峰值 **853 MiB** |
| 脚本总占用（node + Chromium） | **约 1.1 GiB** |
| 手机温度变化 | thermal_zone0 约 36.5℃ → 46.2℃（+10℃） |

**整轮（两账号、正式配置）预计耗时 3-5 小时**，主要花在：
- 每账号搜索间隔 6-12 分钟 × 移动/桌面两组
- 阅读间隔 6-11 分钟 × 最多 10 篇
- 账号之间强制等 1-2 小时

> 想缩短验证时间，可临时把 `searchDelay` / `readDelay` 调到秒级，验证完记得改回去。

---

## 7. 登录态与会话

### 7.1 存储位置

`/root/workspace/microsoft-rewards-script/sessions/sessions.db`（SQLite，权限 600）

每个账号两个平台各一行：`mobile` 和 `desktop`。

### 7.2 怎么确认登录态还有效

```bash
cd /root/workspace/microsoft-rewards-script
node -e '
const {DatabaseSync}=require("node:sqlite");
const db=new DatabaseSync("sessions/sessions.db");
for(const r of db.prepare("SELECT email,platform,updated_at FROM sessions").all())
  console.log(r.email,r.platform,new Date(r.updated_at).toLocaleString());'
```

运行日志里出现这两行就说明复用了会话、没走登录：

```
[SESSION] 正在恢复已保存的浏览器会话 | Cookie数=45
[LOGIN] 当前状态: LOGGED_IN
```

### 7.3 会话失效了怎么办

症状：日志里出现 `EMAIL_INPUT`、`PASSWORD_INPUT`、`PASSKEY_*`，或卡在「批准登录请求」。

**方案 A — 重新跑交互式登录助手**（推荐，需要你配合批准/收验证码）

```bash
cd /root/workspace/microsoft-rewards-script

# 1. 启动常驻浏览器助手
nohup node scripts/local/interactive-login.cjs > logs/_intlogin.log 2>&1 &

# 2. 下发命令（每条命令一个 JSON，最多等 40 秒）
node scripts/local/mkcmd.cjs '{"op":"setua","ua":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36","viewport":{"width":1280,"height":800}}'
node scripts/local/mkcmd.cjs '{"op":"goto","url":"https://rewards.bing.com/auth/login","wait":9000}'
node scripts/local/mkcmd.cjs '{"op":"fill","sel":"#usernameEntry","value":"<邮箱>"}'
node scripts/local/mkcmd.cjs '{"op":"click","sel":"button[data-testid=\"primaryButton\"]","wait":10000}'
# 看当前状态
node scripts/local/mkcmd.cjs '{"op":"eval","js":"JSON.stringify({title:document.title,text:document.body.innerText.slice(0,300)})"}'
# 保存会话（登录成功到 dashboard 之后）
node scripts/local/mkcmd.cjs '{"op":"save","email":"<邮箱>","platform":"desktop"}'
node scripts/local/mkcmd.cjs '{"op":"quit"}'
```

**方案 B — 两个账号的特殊情况**

| 账号 | 遇到的障碍 | 解决 |
|---|---|---|
| 账号 1（QQ 邮箱） | 强制走**通行密钥**（Passkey），容器无蓝牙无法完成 | 先发 `{"op":"nofido"}` 让通行密钥立即失败，微软会自动回退到「使用另一种方式登录」→「使用密码」 |
| 账号 2（Outlook 邮箱） | 需要**邮箱验证码**（发到账号 1 的 QQ 邮箱） | 填恢复邮箱 → 点「发送验证码」→ 收邮件拿 6 位码 → `{"op":"type","value":"<6位码>"}` |

**方案 C — 从 Windows 那台机器搬会话**

`sessions/sessions.db` 整个文件可以直接复制过来替换，登录态原样继承（最快）。

---

## 8. 已知风险清单

### 8.1 DSH 定时任务未触发 → 当天静默漏跑 🔴

**风险**：每日唤醒依赖 DSH App 的定时任务（09:00 / 15:30）。若 App 未运行、任务被暂停或会话失效，当天不会自动跑，且**没有任何提示**（历史上有过 15:30 晚触发约 2 分钟的情况，属正常范围）。

**缓解**：
- 每天开 App 后确认定时任务仍为 active（DSH「定时任务」里看）
- 发现当天没跑就手动补跑：`bash scripts/local/daily-run.sh`
- 用 `bash scripts/local/daily-report.sh` 或 `ls -lt logs/cron-*.log | head -3` 确认最近日期是今天
- **不要再依赖容器内的 scheduler.sh / cron，它们已停用且会随容器消失**

### 8.2 发热与耗电 🟠

**实测**：单账号 5 分钟阅读任务，CPU 温度从 36.5℃ 升到 46.2℃（+10℃）。
整轮 3-5 小时持续运行，温度可能更高。

**缓解**：
- 定时放在 09:00 而非夜间，避免与充电发热叠加
- 不要把手机放在被子/枕头下
- 若发现烫手，先 `bash scripts/local/stop-scheduler.sh` 停掉
- 建议开省电模式之外的温度监控

### 8.3 流量消耗 🟡

Chromium 会加载真实网页，单轮估算 **200-500 MB**（搜索页 + 阅读文章 + 图片）。
若用移动数据，建议：
- 在 `config.json` 里开 `"experimental": { "blockMedia": true }` 拦截图片/视频
- 或只在 Wi-Fi 下跑

### 8.4 网络对 `rewards.bing.com` 的间歇性中断 🟠

**已修复**。该域名解析出 2 个 IP，其中部分会被 RST，导致登录后无法跳回 rewards，
现象是登录流程在「选择登录方式」页死循环，或报
`Rewards dashboard did not render (no section#dailyset)`。

修复方式（已写进代码）：`src/browser/ResolverPin.ts` 会在每次启动时探测可用 IP，
并注入 `--host-resolver-rules` 固定使用它。成功时日志出现：

```
[BROWSER] rewards.bing.com 已固定到可用 IP（规避连接重置）| MAP rewards.bing.com 150.171.28.10
```

**没有这行日志 = 探测失败，行为退回原样**（可能偶发失败，重跑一次通常就好）。

临时关闭该机制：`MSR_DISABLE_PINNED_IP=1 npm start`

### 8.5 账号风控 🟠

脚本自带随机延迟、随机点击、滚动等基础行为，但**任何自动化都有被风控的可能**。
本项目原始 README 已声明风险自负。

**不要**：加代理、改指纹、多开、缩短延迟来"提效"——这些反而更容易触发检测。
**若日志出现** `Fraud_UserWarning_BotScore_UX`：立即停止该账号，静置几天。

### 8.6 每日签到报错（非致命）🟡

日志里的：

```
[DAILY-CHECK-IN] 每日签到出错 | message=签到未确认到账 | pointsGained=0
```

这是微软返回 `status=200` 但积分未增加，通常表示当天该签到已发放或当前不可领。
**不影响其他任务**，可忽略。

### 8.7 阅读任务拿不满 30 分 🟡

实测 8 篇后第 9 篇返回 `pointsGained=0`，脚本会自动停止。
这是微软当天的发放上限，不是 bug。拿到 27 分属正常。

---

## 9. 常见问题速查

**Q：日志在哪？**
- 定时任务：`logs/cron-YYYY-MM-DD.log`（含 cron 外层的开始/结束时间）
- 脚本详细日志：`logs/YYYY-MM-DD.log`（自动按天分文件，保留 90 天）

**Q：怎么确认今天跑没跑？**
```bash
ls -lt /root/workspace/microsoft-rewards-script/logs/cron-*.log | head -3
grep "RUN-END" /root/workspace/microsoft-rewards-script/logs/cron-$(date +%F).log
```

**Q：想立刻重跑，但提示"上一轮仍在运行"？**
说明 flock 锁还在。确认没在跑后删锁：
```bash
pgrep -f "dist/index.js" || rm -f /tmp/msr-daily.lock
```

**Q：怎么彻底停掉所有相关进程？**
```bash
pkill -f "dist/index.js"
pkill -f "chrome-linux/chrome"
```

**Q：改了 config.json 要重新构建吗？**
不需要。`config.json` 是运行时读取的；但 `.env` 和 `config.json` 的修改都要**下一次运行**才生效。

**Q：改了 src/ 下的代码呢？**
需要 `npm run build` 重新编译到 `dist/`。

---

## 10. 关键路径索引

| 内容 | 路径 |
|---|---|
| 项目根 | `/root/workspace/microsoft-rewards-script` |
| 账号配置 | `.../.env`（600） |
| 行为配置 | `.../config.json` |
| 登录会话库 | `.../sessions/sessions.db` |
| 定时包装脚本 | `.../scripts/local/daily-run.sh` |
| 交互式登录助手 | `.../scripts/local/interactive-login.cjs` |
| 助手命令下发工具 | `.../scripts/local/mkcmd.cjs` |
| 资源采样脚本 | `.../scripts/local/monitor.sh` |
| 日志目录 | `.../logs/` |
| Chromium 二进制 | `/root/.cache/ms-playwright/chromium-1228/` |

---

## 11. 本机额外改动记录

相对于上游 `V4-china` 原版，本地只做了以下改动：

1. **新增** `src/browser/ResolverPin.ts`
   启动时探测 `rewards.bing.com` 可用 IP，注入 `--host-resolver-rules` 规避 RST。
2. **修改** `src/browser/Browser.ts`
   引入并在 `chromium.launch` 的 args 末尾追加上述规则（3 行）。
3. **新增** `scripts/utils.js` 里的 `buildRewardsResolverArgs()`
   给手动登录 / 会话查看脚本用同一套 IP 固定逻辑。
4. **修改** `scripts/main/manualLogin.js`、`scripts/main/browserSession.js`
   各 1-2 行，接入上述函数。
5. **新增** `scripts/local/` 目录
   部署运维脚本（daily-run.sh / interactive-login.cjs / mkcmd.cjs / monitor.sh），不参与业务逻辑。

**未改动**：任何搜索、任务、积分、登录的原有业务逻辑与默认参数。
