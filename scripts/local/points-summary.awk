function getv(line, key,   pat, s) {
    pat = key "=[^ |]+"
    if (match(line, pat)) { s = substr(line, RSTART, RLENGTH); sub(/^[^=]*=/, "", s); return s }
    return ""
}
function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
{
    line = $0
    acct = ""
    if (match(line, /\[[0-9][0-9]+\]/)) acct = substr(line, RSTART+1, RLENGTH-2)
    else if (match(line, /\[Sezario[0-9]+\]/)) acct = substr(line, RSTART+1, RLENGTH-2)
    if (acct == "") next

    # RUN-END 汇总行的 现余额 是两账号合计，不是单账号余额，跳过避免污染
    if (line ~ /\[RUN-END\]/) next

    # 日期：优先从文件名 FILENAME 取 cron-YYYY-MM-DD.log
    day = ""
    if (match(FILENAME, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) day = substr(FILENAME, RSTART, RLENGTH)
    month = substr(day, 1, 7)
    key = day SUBSEP acct
    mkey = month SUBSEP acct

    gained = 0; bal = 0
    if (match(line, /获得积分=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); gained = s+0 }
    else if (match(line, /pointsGained=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); gained = s+0 }
    if (match(line, /当前余额=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }
    else if (match(line, /现余额=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }
    else if (match(line, /currentBalance=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }

    cat = "other"
    if (line ~ /\[SEARCH-BING\]/) cat = "search"
    else if (line ~ /DAILY-CHECK-IN/ || line ~ /签到/) cat = "checkin"
    else if (line ~ /\[READ-TO-EARN\]/) cat = "read"
    else if (line ~ /\[FLOW\]/) cat = "flow"

    if (!seenD[key]) { seenD[key]=1; dayOrder[++dn]=key; dFirst[key]=0; dLast[key]=0 }
    if (!seenM[mkey]) { seenM[mkey]=1; monOrder[++mn]=mkey }
    if (!seenA[acct]) { seenA[acct]=1; accOrder[++an]=acct }

    if (bal > 0) {
        if (dFirst[key] == 0) dFirst[key] = bal
        dLast[key] = bal
    }
    if (gained > 0 && cat != "flow") {
        # 去重：同一时刻同得分同余额的多行（DEBUG/INFO 双记）只算一次
        if (match(line, /\[[0-9][0-9]?\/[0-9][0-9]?\/[0-9][0-9][0-9][0-9], [0-9][0-9]?:[0-9][0-9]:[0-9][0-9] [AP]M\]/)) {
            t2 = substr(line, RSTART+1, RLENGTH-2); sub(/^.*, /, "", t2)
        } else t2 = NR
        dk = key SUBSEP t2 SUBSEP gained SUBSEP bal
        if (!seenG[dk]) {
            seenG[dk] = 1
            dsum[key SUBSEP cat] += gained
            mCat[mkey SUBSEP cat] += gained
        }
    }

    # 风控：统计各字段出现风险值的次数
    if (line ~ /GET-DASHBOARD-DATA|机器人检测|疑似受限|bot标记|活动折叠|userWarnings/) {
        v = getv(line, "疑似受限"); if (v == "true") risk[key SUBSEP "restricted"]++
        v = getv(line, "bot标记"); if (v == "true") risk[key SUBSEP "bot"]++
        v = getv(line, "活动折叠"); if (v == "true") risk[key SUBSEP "fold"]++
        v = getv(line, "userWarnings"); if (v != "" && v != "无" && v != "未知") risk[key SUBSEP "warn"]++
        riskChecks[key]++
    }
    if (line ~ /需要用户登录|请登录|需要人工验证|检测到了验证码|passkey 验证/) risk[key SUBSEP "login"]++
    if (line ~ /\[ERROR\]/) { risk[key SUBSEP "error"]++; risk[mkey SUBSEP "error"]++ }
}
function dumpDays(  i,k,a,d,first,last,cat, arr,firstf) {
    printf "["
    for (i=1; i<=dn; i++) {
        k = dayOrder[i]
        split(k, p, SUBSEP); d = p[1]; a = p[2]
        if (i>1) printf ","
        first = dFirst[k]; last = dLast[k]
        printf "{\"date\":\"%s\",\"account\":\"%s\",\"start\":%d,\"now\":%d,\"delta\":%d,", d, a, first, last, last-first
        printf "\"search\":%d,\"read\":%d,\"checkin\":%d,\"other\":%d,", dsum[k SUBSEP "search"], dsum[k SUBSEP "read"], dsum[k SUBSEP "checkin"], dsum[k SUBSEP "other"]
        printf "\"errors\":%d,\"restricted\":%d,\"bot\":%d,\"fold\":%d,\"warn\":%d,\"login\":%d,\"checks\":%d}", risk[k SUBSEP "error"]+0, risk[k SUBSEP "restricted"]+0, risk[k SUBSEP "bot"]+0, risk[k SUBSEP "fold"]+0, risk[k SUBSEP "warn"]+0, risk[k SUBSEP "login"]+0, riskChecks[k]+0
    }
    print "]"
}
function dumpMonths(  i,k,p,m,a) {
    printf "["
    for (i=1; i<=mn; i++) {
        k = monOrder[i]
        split(k, p, SUBSEP); m = p[1]; a = p[2]
        if (i>1) printf ","
        # 月增量 = 该月各天 delta 之和（只累加有余额的天）
        total = 0
        for (j=1; j<=dn; j++) {
            dk = dayOrder[j]; split(dk, dp, SUBSEP)
            if (dp[1] ~ ("^" m "-") && dp[2] == a && dFirst[dk] > 0) total += dLast[dk] - dFirst[dk]
        }
        printf "{\"month\":\"%s\",\"account\":\"%s\",\"delta\":%d,", m, a, total
        printf "\"search\":%d,\"read\":%d,\"checkin\":%d,\"other\":%d,\"errors\":%d}", mCat[k SUBSEP "search"], mCat[k SUBSEP "read"], mCat[k SUBSEP "checkin"], mCat[k SUBSEP "other"], risk[k SUBSEP "error"]+0
    }
    print "]"
}
END {
    printf "{\"days\":"
    dumpDays()
    printf ",\"months\":"
    dumpMonths()
    print "}"
}
