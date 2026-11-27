const { chromium } = require('patchright')
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36'
;(async () => {
  const b = await chromium.launch({ headless: false, args: ['--no-sandbox','--disable-dev-shm-usage'] })
  const ctx = await b.newContext({ userAgent: UA, locale: 'zh-CN' })
  for (let i = 1; i <= 5; i++) {
    const p = await ctx.newPage()
    const t0 = Date.now()
    let s = ''
    try {
      const r = await p.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 30000 })
      await p.waitForTimeout(3000)
      const len = await p.evaluate('document.body?document.body.innerText.length:-1').catch(()=>-1)
      s = `OK status=${r?r.status():'?'} bodyLen=${len} title="${(await p.title()).slice(0,25)}"`
    } catch (e) { s = 'FAIL ' + e.message.split('\n')[0].slice(0,45) }
    console.log(`第${i}次 ${Date.now()-t0}ms  ${s}`)
    await p.close()
    await new Promise(r => setTimeout(r, 4000))
  }
  await b.close()
})().catch(e => console.error('OUTER', e.message.split('\n')[0]))
