function esc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    return s
}
{
    line = $0
    acct = ""
    if (match(line, /\[[0-9][0-9]+\]/)) acct = substr(line, RSTART+1, RLENGTH-2)
    else if (match(line, /\[Sezario[0-9]+\]/)) acct = substr(line, RSTART+1, RLENGTH-2)
    if (acct == "") next

    # RUN-END 汇总行的 现余额 是两账号合计，不是单账号余额，跳过避免污染
    if (line ~ /\[RUN-END\]/) next

    ts = ""
    if (match(line, /\[[0-9][0-9]?\/[0-9][0-9]?\/[0-9][0-9][0-9][0-9], [0-9][0-9]?:[0-9][0-9]:[0-9][0-9] [AP]M\]/)) {
        ts = substr(line, RSTART+1, RLENGTH-2)
        sub(/^.*, /, "", ts)
    }

    gained = 0; bal = 0
    if (match(line, /获得积分=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); gained = s+0 }
    else if (match(line, /pointsGained=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); gained = s+0 }
    if (match(line, /当前余额=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }
    else if (match(line, /现余额=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }
    else if (match(line, /currentBalance=[0-9]+/)) { s = substr(line, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); bal = s+0 }

    if (!seen[acct]) { seen[acct]=1; order[++n]=acct; first[acct]=0; last[acct]=0 }

    cat = "other"
    if (line ~ /\[SEARCH-BING\]/) cat = "search"
    else if (line ~ /DAILY-CHECK-IN/ || line ~ /签到/) cat = "checkin"
    else if (line ~ /\[READ-TO-EARN\]/) cat = "read"
    else if (line ~ /\[FLOW\]/) cat = "flow"

    if (bal > 0) {
        if (first[acct] == 0) first[acct] = bal
        last[acct] = bal
    }
    if (gained > 0 && cat != "flow") {
        key = acct SUBSEP ts SUBSEP gained SUBSEP bal
        if (!seenDetail[key]) {
            seenDetail[key] = 1
            total[acct] += gained
            cat_total[acct SUBSEP cat] += gained
            detail[acct] = ts "|" cat "|" gained "|" bal "\n" detail[acct]
            cnt[acct]++
        }
    }
    if (ts != "") lastTs[acct] = ts
    if (line ~ /ACCOUNT-START/) { started[acct]=1; startTs[acct]=ts }
    if (line ~ /ACCOUNT-END/ || (line ~ /\[FLOW\]/ && line ~ /积分已收集/)) { done[acct]=1; endTs[acct]=ts }
    if (line ~ /需要登录|验证码|2FA|passkey/) manual[acct]=1
    # 「签到未确认到账」是已到账后的重复尝试，属良性；单独计数，END 里视签到是否得分决定是否从 errors 扣除
    if (line ~ /\[ERROR\]/ && line ~ /签到未确认到账/) benign[acct]++
    else if (line ~ /\[ERROR\]/) errors[acct]++
}
END {
    printf "["
    for (i=1; i<=n; i++) {
        a = order[i]
        if (i>1) printf ","
        st = (started[a] ? (done[a] ? "done" : "running") : "pending")
        printf "{\"account\":\"%s\",\"start\":%d,\"now\":%d,\"today\":%d,", a, first[a], last[a], last[a]-first[a]
        printf "\"search\":%d,\"checkin\":%d,\"read\":%d,\"other\":%d,", cat_total[a SUBSEP "search"], cat_total[a SUBSEP "checkin"], cat_total[a SUBSEP "read"], cat_total[a SUBSEP "other"]
        printf "\"status\":\"%s\",\"manual\":%s,", st, (manual[a] ? "true" : "false")
        # 良性签到重复：仅当该账号当天签到已得分时才从错误数扣除，避免掩盖真实失败
        eff_err = errors[a] + 0
        if (cat_total[a SUBSEP "checkin"] > 0 && benign[a] > 0) eff_err -= benign[a]
        if (eff_err < 0) eff_err = 0
        printf "\"errors\":%d,\"benign\":%d,\"lastTs\":\"%s\",\"startTs\":\"%s\",\"endTs\":\"%s\",", eff_err, benign[a]+0, esc(lastTs[a]), esc(startTs[a]), esc(endTs[a])
        printf "\"detail\":["
        m = split(detail[a], d, "\n")
        k = 0
        for (j=1; j<=m && k<8; j++) {
            if (d[j] == "") continue
            split(d[j], f, "|")
            if (k>0) printf ","
            printf "{\"t\":\"%s\",\"cat\":\"%s\",\"pts\":%d,\"bal\":%d}", esc(f[1]), f[2], f[3], f[4]
            k++
        }
        printf "]}"
    }
    print "]"
}
