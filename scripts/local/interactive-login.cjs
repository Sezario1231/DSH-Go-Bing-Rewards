/**
 * 交互式登录助手（仅部署期使用，不参与日常调度）
 *
 * 用途：容器内无法自动完成的登录（通行密钥 / 邮箱验证码 / 2FA），
 * 由本脚本保持浏览器常驻，通过命令文件与外部逐步交互，登录成功后
 * 把 storageState 写入 sessions/sessions.db，供 npm start 直接复用。
 *
 * 命令通过 /tmp/msr/cmd.json 下发，结果写入 /tmp/msr/out.json：
 *   {"op":"shot","name":"step1"}                 截图到 logs/shots/step1.png
 *   {"op":"click","sel":"..."}                   点击 CSS 选择器
 *   {"op":"clicktext","text":"发送验证码"}        按可见文字点击
 *   {"op":"fill","sel":"...","value":"..."}      填写输入框
 *   {"op":"type","value":"..."}                  向当前焦点输入
 *   {"op":"key","key":"Enter"}                   按键
 *   {"op":"goto","url":"..."}                    导航
 *   {"op":"eval","js":"..."}                     执行表达式
 *   {"op":"save","email":"...","platform":"mobile"}  保存会话
 *   {"op":"quit"}                                退出
 */
const fs = require('node:fs')
const path = require('node:path')
const { chromium } = require('patchright')

const DIR = '/tmp/msr'
const CMD = path.join(DIR, 'cmd.json')
const OUT = path.join(DIR, 'out.json')
const FLAG = path.join(DIR, 'ready')
const ROOT = path.resolve(__dirname, '../..')
const SHOTS = path.join(ROOT, 'logs/shots')

const MOBILE_UA =
    'Mozilla/5.0 (Linux; Android 15; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/158.0.0.0 Mobile Safari/537.36 EdgA/158.0.4370.33'

fs.mkdirSync(DIR, { recursive: true })
fs.mkdirSync(SHOTS, { recursive: true })
fs.rmSync(CMD, { force: true })
fs.rmSync(FLAG, { force: true })

function writeOut(obj) {
    fs.writeFileSync(OUT, JSON.stringify(obj, null, 2))
}

async function saveSession(page, email, platform) {
    const { saveStorageState } = require(path.join(ROOT, 'dist/util/SessionStore.js'))
    const storageState = await page.context().storageState()
    saveStorageState(path.join(ROOT, 'sessions'), email, platform !== 'desktop', storageState)
    return { cookies: storageState.cookies.length, origins: storageState.origins.length }
}

