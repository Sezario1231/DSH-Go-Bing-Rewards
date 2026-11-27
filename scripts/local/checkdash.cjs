const { chromium } = require('patchright')
const path = require('path')
const ROOT = path.resolve(__dirname, '../..')
const { loadSession } = require(path.join(ROOT, 'dist/util/SessionStore.js'))

;(async () => {
    const email = process.argv[2]
    const mobile = process.argv[3] !== 'desktop'
    const sess = loadSession(path.join(ROOT, 'sessions'), email, mobile)
    if (!sess?.storageState) {
        console.log('无会话')
        process.exit(1)
    }
    const b = await chromium.launch({
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-dev-shm-usage',
            '--host-resolver-rules=MAP rewards.bing.com 150.171.27.10'
        ]
    })
    const ua = mobile
        ? 'Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/158.0.0.0 Mobile Safari/537.36 EdgA/158.0.4370.33'
        : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0'
    const ctx = await b.newContext({
        userAgent: ua,
        viewport: mobile ? { width: 412, height: 915 } : { width: 1280, height: 800 },
        locale: 'zh-CN',
        storageState: sess.storageState
    })
    const p = await ctx.newPage()
    const errs = []
    p.on('requestfailed', r => {
        const u = r.url()
        if (/rewards\.bing/.test(u)) errs.push(u.slice(0, 60) + ' :: ' + (r.failure()?.errorText || ''))
    })

    await p
        .goto('https://rewards.bing.com/dashboard', { waitUntil: 'domcontentloaded', timeout: 60000 })
        .catch(e => console.log('goto:', e.message.split('\n')[0]))

    for (const wait of [6000, 8000, 10000]) {
        await p.waitForTimeout(wait)
        const has = await p.evaluate(() => !!document.querySelector('section#dailyset')).catch(() => null)
        console.log(`等待累计后 dailyset=${has}`)
        if (has) break
    }

    const info = await p
        .evaluate(() => ({
            url: location.href.slice(0, 100),
            title: document.title,
            hasDailyset: !!document.querySelector('section#dailyset'),
            sections: [...document.querySelectorAll('section')].map(s => s.id).filter(Boolean).slice(0, 20),
            bodyLen: document.body ? document.body.innerText.length : -1,
            bodyHead: document.body ? document.body.innerText.slice(0, 250) : ''
        }))
        .catch(e => ({ err: e.message }))

    console.log(JSON.stringify(info, null, 1))
    console.log('失败请求:', errs.length ? errs.slice(0, 3).join(' | ') : '无')
    await p
        .screenshot({ path: path.join(ROOT, 'logs/shots/dash-' + (mobile ? 'm' : 'd') + '.png'), timeout: 25000, animations: 'disabled' })
        .catch(e => console.log('shot:', e.message.split('\n')[0]))
    await b.close()
})().catch(e => console.error('OUTER', e.message.split('\n')[0]))
