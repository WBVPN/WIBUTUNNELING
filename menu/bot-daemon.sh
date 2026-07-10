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
    local target_id="${SENDER_ID:-$CHAT_ID}"
    local keyboard="$2"
    if [[ -n "$keyboard" ]]; then
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "disable_web_page_preview=true" \
            --data-urlencode "parse_mode=html" \
            --data-urlencode "text=${text}" \
            --data-urlencode "reply_markup=${keyboard}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    else
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${target_id}" \
            --data-urlencode "disable_web_page_preview=true" \
            --data-urlencode "parse_mode=html" \
            --data-urlencode "text=${text}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    fi
}

edit_msg() {
    local text=$(echo -e "$1")
    local target_id="${SENDER_ID:-$CHAT_ID}"
    local keyboard="$2"
    if [[ -n "$keyboard" ]]; then
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText"             --data-urlencode "chat_id=${target_id}"             --data-urlencode "message_id=${MESSAGE_ID}"             --data-urlencode "disable_web_page_preview=true"             --data-urlencode "parse_mode=html"             --data-urlencode "text=${text}"             --data-urlencode "reply_markup=${keyboard}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    else
        curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText"             --data-urlencode "chat_id=${target_id}"             --data-urlencode "message_id=${MESSAGE_ID}"             --data-urlencode "disable_web_page_preview=true"             --data-urlencode "parse_mode=html"             --data-urlencode "text=${text}" >> /etc/wibutunnel/tmp/bot_error.log 2>&1
    fi
}

create_account() {
    local proto=$1
    local user=$2
    local hari=$3
    local limit_ip=${4:-0}
    local limit_bw=${5:-0}
    
    # Validation
    if [[ ! "$limit_ip" =~ ^[0-9]+$ ]]; then limit_ip=0; fi
    if [[ ! "$limit_bw" =~ ^[0-9]+$ ]]; then limit_bw=0; fi
    
    if [[ -n "${user//[a-zA-Z0-9_-]/}" ]]; then
        send_msg "❌ <b>Nama User Salah!</b>\nHanya boleh huruf, angka, dan strip (-).\nDebug: user='${user}', proto='${proto}', waktu='${hari}'"
        return
    fi
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>User '${user}' Sudah Ada!</b>"
        return
    fi

    local uuid=$(uuidgen)
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    
    local exp_date=""
    local tampil_exp=""
    
    local clean_hari="${hari%[hmd]}"
    if [[ -z "${clean_hari//[0-9]/}" && -n "$clean_hari" ]]; then
        if [[ "$hari" == *m ]]; then
            exp_date=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
        elif [[ "$hari" == *h ]]; then
            exp_date=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
        else
            exp_date=$(date -d "+${clean_hari} days" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} days" +"%Y-%m-%d")
        fi
    else
        send_msg "❌ <b>Format Waktu Salah!</b>\nGunakan angka untuk hari, atau akhiran 'h' untuk jam, 'm' untuk menit (contoh: 30, 1h, 60m).\nDebug: hari='${hari}'"
        return
    fi
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

    local CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null)
    local ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"
    local THICKLINE="━━━━━━━━━━━━━━━━━━━━"
    local pesan="✨ <b>VPN ACCOUNT - ${proto}</b> ✨\n"
    pesan+="${THICKLINE}\n"
    pesan+="👤 <b>Remarks    :</b> <code>${user}</code>\n"
    pesan+="🌐 <b>Domain     :</b> <code>${domain}</code>\n"
    pesan+="🏢 <b>ISP / City :</b> <code>${ISP} / ${CITY}</code>\n"
    pesan+="⏳ <b>Expired On :</b> <code>${exp_date}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="⚙️ <b>CONFIG DETAILS</b>\n"
    pesan+="<b>Port TLS   :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port NTLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>AlterId    :</b> <code>0</code>\n"
        pesan+="<b>Security   :</b> <code>auto</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vmess</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption :</b> <code>none</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vless</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password   :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/trojan</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>trojan</code>\n"
    fi

    pesan+="${THICKLINE}\n"
    pesan+="🔗 <b>LINK ${proto} WS TLS</b>\n<code>${link1}</code>\n\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="🔗 <b>LINK ${proto} WS NO TLS</b>\n<code>${link2}</code>\n\n"
        pesan+="🔗 <b>LINK ${proto} GRPC</b>\n<code>${link3}</code>\n"
    else
        pesan+="🔗 <b>LINK ${proto} GRPC</b>\n<code>${link2}</code>\n"
    fi
    pesan+="${THICKLINE}"
    
    send_msg "$pesan"
}

