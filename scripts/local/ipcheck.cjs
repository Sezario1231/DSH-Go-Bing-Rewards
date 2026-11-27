const dns = require('node:dns').promises
const https = require('node:https')
;(async () => {
  const now = await dns.resolve4('rewards.bing.com').catch(() => [])
  console.log('当前 DNS 解析:', now.join(', '))
  // 用固定 IP 直连测试 TLS+HTTP（模拟--host-resolver-rules）
  const test = ip => new Promise(res => {
    const t0 = Date.now()
    const req = https.request({ host: ip, port: 443, path: '/', method: 'GET', servername: 'rewards.bing.com', headers: { Host: 'rewards.bing.com' }, timeout: 15000 }, r => {
      let n = 0
      r.on('data', c => n += c.length)
      r.on('end', () => res(`OK status=${r.statusCode} bytes=${n} ${Date.now()-t0}ms`))
    })
    req.on('error', e => res('FAIL ' + e.code + ' ' + (Date.now()-t0) + 'ms'))
    req.on('timeout', () => { req.destroy(); res('TIMEOUT') })
    req.end()
  })
  for (const ip of ['150.171.28.10', '150.171.27.10']) console.log(`  ${ip}:`, await test(ip))
  console.log('结论: 固定 IP 是否仍在 DNS 列表中 →', ['150.171.28.10','150.171.27.10'].every(ip => now.includes(ip)) ? '是（安全）' : '否（需更新）')
})()
