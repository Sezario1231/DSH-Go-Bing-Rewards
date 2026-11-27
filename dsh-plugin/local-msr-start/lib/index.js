// 积分助手：输入框胶囊一键启动 + 全部功能面板实时积分明细（均不经过 AI）
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

export const name = 'local-msr-start'

// 从本插件文件位置推导仓库根目录，避免硬编码绝对路径：
// <repo>/dsh-plugin/local-msr-start/lib/index.js -> repo = 上溯三级
const REPO = dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url)))))
const START = join(REPO, 'scripts/local/start.sh')
const STOP = join(REPO, 'scripts/local/stop-scheduler.sh')
const POINTS = join(REPO, 'scripts/local/points-json.sh')
const SUMMARY = join(REPO, 'scripts/local/points-summary.sh')
const HEALTH = join(REPO, 'scripts/local/health-json.sh')

const STATUS = { done: ['已完成', 'good'], running: ['运行中', 'info'], pending: ['未开始', 'muted'] }
const CAT = { search: '搜索', checkin: '签到', read: '阅读', other: '其他' }

function readHealth() {
  try {
    const out = execFileSync('bash', [HEALTH], {
      encoding: 'utf8', timeout: 10000,
      env: { ...process.env, TZ: 'Asia/Shanghai' },
    })
    return JSON.parse(out.trim())
  } catch {
    return { status: 'unknown', label: '状态未知', tone: 'muted', detail: '健康检测脚本读取失败' }
  }
}

function readPoints() {
  try {
    const out = execFileSync('bash', [POINTS], {
      encoding: 'utf8', timeout: 10000,
      env: { ...process.env, TZ: 'Asia/Shanghai' },
    })
    const d = JSON.parse(out.trim())
    const as = d.accounts || []
    const fmt = (n) => (n && n > 0 ? String(n) : '—')
    const nz = (v) => (v ? v : '—')

    const num = (a, k) => (a ? a[k] || 0 : 0)
    const a0 = as[0] || {}, a1 = as[1] || {}
    const totalToday = num(a0, 'today') + num(a1, 'today')
    const totalBal = num(a0, 'now') + num(a1, 'now')

    // 最近明细表格行
    const rows = []
    for (const a of as) {
      for (const x of (a.detail || [])) {
        rows.push([x.t || '', a.account, CAT[x.cat] || x.cat || '', `+${x.pts}`, String(x.bal)])
      }
    }
    rows.reverse()

    // 近几天 / 月 / 风控汇总
    let dayRows = [], monthRows = [], risk0 = [], risk1 = []
    try {
      const s = JSON.parse(execFileSync('bash', [SUMMARY], {
        encoding: 'utf8', timeout: 10000,
        env: { ...process.env, TZ: 'Asia/Shanghai' },
      }).trim())
      dayRows = (s.days || []).filter((x) => x.delta > 0 || x.errors > 0).map((x) => [
        x.date.slice(5), x.account, `+${x.delta}`, `${x.search}/${x.read}/${x.checkin}`, String(x.errors),
      ]).reverse()
      monthRows = (s.months || []).map((x) => [
        x.month, x.account, `+${x.delta}`, `${x.search}/${x.read}/${x.checkin}`,
      ])
      const rk = (acct) => {
        const ds = (s.days || []).filter((x) => x.account === acct)
        const sum = (k) => ds.reduce((t, x) => t + (x[k] || 0), 0)
        return [
          ['检测次数', String(sum('checks'))],
          ['疑似受限', String(sum('restricted'))],
          ['bot 标记', String(sum('bot'))],
          ['活动折叠', String(sum('fold'))],
          ['用户警告', String(sum('warn'))],
          ['登录/验证', String(sum('login'))],
          ['错误数', String(sum('errors'))],
        ]
      }
      risk0 = rk(a0.account)
      risk1 = rk(a1.account)
    } catch { /* 汇总读取失败不影响主面板 */ }

    const kv = (a) => [
      ['当前余额', fmt(num(a, 'now'))],
      ['今日新增', fmt(num(a, 'today'))],
      ['搜索得分', fmt(num(a, 'search'))],
      ['阅读得分', fmt(num(a, 'read'))],
      ['签到得分', fmt(num(a, 'checkin'))],
      ['其他得分', fmt(num(a, 'other'))],
      ['错误数', fmt(num(a, 'errors'))],
      ['状态', (STATUS[a.status] || ['—', 'muted'])[0]],
      ['最后活动', nz(a.lastTs)],
    ]

    const h = readHealth()
    const hIcon = { done: '✅', running: '⏳', interrupted: '⚠️', missed: '🔴', pending: '🕒' }[h.status] || 'ℹ️'

    return {
      date: d.date || '',
      totalToday: fmt(totalToday),
      totalBal: fmt(totalBal),
      a0name: nz(a0.account),
      a1name: nz(a1.account),
      a0kv: kv(a0),
      a1kv: kv(a1),
      a0state: (STATUS[a0.status] || ['—', 'muted'])[0],
      a1state: (STATUS[a1.status] || ['—', 'muted'])[0],
      a0tone: (STATUS[a0.status] || ['—', 'muted'])[1],
      a1tone: (STATUS[a1.status] || ['—', 'muted'])[1],
      rows,
      dayRows, monthRows, risk0, risk1,
      health: h,
      healthText: `${hIcon} ${h.label}`,
      healthTone: h.tone || 'muted',
      healthDetail: h.detail || '',
      updated: new Date().toLocaleTimeString('zh-CN', { hour12: false, timeZone: 'Asia/Shanghai' }),
    }
  } catch {
    return { date: '', totalToday: '—', totalBal: '—', a0kv: [], a1kv: [], rows: [],
      healthText: 'ℹ️ 状态未知', healthTone: 'muted', healthDetail: '健康检测读取失败', updated: '读取失败' }
  }
}

