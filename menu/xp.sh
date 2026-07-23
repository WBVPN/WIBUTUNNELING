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

TRIAL_TO_DELETE=()
NORMAL_TO_RECOVERY=()

# Extract all active users in one go (Ultra Fast)
ACTIVE_VLESS=$(jq -r '[.inbounds[1,2,3].settings.clients[]?.email] | unique | join(" ")' "$CONFIG_FILE")
ACTIVE_VMESS=$(jq -r '[.inbounds[4,5,6].settings.clients[]?.email] | unique | join(" ")' "$CONFIG_FILE")
ACTIVE_TROJAN=$(jq -r '[.inbounds[7,8].settings.clients[]?.email] | unique | join(" ")' "$CONFIG_FILE")

process_expired() {
    local EXP_FILE=$1
    local PROTO_NAME=$2
    local ACTIVE_USERS=$3

    [[ ! -f "$EXP_FILE" ]] && return
    awk '!seen[$0]++' "$EXP_FILE" > /etc/wibutunnel/tmp/exp_clean && mv /etc/wibutunnel/tmp/exp_clean "$EXP_FILE"

    local NEW_EXP_CONTENT=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        user=$(echo "$line" | cut -d: -f1)
        exp_date=$(echo "$line" | cut -d: -f2-)
        
        [[ -z "$exp_date" || "$exp_date" == "Lifetime" || "$user" == *"dummy"* ]] && { NEW_EXP_CONTENT+="${line}\n"; continue; }

        if [[ ${#exp_date} -eq 10 ]]; then exp_date="${exp_date} 00:00:00"; fi
        exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
        [[ -z "$exp_sec" ]] && { NEW_EXP_CONTENT+="${line}\n"; continue; }

        # Check if user exists in RAM instead of reading file
        if [[ " $ACTIVE_USERS " =~ " $user " ]]; then
            if [ "$today_sec" -ge "$exp_sec" ]; then
                
                # Mencegah spam jika user sudah dalam status EXPIRED di recovery
                if grep -q "^${user}:.*:EXPIRED" /etc/wibutunnel/locked_users.db 2>/dev/null; then
                    NEW_EXP_CONTENT+="${line}\n"
                    continue
                fi

                if [[ "$user" == *"trial"* ]]; then
                    TRIAL_TO_DELETE+=("$user")
                    # Do not append to NEW_EXP_CONTENT (removes from EXP_FILE)
                    sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
                    sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
                    
                    FOOTER="Deleted Permanently"
                else
                    NORMAL_TO_RECOVERY+=("$user")
                    NEW_EXP_CONTENT+="${line}\n"
                    
                    now=$(date +%s)
                    sed -i "/^$user:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
                    echo "$user:$now:0:EXPIRED" >> /etc/wibutunnel/locked_users.db
                    
                    FOOTER="Move to Recovery"
                fi

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
                            -F "chat_id=${CHAT_ID}" -F "parse_mode=html" -F "text=${PESAN}" >/dev/null 2>&1 &
                    fi
                fi
            else
                NEW_EXP_CONTENT+="${line}\n"
            fi
        else
            # User not in config anymore, naturally removed from EXP_FILE
            :
        fi
    done < "$EXP_FILE"

    echo -e -n "$NEW_EXP_CONTENT" > "$EXP_FILE"
}

process_expired "$VLESS_EXP" "VLESS" "$ACTIVE_VLESS"
process_expired "$VMESS_EXP" "VMESS" "$ACTIVE_VMESS"
process_expired "$TROJAN_EXP" "TROJAN" "$ACTIVE_TROJAN"

if [[ ${#TRIAL_TO_DELETE[@]} -gt 0 || ${#NORMAL_TO_RECOVERY[@]} -gt 0 ]]; then
    JQ_FILTER="."
    
    # 1. Delete trial users from all inbounds
    for u in "${TRIAL_TO_DELETE[@]}"; do
        for i in {1..8}; do
            JQ_FILTER+=" | .inbounds[$i].settings.clients |= (if type == \"array\" then map(select(.email != \"$u\")) else . end)"
        done
    done
    
    # 2. Add normal expired users to blocked routing
    if [[ ${#NORMAL_TO_RECOVERY[@]} -gt 0 ]]; then
        USERS_JSON=$(printf '"%s",' "${NORMAL_TO_RECOVERY[@]}")
        USERS_JSON="[${USERS_JSON%,}]"
        JQ_FILTER+=" | (.routing.rules[] | select(.user != null and .outboundTag == \"blocked\") | .user) |= (. + ${USERS_JSON} | unique)"
    fi
    
    jq "$JQ_FILTER" "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
    
    if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi
fi

# ==========================================
# AUTO TRUNCATE LOGS (PREVENT DISK FULL)
# ==========================================
LOG_SIZE=$(stat -c%s "/var/log/xray/access.log" 2>/dev/null || echo 0)
if [[ $LOG_SIZE -gt 52428800 ]]; then # 50MB
    > /var/log/xray/access.log
    > /var/log/xray/error.log
fi
