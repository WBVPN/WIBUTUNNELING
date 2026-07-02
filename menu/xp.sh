#!/bin/bash
# ==========================================
# WIBU TUNNELING - xp.sh (v4.0 RECOVERY)
# [FIX] Lock path + jq exact match
# ==========================================

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi
check_license_silent

exec 200>/etc/wibutunnel/tmp/xp.lock
flock -n 200 || exit 0

source /etc/wibutunnel/bot.conf 2>/dev/null

CONFIG_FILE="/usr/local/etc/xray/config.json"
VLESS_EXP="/etc/xray/vless_exp.conf"
VMESS_EXP="/etc/xray/vmess_exp.conf"
TROJAN_EXP="/etc/xray/trojan_exp.conf"

today_sec=$(date +%s)
RESTART_NEEDED=false
NOTIFIED_USERS=" "

process_expired() {
    local EXP_FILE=$1
    local PROTO_NAME=$2
    local INB1=$3
    local INB2=$4
    local INB3=$5

    [[ ! -f "$EXP_FILE" ]] && return
    awk '!seen[$0]++' "$EXP_FILE" > /etc/wibutunnel/tmp/exp_clean && mv /etc/wibutunnel/tmp/exp_clean "$EXP_FILE"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        user=$(echo "$line" | cut -d: -f1)
        exp_date=$(echo "$line" | cut -d: -f2-)
        
        [[ -z "$exp_date" || "$exp_date" == "Lifetime" || "$user" == *"dummy"* ]] && continue

        if [[ ${#exp_date} -eq 10 ]]; then exp_date="${exp_date} 00:00:00"; fi
        exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
        [[ -z "$exp_sec" ]] && continue

        user_exists=$(jq -r --arg u "$user" '
            [.inbounds['$INB1'].settings.clients[]?.email,
             .inbounds['$INB2'].settings.clients[]?.email'$(
                 [[ -n "$INB3" ]] && echo ',
             .inbounds['$INB3'].settings.clients[]?.email'
             )'] | index($u)
        ' "$CONFIG_FILE")

        if [[ "$user_exists" != "null" ]]; then
            if [ "$today_sec" -ge "$exp_sec" ]; then
                
                if [[ "$user" == *"trial"* ]]; then
                    if [[ -n "$INB3" ]]; then
                        jq --arg u "$user" '
                            .inbounds['$INB1'].settings.clients |= map(select(.email != $u)) |
                            .inbounds['$INB2'].settings.clients |= map(select(.email != $u)) |
                            .inbounds['$INB3'].settings.clients |= map(select(.email != $u))
                        ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
                    else
                        jq --arg u "$user" '
                            .inbounds['$INB1'].settings.clients |= map(select(.email != $u)) |
                            .inbounds['$INB2'].settings.clients |= map(select(.email != $u))
                        ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
                    fi
                    sed -i "/^${user}:/d" "$EXP_FILE"
                    sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
                    
                    FOOTER="Deleted Permanently"
                else
                    jq --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= (. + [$u] | unique)' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
                    
                    now=$(date +%s)
                    sed -i "/^$user:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
                    echo "$user:$now:0:EXPIRED" >> /etc/wibutunnel/locked_users.db
                    
                    FOOTER="Move to Recovery"
                fi

                RESTART_NEEDED=true

                if [[ ! "$NOTIFIED_USERS" =~ " ${user}_${PROTO_NAME} " ]]; then
                    NOTIFIED_USERS+=" ${user}_${PROTO_NAME} "
                    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                        DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
                        IP_VPS=$(curl -sS --max-time 5 ipv4.icanhazip.com)
                        ISP=$(cat /etc/wibutunnel/tmp/ipapi.txt 2>/dev/null | sed -n '2p')
                        [[ -z "$ISP" ]] && ISP=$(curl -sS --max-time 5 ip-api.com/line/?fields=isp | head -n 1)

                        PESAN="IP     : <code>${IP_VPS}</code>
DOMAIN : <code>${DOMAIN}</code>
ISP    : <code>${ISP}</code>
Expired Account ${PROTO_NAME}
✓ <code>${user}</code>
Limit - Time Expired
Expired On - ${exp_date}

<i>${FOOTER}</i>"
                        curl -s --max-time 8 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                            -F "chat_id=${CHAT_ID}" -F "parse_mode=html" -F "text=${PESAN}" >/dev/null 2>&1
                            
                            # Notification restricted only to the main CHAT_ID owner to avoid spamming co-admins
                    fi
                fi
            fi
        else
            sed -i "/^${user}:/d" "$EXP_FILE"
        fi
    done < "$EXP_FILE"
}

process_expired "$VLESS_EXP" "VLESS" "1" "2" "3"
process_expired "$VMESS_EXP" "VMESS" "4" "5" "6"
process_expired "$TROJAN_EXP" "TROJAN" "7" "8" ""

if [ "$RESTART_NEEDED" = true ]; then
    systemctl restart xray >/dev/null 2>&1
fi
