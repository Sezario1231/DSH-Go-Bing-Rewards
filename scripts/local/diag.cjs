const { chromium } = require('patchright')
const UA_DESKTOP = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0'
;(async () => {
  const b = await chromium.launch({ headless: false, args: ['--no-sandbox','--disable-dev-shm-usage','--disable-blink-features=AutomationControlled'] })
  const results = []
  const tests = [
    ['login.live.com', 'https://login.live.com/'],
    ['rewards.bing.com', 'https://rewards.bing.com/'],
    ['www.bing.com', 'https://www.bing.com/'],
    ['account.microsoft.com', 'https://account.microsoft.com/'],
  ]
  for (const [name, url] of tests) {
    const ctx = await b.newContext({ userAgent: UA_DESKTOP, locale: 'zh-CN' })
    const p = await ctx.newPage()
    let blocked = []
    p.on('requestfailed', r => blocked.push(r.url().slice(0, 60) + ' :: ' + (r.failure()?.errorText || '')))
    const t0 = Date.now()
    let status = '?'
    try {
      const resp = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 })
      status = resp ? resp.status() : 'no-response'
    } catch (e) { status = 'ERR ' + e.message.split('\n')[0].slice(0, 50) }
    const ms = Date.now() - t0
    await p.waitForTimeout(6000)
    let bodyLen = -1, title = ''
    try { bodyLen = await p.evaluate('document.body?document.body.innerText.length:-1'); title = await p.title() } catch {}
    results.push({ name, status, ms, bodyLen, title: title.slice(0,30), failed: blocked.length, sample: blocked.slice(0,2).join(' | ') })
    await ctx.close()
  }
  console.table(results)
  await b.close()
})().catch(e => console.error('FAIL', e.message.split('\n')[0]))
