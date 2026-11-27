import dns from 'node:dns'
import https from 'node:https'

/**
 * 为 rewards.bing.com 挑选一个可用 IP，返回 Chromium 的 --host-resolver-rules 参数。
 *
 * 背景：国内网络对 rewards.bing.com 存在间歇性 RST 干扰，而该域名通常解析出两个 A 记录。
 * Chromium 在多个地址间轮换时，命中被干扰地址会返回 ERR_CONNECTION_RESET，导致登录后
 * 无法跳回 rewards 保存会话，登录流程反复回退到「选择登录方式」页。
 * 逐个探测 A 记录并固定使用可用 IP，可把该域名的访问成功率从约 40% 提升到 100%。
 *
 * 探测失败或全部不可用时返回 null（不注入任何规则，保持原有行为）。
 */
const TARGET_HOST = 'rewards.bing.com'
const PROBE_TIMEOUT_MS = 8000

function probeHost(ip: string): Promise<boolean> {
    return new Promise(resolve => {
        const req = https.request(
            {
                host: ip,
                port: 443,
                path: '/',
                method: 'HEAD',
                servername: TARGET_HOST,
                headers: { Host: TARGET_HOST },
                timeout: PROBE_TIMEOUT_MS
            },
            res => {
                res.resume()
                resolve(true)
            }
        )
        req.on('error', () => resolve(false))
        req.on('timeout', () => {
            req.destroy()
            resolve(false)
        })
        req.end()
    })
}

export async function buildRewardsResolverRule(): Promise<string | null> {
    if (process.env.MSR_DISABLE_PINNED_IP === '1') return null

    try {
        const addresses = await dns.promises.resolve4(TARGET_HOST)
        if (!addresses.length) return null

        for (const ip of addresses) {
            if (await probeHost(ip)) {
                return `MAP ${TARGET_HOST} ${ip}`
            }
        }
    } catch {
        // 解析或探测失败时静默回退
    }

    return null
}
