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
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -F "chat_id=${target_id}" -F "parse_mode=html" -F "text=${text}" >/dev/null 2>&1
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
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&encryption=none&host=${domain}&type=ws#${user}"
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

    local THICKLINE="----------------------------------------"
    local pesan="${THICKLINE}\n"
    pesan+="               <b>${proto}</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>Remarks        :</b> <code>${user}</code>\n"
    pesan+="<b>CITY           :</b> <code>${CITY}</code>\n"
    pesan+="<b>ISP            :</b> <code>${ISP}</code>\n"
    pesan+="<b>Domain         :</b> <code>${domain}</code>\n"
    pesan+="<b>Limit IP       :</b> <code>${limit_ip}</code>\n"
    pesan+="<b>Limit Kuota    :</b> <code>${limit_bw}</code>\n"
    pesan+="<b>Port TLS       :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port none TLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>id             :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/vmess</code>\n"
        pesan+="<b>serviceName    :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>id             :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption     :</b> <code>none</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/vless</code>\n"
        pesan+="<b>serviceName    :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/trojan</code>\n"
        pesan+="<b>serviceName    :</b> <code>trojan</code>\n"
    fi

    pesan+="<b>Expired On     :</b> <code>${tampil_exp}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="            <b>${proto} WS TLS</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<code>${link1}</code>\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="${THICKLINE}\n"
        pesan+="          <b>${proto} WS NO TLS</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link2}</code>\n"
        pesan+="${THICKLINE}\n"
        pesan+="             <b>${proto} GRPC</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link3}</code>\n"
    else
        pesan+="${THICKLINE}\n"
        pesan+="             <b>${proto} GRPC</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link2}</code>\n"
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

    local new_exp=$(date -d "+${hari} days" +"%Y-%m-%d %H:%M:%S")
    local tampil_exp=$(date -d "+${hari} days" +"%Y-%m-%d")
    sed -i "s/^${user}:.*/${user}:${new_exp}/" "$exp_file"
    
    send_msg "✅ <b>Berhasil Perpanjang Akun!</b>\n\n<b>User :</b> <code>${user}</code>\n<b>Ditambah :</b> ${hari} Hari\n<b>Expired Baru :</b> <code>${tampil_exp}</code>"
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
    send_msg "⏳ <b>Sedang merakit file backup...</b>"
    
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
        local caption=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${tgl}</code>\n\n<i>File dienkripsi menggunakan CHAT ID Anda.</i>")
        local response=$(curl -s --max-time 60 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
            -F "chat_id=${target_id}" \
            -F "document=@${backup_file}" \
            -F "caption=${caption}" \
            -F "parse_mode=html")
            
        local file_id=$(echo "$response" | jq -r '.result.document.file_id // empty')
        
        if [[ -n "$file_id" ]]; then
            local restore_msg=$(echo -e "🔑 <b>DATA RESTORE:</b>\n\n<code>${file_id}</code>\n\n🔐 <b>Password:</b> CHAT ID Anda")
            curl -s --max-time 15 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -F "chat_id=${target_id}" \
                -F "parse_mode=html" \
                -F "text=${restore_msg}" >/dev/null 2>&1
        fi
        
        rm -f "$backup_file"
    else
        send_msg "❌ <b>Gagal membuat backup!</b>"
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
        link2="vless://${uuid}@${domain}:80?path=/vless-ntls&encryption=none&host=${domain}&type=ws#${user}"
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

    local THICKLINE="----------------------------------------"
    local pesan="${THICKLINE}\n"
    pesan+="               <b>${proto}</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<b>Remarks        :</b> <code>${user}</code>\n"
    pesan+="<b>CITY           :</b> <code>${CITY}</code>\n"
    pesan+="<b>ISP            :</b> <code>${ISP}</code>\n"
    pesan+="<b>Domain         :</b> <code>${domain}</code>\n"
    pesan+="<b>Limit IP       :</b> <code>${limit_ip}</code>\n"
    pesan+="<b>Limit Kuota    :</b> <code>${limit_bw}</code>\n"
    pesan+="<b>Port TLS       :</b> <code>443</code>\n"
    
    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="<b>Port none TLS  :</b> <code>80</code>\n"
    fi
    
    if [[ "$proto" == "VMESS" ]]; then
        pesan+="<b>id             :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/vmess</code>\n"
        pesan+="<b>serviceName    :</b> <code>vmess</code>\n"
    elif [[ "$proto" == "VLESS" ]]; then
        pesan+="<b>id             :</b> <code>${uuid}</code>\n"
        pesan+="<b>Encryption     :</b> <code>none</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/vless</code>\n"
        pesan+="<b>serviceName    :</b> <code>vless</code>\n"
    elif [[ "$proto" == "TROJAN" ]]; then
        pesan+="<b>Password       :</b> <code>${uuid}</code>\n"
        pesan+="<b>Network        :</b> <code>ws,grpc</code>\n"
        pesan+="<b>Path ws        :</b> <code>/trojan</code>\n"
        pesan+="<b>serviceName    :</b> <code>trojan</code>\n"
    fi

    pesan+="<b>Expired On     :</b> <code>${exp_date}</code>\n"
    pesan+="${THICKLINE}\n"
    pesan+="            <b>${proto} WS TLS</b>\n"
    pesan+="${THICKLINE}\n"
    pesan+="<code>${link1}</code>\n"

    if [[ "$proto" != "TROJAN" ]]; then
        pesan+="${THICKLINE}\n"
        pesan+="          <b>${proto} WS NO TLS</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link2}</code>\n"
        pesan+="${THICKLINE}\n"
        pesan+="             <b>${proto} GRPC</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link3}</code>\n"
    else
        pesan+="${THICKLINE}\n"
        pesan+="             <b>${proto} GRPC</b>\n"
        pesan+="${THICKLINE}\n"
        pesan+="<code>${link2}</code>\n"
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
                TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text")

                if is_admin "$SENDER_ID"; then
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
                            MSG+="├ <code>/renew [user] [hari]</code>\n"
                            MSG+="├ <code>/list</code> (Daftar Akun)\n"
                            MSG+="├ <code>/detail [user]</code> (Tampilkan Link)\n"
                            MSG+="├ <code>/admin</code> (Tambah Akses)\n"
                            MSG+="├ <code>/backup</code> (Backup Database VPS)\n"
                            MSG+="└ <code>/info</code> (Cek status VPS)\n\n"
                            MSG+="━━━━━━━━━━━━━━━━━━━━\n"
                            MSG+="<i>Contoh: /vless budi 30 2 10</i>\n"
                            MSG+="<i>(Membuat VLESS 'budi' 30 hr, limit 2 IP, limit 10 GB)</i>"
                            send_msg "$MSG"
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
                                local adm_msg="📋 <b>Daftar Admin Bot:</b>\n1. <code>$CHAT_ID</code> (Utama)\n"
                                if [[ -f /etc/wibutunnel/bot_admins.db ]]; then
                                    local i=2
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
