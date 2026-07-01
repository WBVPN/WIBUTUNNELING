#!/bin/bash
# WIBUTUNNEL TELEGRAM BOT DAEMON (BASH)
# Seringan kapas, secepat kilat.

BOT_CONF="/etc/wibutunnel/bot.conf"
OFFSET_FILE="/etc/wibutunnel/tmp/bot_offset"
CONFIG_FILE="/usr/local/etc/xray/config.json"

mkdir -p /etc/wibutunnel/tmp
touch $OFFSET_FILE

# Utility function to send message
send_msg() {
    local text=$(echo -e "$1")
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -F "chat_id=${CHAT_ID}" -F "parse_mode=html" -F "text=${text}" >/dev/null 2>&1
}

create_account() {
    local proto=$1
    local user=$2
    local hari=$3
    local limit_ip=${4:-0}
    local limit_bw=${5:-0}
    
    # Validation
    if [[ ! "$hari" =~ ^[0-9]+$ || "$hari" -le 0 ]]; then
        send_msg "❌ <b>Format Hari Salah!</b>\nGunakan angka."
        return
    fi
    if [[ ! "$limit_ip" =~ ^[0-9]+$ ]]; then limit_ip=0; fi
    if [[ ! "$limit_bw" =~ ^[0-9]+$ ]]; then limit_bw=0; fi
    
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then
        send_msg "❌ <b>Nama User Salah!</b>\nHanya boleh huruf dan angka."
        return
    fi
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>User '${user}' Sudah Ada!</b>"
        return
    fi

    local uuid=$(uuidgen)
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    local exp_date=$(date -d "+${hari} days" +"%Y-%m-%d %H:%M:%S")
    local tampil_exp=$(date -d "+${hari} days" +"%Y-%m-%d")
    local link1=""
    local link2=""
    local link3=""
    
    if [[ "$proto" == "VLESS" ]]; then
        jq --arg uuid "$uuid" --arg user "$user" '
            .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}] |
            .inbounds[2].settings.clients += [{"id": $uuid, "email": $user}] |
            .inbounds[3].settings.clients += [{"id": $uuid, "email": $user}]
        ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xtmp.json && mv /etc/wibutunnel/tmp/xtmp.json "$CONFIG_FILE"
        echo "${user}:${exp_date}" >> /etc/xray/vless_exp.conf
        link1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
        link3="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"
    elif [[ "$proto" == "VMESS" ]]; then
        jq --arg uuid "$uuid" --arg user "$user" '
            .inbounds[4].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}] |
            .inbounds[5].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}] |
            .inbounds[6].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}]
        ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xtmp.json && mv /etc/wibutunnel/tmp/xtmp.json "$CONFIG_FILE"
        echo "${user}:${exp_date}" >> /etc/xray/vmess_exp.conf
        link1="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
        link2="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ntls\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"\",\"sni\":\"\"}" | base64 -w 0)"
        link3="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
    elif [[ "$proto" == "TROJAN" ]]; then
        jq --arg uuid "$uuid" --arg user "$user" '
            .inbounds[7].settings.clients += [{"password": $uuid, "email": $user}] |
            .inbounds[8].settings.clients += [{"password": $uuid, "email": $user}]
        ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xtmp.json && mv /etc/wibutunnel/tmp/xtmp.json "$CONFIG_FILE"
        echo "${user}:${exp_date}" >> /etc/xray/trojan_exp.conf
        link1="trojan://${uuid}@${domain}:443?path=/trojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan&sni=${domain}#${user}"
    fi

    echo "${user}:${limit_ip}" >> /etc/wibutunnel/limit_ip.db
    echo "${user}:${limit_bw}" >> /etc/wibutunnel/limit_bw.db
    systemctl restart xray >/dev/null 2>&1

    [[ "$limit_ip" -eq 0 ]] && limit_ip="Bebas" || limit_ip="${limit_ip} IP"
    [[ "$limit_bw" -eq 0 ]] && limit_bw="Unlimited" || limit_bw="${limit_bw} GB"

    local pesan="━━━━━━━━━━━━━━━━━━━━\n"
    pesan+=" ✅ <b>${proto} ACCOUNT CREATED</b>\n"
    pesan+="━━━━━━━━━━━━━━━━━━━━\n"
    pesan+=" <b>User     :</b> <code>${user}</code>\n"
    pesan+=" <b>Domain   :</b> <code>${domain}</code>\n"
    pesan+=" <b>Expired  :</b> <code>${tampil_exp}</code>\n"
    pesan+=" <b>Limit IP :</b> ${limit_ip}\n"
    pesan+=" <b>Limit BW :</b> ${limit_bw}\n"
    pesan+="━━━━━━━━━━━━━━━━━━━━\n\n"
    pesan+="🌐 <b>Link TLS (WS):</b>\n<code>${link1}</code>\n\n"
    if [[ -n "$link3" ]]; then
        pesan+="🌐 <b>Link NTLS (WS):</b>\n<code>${link2}</code>\n\n"
        pesan+="🌐 <b>Link GRPC:</b>\n<code>${link3}</code>\n"
    else
        pesan+="🌐 <b>Link GRPC:</b>\n<code>${link2}</code>\n"
    fi
    pesan+="━━━━━━━━━━━━━━━━━━━━"
    
    send_msg "$pesan"
}

