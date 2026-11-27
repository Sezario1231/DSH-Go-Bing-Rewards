# 账号管理（DSH Go 手机部署）

所有操作在 **DSH Go 原生面板 →「账号管理」** 里点按钮即可；也可以用下面的终端命令。
凭证（邮箱、验证码、密码）**只在对话中由你提供，AI 填入浏览器**；不会被打印到日志或写进除 `.env` / `sessions.db` 以外的文件。

## 1. 删除账号（简单）

面板「账号管理」→ 选择账号 → 删除。或：

```bash
bash scripts/local/account-remove.sh 2      # 删除账号 2
```

- 只把 `.env` 里 `ACCOUNT_2_*` 整组加 `#` 注释，**不读取、不输出凭证**，原文件自动备份为 `.env.bak.*`
- 至少保留 1 个账号；登录态（`sessions/`）不删，如需彻底清除请手动删除对应会话文件
- 下次启动生效

## 2. 串行 / 并行切换（简单）

面板「账号管理」→ 串行 / 并行 2 / 并行 3。或：

```bash
bash scripts/local/parallel-set.sh          # 查看当前
bash scripts/local/parallel-set.sh 1        # 串行（默认）
bash scripts/local/parallel-set.sh 2        # 并行，最多 2 个同时跑
```

- `clusters=1` 串行（账号逐个跑，间隔 `accountDelay`）；`clusters=N` 最多 N 个同时跑
- 建议并行不超过 **3**、账号总数不超过 **6**；配置自动备份为 `config.json.bak.*`
- 下次启动生效；正在跑的任务不受影响

## 3. 添加账号（AI 辅助，邮箱验证码优先）

> 邮箱验证码由你在对话中贴给 AI；AI 通过浏览器操作填入。密码只在验证码不可用时作为兜底，同样由你提供。

### 步骤

1. **生成空白模板**
   ```bash
   bash scripts/local/account-add.sh prepare
   ```
   输出下一个可用编号（如 `账号 3`），并在 `.env` 追加空的 `ACCOUNT_3_*`。

2. **启动登录浏览器**
   ```bash
   bash scripts/local/account-add.sh login
   ```
   等待 `/tmp/msr/ready` 出现。

3. **AI 引导登录**（通过 `login-ctl.sh` 控制浏览器）：
   ```bash
   bash scripts/local/login-ctl.sh goto 'https://rewards.bing.com/'
   bash scripts/local/login-ctl.sh shot step1        # 截图，AI 识别登录页
   bash scripts/local/login-ctl.sh clicktext '使用邮箱登录'   # 或点登录入口
   bash scripts/local/login-ctl.sh fill '#username' '你的邮箱'  # 邮箱由你提供
   bash scripts/local/login-ctl.sh clicktext '发送验证码'
   # 你把收到的验证码贴给 AI：
   bash scripts/local/login-ctl.sh fill '#code' '验证码'
   bash scripts/local/login-ctl.sh clicktext '登录'
   bash scripts/local/login-ctl.sh shot logged       # 确认已登录
   bash scripts/local/login-ctl.sh save '你的邮箱' mobile   # 保存登录态
   bash scripts/local/login-ctl.sh quit
   ```

4. **补齐 `.env`**：把 `ACCOUNT_3_EMAIL` 填成你的邮箱（其余字段按需）。
   AI 不会把邮箱/验证码写进对话日志以外的文件。

5. **验证**：面板「账号管理」应出现新账号且状态为「启用」；或运行
   ```bash
   bash scripts/local/accounts-list.sh
   ```

6. **兜底密码登录**：若邮箱验证码不可用，在登录页选"使用密码登录"，由你提供密码，AI 填入并提交。

### 说明

- 首次登录后会话保存在 `sessions.db`，日常任务自动复用，之后不再需要验证码
- 若登录遇到通行密钥/双重验证等无法自动完成的步骤，请使用 DSH 的「交给你操作」(handoff) 由你亲自完成
- 凭证安全：AI 只把凭证写进临时命令文件 `/tmp/msr/cmd.json` 并立即被浏览器消费，不落盘到对话历史以外的持久文件

## 安全约定

- 添加/删除账号都只改 `.env` 与 `config.json`，两者均自动备份
- 任何情况下都不在对话、日志、截图文件名中存放密码/TOTP/验证码明文
- 手机屏幕小，优先用面板按钮操作
