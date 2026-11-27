const { chromium } = require('patchright')
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36'
;(async () => {
  const b = await chromium.launch({
    headless: false,
    args: ['--no-sandbox','--disable-dev-shm-usage','--host-resolver-rules=MAP rewards.bing.com 150.171.28.10']
  })
  const ctx = await b.newContext({ userAgent: UA, locale: 'zh-CN' })
  const p = await ctx.newPage()
  const bad = []
  p.on('requestfailed', r => { const u=r.url(); if(/rewards\.bing\.com|login\.live\.com/.test(u)) bad.push(u.slice(0,70)+' :: '+(r.failure()?.errorText||'')) })
  console.log('→ 打开 rewards 登录入口')
  try {
    await p.goto('https://rewards.bing.com/auth/login', { waitUntil: 'domcontentloaded', timeout: 45000 })
  } catch(e) { console.log('goto err:', e.message.split('\n')[0]) }
  await p.waitForTimeout(8000)
  console.log('当前URL:', p.url().slice(0, 90))
  console.log('标题:', (await p.title()).slice(0, 40))
  console.log('正文长度:', await p.evaluate('document.body?document.body.innerText.length:-1').catch(()=>-1))
  await p.screenshot({ path: 'logs/shots/chain1.png' })
  const inputs = await p.$$eval('input', els => els.map(e => ({ type:e.type, name:e.name||'', id:e.id||'', testid:e.dataset.testid||'', ph:e.placeholder||'' })).slice(0,8))
  const btns = await p.$$eval('button,[role="button"]', els => els.map(e => ({ testid:e.dataset.testid||'', text:(e.innerText||'').trim().slice(0,25) })).filter(x=>x.text||x.testid).slice(0,8))
  console.log('输入框:', JSON.stringify(inputs))
  console.log('按钮:', JSON.stringify(btns))
  console.log('相关失败请求:', bad.length ? bad.join(' | ') : '无')
  await b.close()
})().catch(e => console.error('OUTER', e.message.split('\n')[0]))
