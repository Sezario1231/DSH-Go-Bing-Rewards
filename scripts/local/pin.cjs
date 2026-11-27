const { chromium } = require('patchright')
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36'
const ips = ['150.171.28.10', '150.171.27.10']
;(async () => {
  for (const ip of ips) {
    const b = await chromium.launch({
      headless: false,
      args: ['--no-sandbox','--disable-dev-shm-usage', `--host-resolver-rules=MAP rewards.bing.com ${ip}`, '--disable-features=AsyncDns']
    })
    const ctx = await b.newContext({ userAgent: UA, locale: 'zh-CN' })
    let ok = 0, detail = []
    for (let i = 1; i <= 4; i++) {
      const p = await ctx.newPage()
      try {
        const r = await p.goto('https://rewards.bing.com/', { waitUntil: 'domcontentloaded', timeout: 25000 })
        await p.waitForTimeout(2500)
        const len = await p.evaluate('document.body?document.body.innerText.length:-1').catch(()=>-1)
        if (r && r.status() === 200 && len > 500) { ok++; detail.push(`#${i} OK(${len})`) }
        else detail.push(`#${i} status=${r?r.status():'?'} len=${len}`)
      } catch (e) { detail.push(`#${i} FAIL:${e.message.split('\n')[0].replace(/.*net::/,'')}`) }
      await p.close()
    }
    console.log(`IP ${ip}: 成功 ${ok}/4  |  ${detail.join('  ')}`)
    await b.close()
  }
})().catch(e => console.error('OUTER', e.message.split('\n')[0]))