;(async () => {
    const browser = await chromium.launch({
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-blink-features=AutomationControlled',
            '--disable-save-password-bubble',
            '--mute-audio',
            '--window-size=412,915',
            '--host-resolver-rules=MAP rewards.bing.com 150.171.27.10, MAP rewards.bing.com 150.171.28.10'
        ]
    })
    let context = await browser.newContext({
        userAgent: MOBILE_UA,
        viewport: { width: 412, height: 915 },
        locale: 'zh-CN'
    })
    let page = await context.newPage()

    writeOut({ ok: true, msg: 'browser ready' })
    fs.writeFileSync(FLAG, '1')

    let running = true
    while (running) {
        let cmd = null
        try {
            cmd = JSON.parse(fs.readFileSync(CMD, 'utf8'))
        } catch {
            await new Promise(r => setTimeout(r, 400))
            continue
        }
        fs.rmSync(CMD, { force: true })

        try {
            let result = {}
            switch (cmd.op) {
                case 'shot': {
                    const file = path.join(SHOTS, `${cmd.name || 'shot'}.png`)
                    await page.screenshot({ path: file, timeout: 25000, animations: 'disabled', caret: 'initial' })
                    result = { file, url: page.url(), title: await page.title() }
                    break
                }
                case 'goto': {
                    await page.goto(cmd.url, { waitUntil: 'domcontentloaded', timeout: 60000 })
                    await page.waitForTimeout(cmd.wait ?? 3000)
                    result = { url: page.url(), title: await page.title() }
                    break
                }
                case 'click': {
                    await page.click(cmd.sel, { timeout: cmd.timeout ?? 15000 })
                    await page.waitForTimeout(cmd.wait ?? 2500)
                    result = { url: page.url() }
                    break
                }
                case 'clicktext': {
                    const loc = page.getByText(cmd.text, { exact: cmd.exact ?? false }).first()
                    await loc.click({ timeout: cmd.timeout ?? 15000 })
                    await page.waitForTimeout(cmd.wait ?? 2500)
                    result = { url: page.url() }
                    break
                }
                case 'fill': {
                    await page.fill(cmd.sel, cmd.value, { timeout: cmd.timeout ?? 15000 })
                    result = { filled: true }
                    break
                }
                case 'type': {
                    await page.keyboard.type(cmd.value, { delay: cmd.delay ?? 60 })
                    result = { typed: true }
                    break
                }
                case 'key': {
                    await page.keyboard.press(cmd.key)
                    await page.waitForTimeout(cmd.wait ?? 2500)
                    result = { url: page.url() }
                    break
                }
                case 'eval': {
                    result = { value: await page.evaluate(cmd.js) }
                    break
                }
                case 'setua': {
                    await context.setExtraHTTPHeaders({ 'User-Agent': cmd.ua })
                    await context.addInitScript(ua => {
                        Object.defineProperty(navigator, 'userAgent', { get: () => ua })
                    }, cmd.ua)
                    await context.close()
                    context = await browser.newContext({
                        userAgent: cmd.ua,
                        viewport: cmd.viewport || { width: 412, height: 915 },
                        locale: 'zh-CN'
                    })
                    page = await context.newPage()
                    result = { ua: cmd.ua }
                    break
                }
                case 'nofido': {
                    await context.addInitScript(() => {
                        try {
                            if (navigator.credentials) {
                                navigator.credentials.get = () =>
                                    Promise.reject(new DOMException('NotAllowedError', 'NotAllowedError'))
                                navigator.credentials.create = () =>
                                    Promise.reject(new DOMException('NotAllowedError', 'NotAllowedError'))
                            }
                            if (window.PublicKeyCredential) {
                                window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = () =>
                                    Promise.resolve(false)
                                window.PublicKeyCredential.isConditionalMediationAvailable = () =>
                                    Promise.resolve(false)
                            }
                        } catch (e) {}
                    })
                    result = { nofido: true }
                    break
                }
                case 'loadstate': {
                    const { loadSession } = require(path.join(ROOT, 'dist/util/SessionStore.js'))
                    const sess = loadSession(path.join(ROOT, 'sessions'), cmd.email, cmd.fromMobile !== false)
                    if (!sess?.storageState) {
                        result = { loaded: false, error: 'no saved session' }
                        break
                    }
                    await context.close()
                    context = await browser.newContext({
                        userAgent: cmd.ua || MOBILE_UA,
                        viewport: cmd.viewport || { width: 412, height: 915 },
                        locale: 'zh-CN',
                        storageState: sess.storageState
                    })
                    page = await context.newPage()
                    result = { loaded: true, cookies: sess.storageState.cookies.length }
                    break
                }
                case 'save': {
                    const info = await saveSession(page, cmd.email, cmd.platform || 'mobile')
                    result = { saved: true, ...info }
                    break
                }
                case 'quit': {
                    result = { quitting: true }
                    running = false
                    break
                }
                default:
                    result = { error: 'unknown op: ' + cmd.op }
            }
            writeOut({ ok: true, op: cmd.op, ...result })
        } catch (e) {
            writeOut({ ok: false, op: cmd.op, error: e.message.split('\n')[0] })
        }
    }

    await browser.close()
    fs.rmSync(FLAG, { force: true })
    writeOut({ ok: true, msg: 'exited' })
    process.exit(0)
})().catch(e => {
    writeOut({ ok: false, fatal: e.message })
    process.exit(1)
})