delete_account() {
    local user=$1
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then return; fi
    
    jq --arg u "$user" '
        .inbounds[1].settings.clients |= map(select(.email != $u)) |
        .inbounds[2].settings.clients |= map(select(.email != $u)) |
        .inbounds[3].settings.clients |= map(select(.email != $u)) |
        .inbounds[4].settings.clients |= map(select(.email != $u)) |
        .inbounds[5].settings.clients |= map(select(.email != $u)) |
        .inbounds[6].settings.clients |= map(select(.email != $u)) |
        .inbounds[7].settings.clients |= map(select(.email != $u)) |
        .inbounds[8].settings.clients |= map(select(.password != $u)) |
        (.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))
    ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xtmp.json && mv /etc/wibutunnel/tmp/xtmp.json "$CONFIG_FILE"

    sed -i "/^${user}:/d" /etc/xray/vless_exp.conf
    sed -i "/^${user}:/d" /etc/xray/vmess_exp.conf
    sed -i "/^${user}:/d" /etc/xray/trojan_exp.conf
    sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null
    sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null
    sed -i "/^${user}:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
    sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null

    systemctl restart xray >/dev/null 2>&1
    send_msg "🗑️ <b>Berhasil!</b>\nAkun <code>${user}</code> telah dimusnahkan secara permanen."
}

while true; do
    if [[ ! -f "$BOT_CONF" ]]; then sleep 5; continue; fi
    source "$BOT_CONF"
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then sleep 5; continue; fi
    
    OFFSET=$(cat $OFFSET_FILE 2>/dev/null)
    [[ -z "$OFFSET" ]] && OFFSET=0

    # Ambil update (Long Polling 15 detik)
    UPDATES=$(curl -s --max-time 20 -X GET "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=15")
    
    if [[ $(echo "$UPDATES" | jq -r '.ok') == "true" ]]; then
        MSG_COUNT=$(echo "$UPDATES" | jq '.result | length')
        if [[ "$MSG_COUNT" -gt 0 ]]; then
            for (( i=0; i<$MSG_COUNT; i++ )); do
                UPDATE_ID=$(echo "$UPDATES" | jq -r ".result[$i].update_id")
                SENDER_ID=$(echo "$UPDATES" | jq -r ".result[$i].message.chat.id")
                TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text")

                if [[ "$SENDER_ID" == "$CHAT_ID" ]]; then
                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    ARG1=$(echo "$TEXT" | awk '{print $2}')
                    ARG2=$(echo "$TEXT" | awk '{print $3}')
                    ARG3=$(echo "$TEXT" | awk '{print $4}')
                    ARG4=$(echo "$TEXT" | awk '{print $5}')
                    
                    case "$CMD" in
                        /start|/menu|/help)
                            MSG="━━━━━━━━━━━━━━━━━━━━\n 🤖 <b>WIBUTUNNEL PANEL BOT</b>\n━━━━━━━━━━━━━━━━━━━━\n\n"
                            MSG+="✨ <b>Menu Create Account</b>\n"
                            MSG+="├ <code>/vless [user] [hari] [ip] [gb]</code>\n"
                            MSG+="├ <code>/vmess [user] [hari] [ip] [gb]</code>\n"
                            MSG+="└ <code>/trojan [user] [hari] [ip] [gb]</code>\n\n"
                            MSG+="⚙️ <b>Menu Management</b>\n"
                            MSG+="├ <code>/hapus [user]</code>\n"
                            MSG+="└ <code>/info</code> (Cek status VPS)\n\n"
                            MSG+="━━━━━━━━━━━━━━━━━━━━\n"
                            MSG+="<i>Contoh: /vless budi 30 2 10</i>\n"
                            MSG+="<i>(Membuat VLESS 'budi' 30 hr, limit 2 IP, limit 10 GB)</i>"
                            send_msg "$MSG"
                            ;;
                        /vless)
                            [[ -n "$ARG1" && -n "$ARG2" ]] && create_account "VLESS" "$ARG1" "$ARG2" "$ARG3" "$ARG4" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/vless nama_user 30</code>"
                            ;;
                        /vmess)
                            [[ -n "$ARG1" && -n "$ARG2" ]] && create_account "VMESS" "$ARG1" "$ARG2" "$ARG3" "$ARG4" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/vmess nama_user 30</code>"
                            ;;
                        /trojan)
                            [[ -n "$ARG1" && -n "$ARG2" ]] && create_account "TROJAN" "$ARG1" "$ARG2" "$ARG3" "$ARG4" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/trojan nama_user 30</code>"
                            ;;
                        /hapus)
                            [[ -n "$ARG1" ]] && delete_account "$ARG1" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/hapus nama_user</code>"
                            ;;
                        /info)
                            IP=$(curl -s ipv4.icanhazip.com)
                            UPTIME=$(uptime -p | cut -d' ' -f2-)
                            RAM=$(free -m | awk '/Mem:/ {print $3" MB / "$2" MB"}')
                            send_msg "💻 <b>VPS INFO</b>\n\n<b>IP :</b> <code>${IP}</code>\n<b>Uptime :</b> ${UPTIME}\n<b>RAM :</b> ${RAM}"
                            ;;
                    esac
                fi
                echo "$((UPDATE_ID + 1))" > $OFFSET_FILE
            done
        fi
    fi
    sleep 1
done