delete_account() {
    local user=$1
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then return; fi
    
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) == null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan di database."
        return
    fi
    
    jq --arg u "$user" '
        .inbounds[1].settings.clients |= map(select(.email != $u)) |
        .inbounds[2].settings.clients |= map(select(.email != $u)) |
        .inbounds[3].settings.clients |= map(select(.email != $u)) |
        .inbounds[4].settings.clients |= map(select(.email != $u)) |
        .inbounds[5].settings.clients |= map(select(.email != $u)) |
        .inbounds[6].settings.clients |= map(select(.email != $u)) |
        .inbounds[7].settings.clients |= map(select(.email != $u)) |
        .inbounds[8].settings.clients |= map(select(.email != $u)) |
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

is_admin() {
    local id=$1
    if [[ "$id" == "$CHAT_ID" ]]; then
        return 0
    fi
    if [[ -f /etc/wibutunnel/bot_admins.db ]]; then
        if grep -q "^${id}$" /etc/wibutunnel/bot_admins.db; then
            return 0
        fi
    fi
    return 1
}

renew_account() {
    local user=$1
    local hari=$2
    if [[ ! "$hari" =~ ^[0-9]+$ || "$hari" -le 0 ]]; then
        send_msg "❌ <b>Format Hari Salah!</b>\nGunakan angka."
        return
    fi
    
    if jq -e --arg u "$user" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) == null' "$CONFIG_FILE" >/dev/null 2>&1; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan."
        return
    fi

    local exp_file=""
    if grep -q "^${user}:" /etc/xray/vless_exp.conf; then
        exp_file="/etc/xray/vless_exp.conf"
    elif grep -q "^${user}:" /etc/xray/vmess_exp.conf; then
        exp_file="/etc/xray/vmess_exp.conf"
    elif grep -q "^${user}:" /etc/xray/trojan_exp.conf; then
        exp_file="/etc/xray/trojan_exp.conf"
    fi

    if [[ -z "$exp_file" ]]; then
        send_msg "❌ <b>Gagal!</b>\nData masa aktif user <code>${user}</code> tidak ditemukan."
        return
    fi

    local exp_date=""
    local tampil_exp=""
    
    local clean_hari="${hari%[hmd]}"
    if [[ -z "${clean_hari//[0-9]/}" && -n "$clean_hari" ]]; then
        if [[ "$hari" == *m ]]; then
            exp_date=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} minutes" +"%Y-%m-%d %H:%M:%S")
        elif [[ "$hari" == *h ]]; then
            exp_date=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} hours" +"%Y-%m-%d %H:%M:%S")
        else
            exp_date=$(date -d "+${clean_hari} days" +"%Y-%m-%d %H:%M:%S")
            tampil_exp=$(date -d "+${clean_hari} days" +"%Y-%m-%d")
        fi
    else
        send_msg "❌ <b>Format Waktu Salah!</b>\nGunakan angka untuk hari, atau akhiran 'h' untuk jam, 'm' untuk menit (contoh: 30, 1h, 60m).\nDebug: hari='${hari}'"
        return
    fi
    
    sed -i "s/^${user}:.*/${user}:${exp_date}/" "$exp_file"
    
    send_msg "✅ <b>Berhasil Perpanjang Akun!</b>\n\n<b>User :</b> <code>${user}</code>\n<b>Ditambah :</b> ${hari}\n<b>Expired Baru :</b> <code>${tampil_exp}</code>"
}