export function apply(ctx) {
  ctx.inject(['dshGo'], (ctx) => {
    ctx.dshGo.on('start-rewards', (scope, event) => {
      const zh = !String(event?.locale || '').startsWith('en')
      try {
        const out = execFileSync('bash', [START], {
          encoding: 'utf8', timeout: 15000,
          env: { ...process.env, TZ: 'Asia/Shanghai' },
        })
        if (out.includes('已在运行')) return { toast: zh ? '积分任务已在运行中' : 'Already running' }
        return { toast: zh ? '✅ 积分任务已启动' : '✅ Started' }
      } catch (err) {
        const msg = String(err?.stderr || err?.message || '').slice(0, 60)
        return { toast: zh ? `启动失败：${msg}` : `Failed: ${msg}` }
      }
    })

    ctx.dshGo.on('stop-rewards', (scope, event) => {
      const zh = !String(event?.locale || '').startsWith('en')
      try {
        const out = execFileSync('bash', [STOP], {
          encoding: 'utf8', timeout: 15000,
        })
        return { toast: zh ? `已停止（${(out || '').trim().slice(0, 30)}）` : `Stopped (${(out || '').trim().slice(0, 30)})` }
      } catch (err) {
        const msg = String(err?.stderr || err?.message || '').slice(0, 60)
        return { toast: zh ? `停止失败：${msg}` : `Failed: ${msg}` }
      }
    })

    ctx.dshGo.panel('points-board', {
      view: (scope, caps) => {
        const zh = !String(caps?.locale || '').startsWith('en')
        return {
          v: 2, type: 'stack', title: zh ? '积分明细' : 'Points', accent: 'teal',
          children: [
            { type: 'text', text: { $: 'data.date' }, style: { size: 'caption' } },
            { type: 'callout', text: { $: 'data.healthText' }, tone: { $: 'data.healthTone' } },
            { type: 'text', text: { $: 'data.healthDetail' }, style: { size: 'caption' } },
            { type: 'actions', items: [
              { label: zh ? '启动积分' : 'Start', action: 'start', icon: 'play' },
              { label: zh ? '停止' : 'Stop', action: 'stop', icon: 'stop' },
              { label: zh ? '刷新' : 'Refresh', action: 'refresh', icon: 'refresh' },
            ] },
            { type: 'row', children: [
              { type: 'metric', label: zh ? '今日新增' : 'Today', value: { $: 'data.totalToday' }, tone: 'good' },
              { type: 'metric', label: zh ? '总余额' : 'Balance', value: { $: 'data.totalBal' } },
            ] },
            { type: 'accordion', expanded: true, items: [
              { label: zh ? '📊 账号一' : '📊 Account 1', children: [
                { type: 'keyValue', items: { $: 'data.a0kv' } },
              ] },
              { label: zh ? '📊 账号二' : '📊 Account 2', children: [
                { type: 'keyValue', items: { $: 'data.a1kv' } },
              ] },
              { label: zh ? '📋 最近得分明细' : '📋 Recent points', children: [
                { type: 'table', columns: [zh ? '时间' : 'Time', zh ? '账号' : 'Account', zh ? '项目' : 'Item', zh ? '得分' : 'Pts', zh ? '余额' : 'Bal'], rows: { $: 'data.rows' } },
              ] },
              { label: zh ? '📅 近几天日明细' : '📅 Daily', children: [
                { type: 'table', columns: [zh ? '日期' : 'Date', zh ? '账号' : 'Account', zh ? '新增' : 'Gain', zh ? '搜/读/签' : 'S/R/C', zh ? '错' : 'Err'], rows: { $: 'data.dayRows' } },
                { type: 'text', text: zh ? '分类为日志统计，仅供参考；新增以余额差为准' : 'Categories from logs; gain = balance diff', style: { size: 'caption' } },
              ] },
              { label: zh ? '🗓️ 月明细' : '🗓️ Monthly', children: [
                { type: 'table', columns: [zh ? '月份' : 'Month', zh ? '账号' : 'Account', zh ? '新增' : 'Gain', zh ? '搜/读/签' : 'S/R/C'], rows: { $: 'data.monthRows' } },
              ] },
              { label: zh ? '🛡️ 风控情况' : '🛡️ Risk', children: [
                { type: 'text', text: zh ? '账号一' : 'Account 1', style: { size: 'caption' } },
                { type: 'keyValue', items: { $: 'data.risk0' } },
                { type: 'text', text: zh ? '账号二' : 'Account 2', style: { size: 'caption' } },
                { type: 'keyValue', items: { $: 'data.risk1' } },
                { type: 'text', text: zh ? '仅记录，不阻断自动运行' : 'Record only; never blocks automation', style: { size: 'caption' } },
              ] },
              { label: zh ? '⚙️ 运行状态' : '⚙️ Status', children: [
                { type: 'text', text: { $: 'data.updated' }, style: { size: 'caption' } },
                { type: 'actions', items: [{ label: zh ? '立即刷新' : 'Refresh', action: 'refresh', icon: 'refresh' }] },
              ] },
            ] },
          ],
        }
      },
      data: (scope, emit, caps) => {
        const tick = () => emit(readPoints())
        tick()
        const timer = setInterval(tick, 15000)
        return () => clearInterval(timer)
      },
      actions: {
        refresh: () => ({ refresh: true, toast: '已刷新' }),
        start: () => {
          try {
            const out = execFileSync('bash', [START], { encoding: 'utf8', timeout: 15000 })
            return { refresh: true, toast: (out || '').trim().slice(0, 60) || '已启动积分' }
          } catch {
            return { refresh: true, toast: '启动失败，请查看日志' }
          }
        },
        stop: () => {
          try {
            const out = execFileSync('bash', [STOP], { encoding: 'utf8', timeout: 15000 })
            return { refresh: true, toast: (out || '').trim().slice(0, 60) || '已停止' }
          } catch {
            return { refresh: true, toast: '停止失败，请手动检查' }
          }
        },
      },
    })
  })
}
