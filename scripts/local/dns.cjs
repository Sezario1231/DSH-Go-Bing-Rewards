const dns = require('node:dns').promises
;(async () => {
  for (const host of ['rewards.bing.com', 'login.live.com', 'www.bing.com']) {
    try {
      const a = await dns.resolve4(host)
      console.log(host, '→ A:', a.join(', '))
    } catch (e) { console.log(host, '→ 解析失败:', e.code) }
  }
})()