list_account() {
    local msg="━━━━━━━━━━━━━━━━━━━━\n 📋 <b>LIST AKUN AKTIF</b>\n━━━━━━━━━━━━━━━━━━━━\n"
    
    get_limits() {
        local u=$1
        local ip=$(grep "^${u}:" /etc/wibutunnel/limit_ip.db 2>/dev/null | cut -d: -f2)
        local bw=$(grep "^${u}:" /etc/wibutunnel/limit_bw.db 2>/dev/null | cut -d: -f2)
        [[ -z "$ip" || "$ip" == "0" ]] && ip="Bebas" || ip="${ip} IP"
        [[ -z "$bw" || "$bw" == "0" ]] && bw="Unl" || bw="${bw} GB"
        echo "IP: ${ip} | BW: ${bw}"
    }

    msg+="\n🔹 <b>VLESS:</b>\n"
    local c_vless=0
    while IFS=":" read -r usr exp; do
        [[ -z "$usr" || "$usr" == dummy* ]] && continue
        local lmt=$(get_limits "$usr")
        msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
        ((c_vless++))
    done < /etc/xray/vless_exp.conf
    [[ "$c_vless" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    
    msg+="\n🔹 <b>VMESS:</b>\n"
    local c_vmess=0
    while IFS=":" read -r usr exp; do
        [[ -z "$usr" || "$usr" == dummy* ]] && continue
        local lmt=$(get_limits "$usr")
        msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
        ((c_vmess++))
    done < /etc/xray/vmess_exp.conf
    [[ "$c_vmess" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    
    msg+="\n🔹 <b>TROJAN:</b>\n"
    local c_trojan=0
    while IFS=":" read -r usr exp; do
        [[ -z "$usr" || "$usr" == dummy* ]] && continue
        local lmt=$(get_limits "$usr")
        msg+=" ├ <code>${usr}</code> (Exp: $(echo "$exp" | awk '{print $1}') | ${lmt})\n"
        ((c_trojan++))
    done < /etc/xray/trojan_exp.conf
    [[ "$c_trojan" -eq 0 ]] && msg+=" └ <i>Kosong</i>\n"
    
    msg+="\n━━━━━━━━━━━━━━━━━━━━"
    send_msg "$msg"
}

backup_vps() {
    local target_id="${SENDER_ID:-$CHAT_ID}"
    
    # Send loading message and capture message_id
    local load_resp=$(curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -F "chat_id=${target_id}" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F "text=⏳ <b>Sedang merakit file backup...</b>")
    local load_msg_id=$(echo "$load_resp" | jq -r '.result.message_id // empty')
    
    local domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    local ip_vps=$(curl -sS --max-time 5 ipv4.icanhazip.com 2>/dev/null || echo "Unknown")
    local backup_file="/tmp/${domain}-${ip_vps}.zip"
    rm -f "$backup_file"
    
    cd /
    zip -q -P "$CHAT_ID" -r "$backup_file" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/xray/domain 2>/dev/null
    
    if [[ -f "$backup_file" ]]; then
        local tgl=$(date "+%Y-%m-%d %H:%M:%S")
        local caption=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${tgl}</code>\n\n<i>Mengunggah dan membuat File ID...</i>")
        local response=$(curl -s --max-time 60 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
            -F "chat_id=${target_id}" \
            -F "document=@${backup_file}" \
            -F "caption=${caption}" \
            -F "parse_mode=html")
            
        local file_id=$(echo "$response" | jq -r '.result.document.file_id // empty')
        local msg_id=$(echo "$response" | jq -r '.result.message_id // empty')
        
        if [[ -n "$file_id" && -n "$msg_id" && "$msg_id" != "null" ]]; then
            local new_caption=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${tgl}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${file_id}</code>\n\n🔐 <b>Password:</b> CHAT ID Anda")
            curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
                -F "chat_id=${target_id}" \
                -F "message_id=${msg_id}" \
                -F "parse_mode=html" \
                -F "caption=${new_caption}" >/dev/null 2>&1
        fi
        
        rm -f "$backup_file"
        
        # Hapus pesan loading
        if [[ -n "$load_msg_id" && "$load_msg_id" != "null" ]]; then
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
                -F "chat_id=${target_id}" \
                -F "message_id=${load_msg_id}" >/dev/null 2>&1
        fi
    else
        send_msg "❌ <b>Gagal membuat backup!</b>"
        # Tetap hapus pesan loading walau gagal
        if [[ -n "$load_msg_id" && "$load_msg_id" != "null" ]]; then
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
                -F "chat_id=${target_id}" \
                -F "message_id=${load_msg_id}" >/dev/null 2>&1
        fi
    fi
}

detail_account() {
    local user=$1
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then return; fi
    
    local proto=""
    local uuid=""
    local exp_date=""
    
    if grep -q "^${user}:" /etc/xray/vless_exp.conf; then
        proto="VLESS"
        uuid=$(jq -r --arg u "$user" '.inbounds[1].settings.clients[] | select(.email == $u) | .id' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/vless_exp.conf | cut -d: -f2- | awk '{print $1}')
    elif grep -q "^${user}:" /etc/xray/vmess_exp.conf; then
        proto="VMESS"
        uuid=$(jq -r --arg u "$user" '.inbounds[4].settings.clients[] | select(.email == $u) | .id' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/vmess_exp.conf | cut -d: -f2- | awk '{print $1}')
    elif grep -q "^${user}:" /etc/xray/trojan_exp.conf; then
        proto="TROJAN"
        uuid=$(jq -r --arg u "$user" '.inbounds[7].settings.clients[] | select(.email == $u) | .password' "$CONFIG_FILE" | head -n 1)
        exp_date=$(grep "^${user}:" /etc/xray/trojan_exp.conf | cut -d: -f2- | awk '{print $1}')
    fi

    if [[ -z "$proto" || -z "$uuid" ]]; then
        send_msg "❌ <b>Gagal!</b>\nAkun <code>${user}</code> tidak ditemukan."
        return
    fi

    local domain=$(cat /etc/xray/domain 2>/dev/null)
    local limit_ip=$(grep "^${user}:" /etc/wibutunnel/limit_ip.db 2>/dev/null | cut -d: -f2)
    local limit_bw=$(grep "^${user}:" /etc/wibutunnel/limit_bw.db 2>/dev/null | cut -d: -f2)
    
    [[ -z "$limit_ip" || "$limit_ip" -eq 0 ]] && limit_ip="Bebas" || limit_ip="${limit_ip} IP"
    [[ -z "$limit_bw" || "$limit_bw" -eq 0 ]] && limit_bw="Unlimited" || limit_bw="${limit_bw} GB"

    local link1=""
    local link2=""
    local link3=""

    if [[ "$proto" == "VLESS" ]]; then
        link1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
        link3="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"
    elif [[ "$proto" == "VMESS" ]]; then
        link1="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
        link2="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ntls\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"\",\"sni\":\"\"}" | base64 -w 0)"
        link3="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\",\"sni\":\"$domain\"}" | base64 -w 0)"
    elif [[ "$proto" == "TROJAN" ]]; then
        link1="trojan://${uuid}@${domain}:443?path=/trojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
        link2="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan&sni=${domain}#${user}"
    fi

    local CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null)
    local ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"

    local THICKLINE="━━━━━━━━━━━━━━━━━━━━"
    local pesan="✨ <b>VPN ACCOUNT - ${proto}</b> ✨\n"
    pesan+="${THICKLINE}\n"
    pesan+="👤 <b>Remarks    :</b> <code>${user}</code>\n"
    pesan+="🌐 <b>Domain     :</b> <code>${domain}</code>\n"
    pesan+="🏢 <b>ISP / City :</b> <code>${ISP} / ${CITY}</code>\n"
    pesan+="⏳ <b>Expired On :</b> <code>${exp_date}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="⚙️ <b>CONFIG DETAILS</b>\n"
    pesan+="<b>Port TLS   :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port NTLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>AlterId    :</b> <code>0</code>\n"
        pesan+="<b>Security   :</b> <code>auto</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vmess</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>UUID       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption :</b> <code>none</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/vless</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password   :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network    :</b> <code>ws, grpc</code>\n"
        pesan+="<b>Path WS    :</b> <code>/trojan</code>\n"
        pesan+="<b>Serv.Name  :</b> <code>trojan</code>\n"
    fi

    pesan+="${THICKLINE}\n"
    pesan+="🔗 <b>LINK ${proto} WS TLS</b>\n<code>${link1}</code>\n\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="🔗 <b>LINK ${proto} WS NO TLS</b>\n<code>${link2}</code>\n\n"
        pesan+="🔗 <b>LINK ${proto} GRPC</b>\n<code>${link3}</code>\n"
    else
        pesan+="🔗 <b>LINK ${proto} GRPC</b>\n<code>${link2}</code>\n"
    fi
    pesan+="${THICKLINE}"
    
    send_msg "$pesan"
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
                
                # Handle direct message
                TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text // empty")
                TEXT="${TEXT//$'\r'/}"
                
                echo "[$(date)] RECV TEXT: $TEXT from $SENDER_ID (Admin: $CHAT_ID)" >> /etc/wibutunnel/tmp/bot_error.log

                if is_admin "$SENDER_ID"; then
                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    ARG1=$(echo "$TEXT" | awk '{print $2}')
                    ARG2=$(echo "$TEXT" | awk '{print $3}')
                    ARG3=$(echo "$TEXT" | awk '{print $4}')
                    ARG4=$(echo "$TEXT" | awk '{print $5}')
                    
                    case "$CMD" in
                        /start|/menu|/help)
                            MSG="━━━━━━━━━━━━━━━━━━━━\n 🤖 <b>WIBUTUNNEL PANEL BOT</b>\n━━━━━━━━━━━━━━━━━━━━\n\nSelamat datang di Panel Kendali VPS. Silakan pilih menu di bawah ini:"
                            
                            kb='{"inline_keyboard":['
                            kb+='[{"text":"🚀 BUAT AKUN BARU 🚀","callback_data":"cmd_create"}],'
                            kb+='[{"text":"⚙️ Kelola Akun","callback_data":"cmd_manage"},{"text":"📋 Daftar Akun","callback_data":"cmd_list"}],'
                            kb+='[{"text":"📊 Trafik Data","callback_data":"cmd_trafik"},{"text":"🟢 User Online","callback_data":"cmd_login"}],'
                            kb+='[{"text":"💻 Info Server","callback_data":"cmd_info"},{"text":"📦 Backup Data","callback_data":"cmd_backup"}]'
                            kb+=']}'
                            
                            send_msg "$MSG" "$kb"
                            ;;
                        /admin)
                            if [[ "$SENDER_ID" != "$CHAT_ID" ]]; then
                                send_msg "❌ <b>Akses Ditolak!</b>\nHanya Admin Utama (Owner) yang bisa mengatur akses admin."
                            elif [[ "$ARG1" == "add" && -n "$ARG2" ]]; then
                                echo "$ARG2" >> /etc/wibutunnel/bot_admins.db
                                send_msg "✅ <b>Berhasil!</b>\nID Telegram <code>$ARG2</code> telah ditambahkan sebagai admin bot."
                            elif [[ "$ARG1" == "del" && -n "$ARG2" ]]; then
                                sed -i "/^${ARG2}$/d" /etc/wibutunnel/bot_admins.db 2>/dev/null
                                send_msg "🗑️ <b>Berhasil!</b>\nID Telegram <code>$ARG2</code> telah dihapus dari admin bot."
                            elif [[ "$ARG1" == "list" ]]; then
                                adm_msg="📋 <b>Daftar Admin Bot:</b>\n1. <code>$CHAT_ID</code> (Utama)\n"
                                if [[ -f /etc/wibutunnel/bot_admins.db ]]; then
                                    i=2
                                    while read -r adm; do
                                        [[ -z "$adm" ]] && continue
                                        adm_msg+="${i}. <code>$adm</code>\n"
                                        ((i++))
                                    done < /etc/wibutunnel/bot_admins.db
                                fi
                                send_msg "$adm_msg"
                            else
                                send_msg "⚙️ <b>Menu Admin Multi-User:</b>\n├ <code>/admin add [ID_Telegram]</code>\n├ <code>/admin del [ID_Telegram]</code>\n└ <code>/admin list</code>\n\n<i>Keterangan: Minta rekan Anda mengecek ID Telegram mereka ke @userinfobot</i>"
                            fi
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
                        /trialvless|/trialvmess|/trialtrojan)
                            tr_proto=$(echo "$CMD" | sed 's/\/trial//g' | tr 'a-z' 'A-Z')
                            tr_waktu=${ARG1:-1h}
                            tr_bw=${ARG2:-1}
                            if [[ ! "$tr_bw" =~ ^[0-9]+$ ]]; then tr_bw=1; fi
                            
                            tr_user="trial-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 4)"
                            create_account "$tr_proto" "$tr_user" "$tr_waktu" "1" "$tr_bw"
                            ;;
                        /hapus)
                            [[ -n "$ARG1" ]] && delete_account "$ARG1" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/hapus nama_user</code>"
                            ;;
                        /renew)
                            [[ -n "$ARG1" && -n "$ARG2" ]] && renew_account "$ARG1" "$ARG2" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/renew nama_user 30</code>"
                            ;;
                        /list)
                            list_account
                            ;;
                        /detail)
                            [[ -n "$ARG1" ]] && detail_account "$ARG1" || send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>/detail nama_user</code>"
                            ;;
                        /backup)
                            backup_vps
                            ;;
                        /info)
                            IP=$(curl -sS --max-time 3 ipv4.icanhazip.com 2>/dev/null)
                            UPTIME=$(uptime -p | cut -d' ' -f2-)
                            RAM=$(free -m | awk '/Mem:/ {print $3" MB / "$2" MB"}')
                            CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
                            DISK=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')
                            OS=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
                            
                            INFO_MSG="💻 <b>INFORMASI VPS SERVER</b>\n"
                            INFO_MSG+="━━━━━━━━━━━━━━━━━━━━\n"
                            INFO_MSG+="<b>🖥 OS     :</b> <code>${OS}</code>\n"
                            INFO_MSG+="<b>🌐 IP     :</b> <code>${IP}</code>\n"
                            INFO_MSG+="<b>⏱ Uptime :</b> <code>${UPTIME}</code>\n"
                            INFO_MSG+="<b>🧠 RAM    :</b> <code>${RAM}</code>\n"
                            INFO_MSG+="<b>⚡️ CPU    :</b> <code>${CPU}%</code>\n"
                            INFO_MSG+="<b>💾 Disk   :</b> <code>${DISK}</code>\n"
                            INFO_MSG+="━━━━━━━━━━━━━━━━━━━━"
                            send_msg "$INFO_MSG"
                            ;;
                        /lock|/unlock)
                            if [[ -z "$ARG1" ]]; then
                                send_msg "❌ <b>Format Salah!</b>\nGunakan: <code>$CMD nama_user</code>"
                            else
                                DB_LOCK="/etc/wibutunnel/locked_users.db"
                                if [[ "$CMD" == "/lock" ]]; then
                                    if grep -q "^${ARG1}:" "$DB_LOCK" 2>/dev/null; then
                                        send_msg "⚠️ Akun <code>$ARG1</code> sudah dalam status TERKUNCI."
                                    elif jq -e --arg u "$ARG1" '[.inbounds[].settings.clients[]?.email, .inbounds[].settings.clients[]?.password] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
                                        jq --arg user "$ARG1" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= (. + [$user] | unique)' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
                                        echo "$ARG1:$(date +%s):0:LOCK" >> "$DB_LOCK"
                                        systemctl restart xray >/dev/null 2>&1
                                        send_msg "🔒 <b>Berhasil!</b>\nAkun <code>$ARG1</code> telah DIKUNCI (Dipindahkan ke Recovery)."
                                    else
                                        send_msg "❌ <b>Gagal!</b>\nAkun <code>$ARG1</code> tidak ditemukan."
                                    fi
                                elif [[ "$CMD" == "/unlock" ]]; then
                                    if grep -q "^${ARG1}:" "$DB_LOCK" 2>/dev/null; then
                                        jq --arg u "$ARG1" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"
                                        sed -i "/^${ARG1}:/d" "$DB_LOCK" 2>/dev/null
                                        systemctl restart xray >/dev/null 2>&1
                                        send_msg "🔓 <b>Berhasil!</b>\nAkun <code>$ARG1</code> telah DI-UNLOCK dan dapat digunakan kembali."
                                    else
                                        send_msg "⚠️ Akun <code>$ARG1</code> tidak dalam status terkunci."
                                    fi
                                fi
                            fi
                            ;;
                        /cek_trafik)
                            if [[ -s "/etc/wibutunnel/user_usage.db" ]]; then
                                TRF_MSG="📊 <b>TOP 10 PEMAKAIAN QUOTA</b>\n━━━━━━━━━━━━━━━━━━━━\n"
                                idx=1
                                while IFS=":" read -r bytes usr; do
                                    if [[ "$bytes" -ge 1073741824 ]]; then
                                        gb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1073741824 }')
                                        vol="${gb} GB"
                                    elif [[ "$bytes" -ge 1048576 ]]; then
                                        mb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1048576 }')
                                        vol="${mb} MB"
                                    elif [[ "$bytes" -ge 1024 ]]; then
                                        kb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1024 }')
                                        vol="${kb} KB"
                                    else
                                        vol="${bytes} Bytes"
                                    fi
                                    if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto="VLESS"
                                    elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto="VMESS"
                                    elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto="TROJAN"
                                    else continue
                                    fi
                                    TRF_MSG+="<b>${idx}.</b> <code>${usr}</code> [${proto}] : ${vol}\n"
                                    ((idx++))
                                    [[ $idx -gt 10 ]] && break
                                done < <(awk -F':' '{ 
                                    if ($1 ~ /^(vless|vmess|trojan)-(ws|grpc)-(tls|ntls)$/ || $1 ~ /^(vless|vmess|trojan)-grpc$/ || $1 == "api" || $1 == "direct" || $1 == "blocked") next;
                                    down=($2=="null"||$2=="")?0:$2; 
                                    up=($3=="null"||$3=="")?0:$3; 
                                    print (down+up)":"$1 
                                }' /etc/wibutunnel/user_usage.db 2>/dev/null | sort -t: -k1 -nr)
                                TRF_MSG+="━━━━━━━━━━━━━━━━━━━━"
                                send_msg "$TRF_MSG"
                            else
                                send_msg "📊 <b>Belum ada data trafik pemakaian.</b>"
                            fi
                            ;;
                        /cek_login)
                            LOG_FILE="/var/log/xray/access.log"
                            if [[ ! -s "$LOG_FILE" ]]; then
                                send_msg "❌ <b>Belum ada data log aktif (kosong).</b>"
                                continue
                            fi
                            
                            # [MATA ELANG V2 - NEW LOGIC] Deteksi real IP via Log 3 Menit (Support Cloudflare/CDN)
                            THRESH=$(date -d '3 minutes ago' +'%Y/%m/%d %H:%M:%S')
                            LOGIN_DATA=$(awk -v thresh="$THRESH" '$1" "$2 >= thresh && /accepted/ { for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]", " : "") ip; counts[email]++ } } } END { for (e in ips) print e "|" counts[e] "|" ips[e] }' <(tail -n 50000 "$LOG_FILE" 2>/dev/null) 2>/dev/null)

                            if [[ -z "$LOGIN_DATA" ]]; then
                                send_msg "🟢 <b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n<i>Saat ini tidak ada user yang aktif.</i>\n━━━━━━━━━━━━━━━━━━━━"
                            else
                                LOG_MSG="🟢 <b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n"
                                while IFS="|" read -r usr count iplist; do
                                    if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto="VLESS"
                                    elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto="VMESS"
                                    elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto="TROJAN"
                                    else continue
                                    fi
                                    LOG_MSG+="👤 <code>${usr}</code> [${proto}]\n└ 🌐 IP: ${iplist} (${count} Login)\n\n"
                                done <<< "$LOGIN_DATA"
                                LOG_MSG+="━━━━━━━━━━━━━━━━━━━━"
                                send_msg "$LOG_MSG"
                            fi
                            ;;
                    esac
                fi
                
                # Handle Callback Queries
                CB_ID=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.id // empty")
                if [[ -n "$CB_ID" ]]; then
                    SENDER_ID=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.message.chat.id")
                    MESSAGE_ID=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.message.message_id")
                    DATA=$(echo "$UPDATES" | jq -r ".result[$i].callback_query.data // empty")
                    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery?callback_query_id=${CB_ID}" >/dev/null
                    
                    if is_admin "$SENDER_ID"; then
                        case "$DATA" in
                            cmd_list) list_account ;;
                            cmd_trafik) TEXT="/cek_trafik"; CMD="/cek_trafik" ;; # Trigger text parsing below or call directly
                            cmd_login) TEXT="/cek_login"; CMD="/cek_login" ;;
                            cmd_info) TEXT="/info"; CMD="/info" ;;
                            cmd_backup) backup_vps ;;
                            cmd_create)
                                msg_create="✨ <b>PANDUAN MEMBUAT AKUN</b> ✨\n━━━━━━━━━━━━━━━━━━━━\n"
                                msg_create+="Ketik perintah manual di chat:\n\n"
                                msg_create+="💎 <b>VLESS:</b>\n<code>/vless [nama] [hari] [ip] [gb]</code>\n"
                                msg_create+="🌀 <b>VMESS:</b>\n<code>/vmess [nama] [hari] [ip] [gb]</code>\n"
                                msg_create+="⚡️ <b>TROJAN:</b>\n<code>/trojan [nama] [hari] [ip] [gb]</code>\n\n"
                                msg_create+="<b>Contoh:</b> <code>/vless budi 30 2 10</code>\n"
                                msg_create+="<b>Trial:</b> <code>/trialvless 1h 1</code>\n━━━━━━━━━━━━━━━━━━━━"
                                kb_back='{"inline_keyboard":[[{"text":"🔙 Kembali ke Menu","callback_data":"cmd_menu"}]]}'
                                edit_msg "$msg_create" "$kb_back"
                                ;;
                                                        cmd_menu)
                                MSG="━━━━━━━━━━━━━━━━━━━━\n 🤖 <b>WIBUTUNNEL PANEL BOT</b>\n━━━━━━━━━━━━━━━━━━━━\n\nSelamat datang di Panel Kendali VPS. Silakan pilih menu di bawah ini:"
                                kb='{"inline_keyboard":['
                                kb+='[{"text":"🚀 BUAT AKUN BARU 🚀","callback_data":"cmd_create"}],'
                                kb+='[{"text":"⚙️ Kelola Akun","callback_data":"cmd_manage"},{"text":"📋 Daftar Akun","callback_data":"cmd_list"}],'
                                kb+='[{"text":"📊 Trafik Data","callback_data":"cmd_trafik"},{"text":"🟢 User Online","callback_data":"cmd_login"}],'
                                kb+='[{"text":"💻 Info Server","callback_data":"cmd_info"},{"text":"📦 Backup Data","callback_data":"cmd_backup"}]'
                                kb+=']}'
                                edit_msg "$MSG" "$kb"
                                ;;
                            cmd_manage)
                                msg_manage="⚙️ <b>PANDUAN KELOLA AKUN</b> ⚙️\n━━━━━━━━━━━━━━━━━━━━\n"
                                msg_manage+="Ketik perintah manual di chat:\n\n"
                                msg_manage+="🗑 <b>Hapus Akun:</b>\n<code>/hapus [nama]</code>\n"
                                msg_manage+="🔄 <b>Perpanjang:</b>\n<code>/renew [nama] [hari]</code>\n"
                                msg_manage+="🔗 <b>Cek Link Akun:</b>\n<code>/detail [nama]</code>\n"
                                msg_manage+="🔒 <b>Kunci (Lock):</b>\n<code>/lock [nama]</code>\n"
                                msg_manage+="🔓 <b>Buka (Unlock):</b>\n<code>/unlock [nama]</code>\n━━━━━━━━━━━━━━━━━━━━"
                                kb_back='{"inline_keyboard":[[{"text":"🔙 Kembali ke Menu","callback_data":"cmd_menu"}]]}'
                                edit_msg "$msg_manage" "$kb_back"
                                ;;
                        esac
                        
                        # Hack to reuse existing commands for simple ones
                        if [[ "$DATA" == "cmd_trafik" || "$DATA" == "cmd_login" || "$DATA" == "cmd_info" ]]; then
                            # Copy from above
                            if [[ "$DATA" == "cmd_info" ]]; then
                                IP=$(curl -sS --max-time 3 ipv4.icanhazip.com 2>/dev/null)
                                UPTIME=$(uptime -p | cut -d' ' -f2-)
                                RAM=$(free -m | awk '/Mem:/ {print $3" MB / "$2" MB"}')
                                CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
                                DISK=$(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')
                                OS=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
                                INFO_MSG="💻 <b>INFORMASI VPS SERVER</b>\n━━━━━━━━━━━━━━━━━━━━\n<b>🖥 OS     :</b> <code>${OS}</code>\n<b>🌐 IP     :</b> <code>${IP}</code>\n<b>⏱ Uptime :</b> <code>${UPTIME}</code>\n<b>🧠 RAM    :</b> <code>${RAM}</code>\n<b>⚡️ CPU    :</b> <code>${CPU}%</code>\n<b>💾 Disk   :</b> <code>${DISK}</code>\n━━━━━━━━━━━━━━━━━━━━"
                                send_msg "$INFO_MSG"
                            elif [[ "$DATA" == "cmd_trafik" ]]; then
                                if [[ -s "/etc/wibutunnel/user_usage.db" ]]; then
                                    TRF_MSG="📊 <b>TOP 10 PEMAKAIAN QUOTA</b>\n━━━━━━━━━━━━━━━━━━━━\n"
                                    idx=1
                                    while IFS=":" read -r bytes usr; do
                                        if [[ "$bytes" -ge 1073741824 ]]; then gb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1073741824 }'); vol="${gb} GB"
                                        elif [[ "$bytes" -ge 1048576 ]]; then mb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1048576 }'); vol="${mb} MB"
                                        elif [[ "$bytes" -ge 1024 ]]; then kb=$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1024 }'); vol="${kb} KB"
                                        else vol="${bytes} Bytes"; fi
                                        if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto="VLESS"; elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto="VMESS"; elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto="TROJAN"; else continue; fi
                                        TRF_MSG+="<b>${idx}.</b> <code>${usr}</code> [${proto}] : ${vol}\n"
                                        ((idx++)); [[ $idx -gt 10 ]] && break
                                    done < <(awk -F':' '{ if ($1 ~ /^(vless|vmess|trojan)-(ws|grpc)-(tls|ntls)$/ || $1 ~ /^(vless|vmess|trojan)-grpc$/ || $1 == "api" || $1 == "direct" || $1 == "blocked") next; down=($2=="null"||$2=="")?0:$2; up=($3=="null"||$3=="")?0:$3; print (down+up)":"$1 }' /etc/wibutunnel/user_usage.db 2>/dev/null | sort -t: -k1 -nr)
                                    TRF_MSG+="━━━━━━━━━━━━━━━━━━━━"
                                    send_msg "$TRF_MSG"
                                else
                                    send_msg "📊 <b>Belum ada data trafik pemakaian.</b>"
                                fi
                            elif [[ "$DATA" == "cmd_login" ]]; then
                                LOG_FILE="/var/log/xray/access.log"
                                if [[ ! -s "$LOG_FILE" ]]; then send_msg "❌ <b>Belum ada data log aktif (kosong).</b>"; else
                                    # [MATA ELANG V2 - NEW LOGIC] Deteksi real IP via Log 3 Menit (Support Cloudflare/CDN)
                                    THRESH=$(date -d '3 minutes ago' +'%Y/%m/%d %H:%M:%S')
                                    LOGIN_DATA=$(awk -v thresh="$THRESH" '$1" "$2 >= thresh && /accepted/ { for(i=1;i<=NF;i++){ if($i=="accepted"){ ip=$(i-1); sub(/^(tcp|udp):/, "", ip); sub(/:[0-9]+$/, "", ip); break } }; email=$NF; gsub(/[^a-zA-Z0-9_-]/, "", email); if(email != "dummy" && email != "api" && ip != "127.0.0.1" && ip != "") { if (!seen[email, ip]++) { ips[email] = (ips[email] ? ips[email]", " : "") ip; counts[email]++ } } } END { for (e in ips) print e "|" counts[e] "|" ips[e] }' <(tail -n 50000 "$LOG_FILE" 2>/dev/null) 2>/dev/null)
                                    if [[ -z "$LOGIN_DATA" ]]; then send_msg "🟢 <b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n<i>Saat ini tidak ada user yang aktif.</i>\n━━━━━━━━━━━━━━━━━━━━"; else
                                        LOG_MSG="🟢 <b>ONLINE USERS (LIVE)</b>\n━━━━━━━━━━━━━━━━━━━━\n"
                                        while IFS="|" read -r usr count iplist; do
                                            if grep -q "^${usr}:" /etc/xray/vless_exp.conf 2>/dev/null; then proto="VLESS"; elif grep -q "^${usr}:" /etc/xray/vmess_exp.conf 2>/dev/null; then proto="VMESS"; elif grep -q "^${usr}:" /etc/xray/trojan_exp.conf 2>/dev/null; then proto="TROJAN"; else continue; fi
                                            LOG_MSG+="👤 <code>${usr}</code> [${proto}]\n└ 🌐 IP: ${iplist} (${count} Login)\n\n"
                                        done <<< "$LOGIN_DATA"
                                        LOG_MSG+="━━━━━━━━━━━━━━━━━━━━"
                                        send_msg "$LOG_MSG"
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi

                echo "$((UPDATE_ID + 1))" > $OFFSET_FILE
            done
        fi
    fi
    sleep 1
done
