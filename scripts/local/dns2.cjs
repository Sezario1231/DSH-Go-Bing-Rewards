const dns = require('node:dns').promises
;(async () => {
  const all = await dns.resolve4('rewards.bing.com', { ttl: true }).catch(()=>[])
  console.log('全部记录(含TTL):', JSON.stringify(all))
})()
