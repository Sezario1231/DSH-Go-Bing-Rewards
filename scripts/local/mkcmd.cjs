// 用法: node scripts/local/mkcmd.cjs '{"op":"shot","name":"x"}'  [等待秒数]
const fs=require('fs')
const DIR='/tmp/msr'
fs.mkdirSync(DIR,{recursive:true})
const cmd=process.argv[2]
const wait=Number(process.argv[3]||30)
fs.rmSync(DIR+'/out.json',{force:true})
fs.writeFileSync(DIR+'/cmd.json',cmd)
const t0=Date.now()
const iv=setInterval(()=>{
  if(fs.existsSync(DIR+'/out.json')){
    clearInterval(iv)
    try{ console.log(fs.readFileSync(DIR+'/out.json','utf8').trim()) }catch(e){ console.log('read err') }
    process.exit(0)
  }
  if(Date.now()-t0>wait*1000){ clearInterval(iv); console.log('{"ok":false,"error":"timeout waiting for out.json"}'); process.exit(1) }
},250)
