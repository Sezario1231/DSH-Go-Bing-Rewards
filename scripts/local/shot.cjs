const { chromium } = require('patchright')
;(async () => {
  const b = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] })
  const p = await b.newPage({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2 })
  for (let i = 1; i <= 3; i++) {
    try {
      await p.goto('https://rewards.bing.com/auth/login', { waitUntil: 'domcontentloaded', timeout: 45000 })
      break
    } catch (e) {
      console.log(`尝试 ${i} 失败: ${e.message.split('\n')[0]}`)
      await p.waitForTimeout(3000)
    }
  }
  await p.waitForTimeout(5000)
  await p.screenshot({ path: 'logs/shots/login-page.png' })
  console.log('URL:', p.url())
  console.log('TITLE:', await p.title())
  const items = await p.$$eval('button, a[role="button"], input', els =>
    els.slice(0, 20).map(e => ({
      tag: e.tagName.toLowerCase(),
      testid: e.getAttribute('data-testid') || '',
      text: (e.innerText || e.value || '').trim().slice(0, 30)
    })).filter(x => x.text || x.testid)
  )
  console.log(JSON.stringify(items, null, 1))
  await b.close()
})().catch(e => { console.error('FAIL', e.message.split('\n')[0]); process.exit(1) })
