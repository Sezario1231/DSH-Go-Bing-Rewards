const { chromium } = require('patchright')
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36'
const ARGS = ['--no-sandbox','--disable-dev-shm-usage',
  '--host-resolver-rules=MAP rewards.bing.com 150.171.28.10, MAP rewards.bing.com 150.171.27.10']
;(async () => {
  const b = await chromium.launch({ headless: true, args: ARGS })
  const ctx = await b.newContext({ userAgent: UA, locale: 'zh-CN' })
  let ok = 0
  for (let i = 1; i <= 8; i++) {
    const p = await ctx.newPage()
    try {
      const r = await p.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 20000 })
      await p.waitForTimeout(1500)
      const len = await p.evaluate('document.body?document.body.innerText.length:-1').catch(()=>-1)
      if (r?.status() === 200 && len > 500) { ok++; process.stdout.write(`#${i}✓ `) } else process.stdout.write(`#${i}(${r?.status()},${len}) `)
    } catch (e) { process.stdout.write(`#${i}✗ `) }
    await p.close()
  }
  console.log(`\nheadless 成功率: ${ok}/8`)
  await b.close()
})().catch(e => console.error('OUTER', e.message.split('\n')[0]))
