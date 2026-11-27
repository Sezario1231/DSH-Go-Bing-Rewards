const { chromium } = require('patchright')
;(async () => {
  const b = await chromium.launch({ headless: false, args: ['--no-sandbox', '--disable-dev-shm-usage'] })
  const p = await b.newPage({ viewport: { width: 412, height: 915 } })
  p.on('console', m => console.log('[console]', m.text().slice(0, 100)))
  try {
    await p.goto('https://rewards.bing.com/auth/login', { waitUntil: 'commit', timeout: 60000 })
    console.log('goto OK(commit), url=', p.url())
  } catch (e) { console.log('goto fail:', e.message.split('\n')[0]) }
  try {
    await p.waitForTimeout(8000)
    console.log('evaluate 1+1 =', await p.evaluate('1+1'))
    console.log('url now =', p.url())
    console.log('body len =', await p.evaluate('document.body ? document.body.innerText.length : -1'))
  } catch (e) { console.log('evaluate fail:', e.message.split('\n')[0]) }
  try {
    const buf = await p.screenshot({ timeout: 15000 })
    require('fs').writeFileSync('logs/shots/probe.png', buf)
    console.log('screenshot OK bytes=', buf.length)
  } catch (e) { console.log('screenshot fail:', e.message.split('\n')[0]) }
  await b.close()
})().catch(e => { console.error('OUTER FAIL', e.message.split('\n')[0]) })
