#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-vless.sh (v4.0 RECOVERY)
# [FIX] jq exact match + THICKLINE encoding fix
# ==========================================

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi
check_license

source /etc/wibutunnel/bot.conf 2>/dev/null
CONFIG_FILE="/usr/local/etc/xray/config.json"
DOMAIN_FILE="/etc/xray/domain"
EXP_FILE="/etc/xray/vless_exp.conf"
DB_IP="/etc/wibutunnel/limit_ip.db"
DB_BW="/etc/wibutunnel/limit_bw.db"
DB_LOCK="/etc/wibutunnel/locked_users.db"

THICKLINE="----------------------------------------"

mkdir -p /etc/xray
touch "$EXP_FILE"

user_json_exists() {
    jq -e --arg u "$1" '[.inbounds[].settings.clients[]?.email] | index($u) != null' "$CONFIG_FILE" >/dev/null 2>&1
}

select_user() {
    local ACTION_TITLE=$1
    local DISPLAY_TYPE=$2
    mapfile -t user_array < <(jq -r '.inbounds[1].settings.clients[].email' "$CONFIG_FILE" | grep -v "dummy" | sort)
    TOTAL_USERS=${#user_array[@]}
    if [ "$TOTAL_USERS" -eq 0 ]; then
        echo -e "${YELLOW}Belum ada akun VLESS.${NC}"
        read -p "Tekan Enter..." dummy
        SELECTED_USER=""
        return
    fi

    clear; echo -e "${LINE}"; echo -e "             ${WHITE}${ACTION_TITLE}${NC}"; echo -e "${LINE}"
    for i in "${!user_array[@]}"; do
        u="${user_array[$i]}"
        if [[ "$DISPLAY_TYPE" == "IP" ]]; then
            val=$(grep "^${u}:" "$DB_IP" 2>/dev/null | cut -d: -f2)
            [[ -z "$val" || "$val" == "0" ]] && val="Bebas" || val="${val} IP"
            color="${CYAN}"
        elif [[ "$DISPLAY_TYPE" == "BW" ]]; then
            val=$(grep "^${u}:" "$DB_BW" 2>/dev/null | cut -d: -f2)
            [[ -z "$val" || "$val" == "0" ]] && val="Unlimited" || val="${val} GB"
            color="${CYAN}"
        else
            val=$(grep "^${u}:" "$EXP_FILE" | cut -d: -f2- | tail -n 1)
            is_locked=$(grep -q "^${u}:" "$DB_LOCK" 2>/dev/null && echo " ${RED}LOCKED${NC}" || echo "")
            [[ -z "$val" ]] && val="Lifetime"
            color="${YELLOW}Exp: "
        fi
        printf " ${GREEN}%2d.${NC} %-15s ${color}%s${NC}%b\n" "$((i+1))" "$u" "$val" "$is_locked"
    done
    echo -e "${LINE}\n ${CYAN}Total: ${TOTAL_USERS} users${NC}\n${LINE}"
    read -p " Pilih [Nomor/Nama] / [0] Batal: " sel

    if [[ -z "$sel" ]] || [[ "$sel" == "0" ]]; then SELECTED_USER=""; return
    elif [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -le "$TOTAL_USERS" ] && [ "$sel" -ge 1 ]; then SELECTED_USER="${user_array[$((sel-1))]}"; return
    elif user_json_exists "$sel" && [[ "$sel" != *"dummy"* ]]; then sanitize_user "$sel" || { echo -e "\n ${RED}Pilihan tidak valid!${NC}"; sleep 1; SELECTED_USER=""; return; }; SELECTED_USER="$sel"; return
    else echo -e "\n ${RED}Pilihan tidak valid!${NC}"; sleep 1; SELECTED_USER=""; fi
}

add_user() {
    clear; echo -e "${LINE}"; echo -e "               ${WHITE}BUAT AKUN VLESS${NC}"; echo -e "${LINE}"
    if [ ! -f "$CONFIG_FILE" ]; then echo -e "${RED}ERROR: Xray belum terinstal!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Masukkan Nama User : " user
    [[ -z "$user" ]] && return
    sanitize_user "$user" || { echo -e "${RED}Error: Karakter tidak valid! Hanya a-zA-Z0-9._@-${NC}"; read -p "Enter..." dummy; return; }
    if user_json_exists "$user"; then echo -e "${RED}Error: User sudah ada!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Masa Aktif (Hari)  : " masaaktif
    if [[ "$masaaktif" =~ ^[0-9]+$ ]] && [ "$masaaktif" -gt 0 ]; then
        exp_date=$(date -d "+${masaaktif} days" +"%Y-%m-%d %H:%M:%S")
        tampil_exp=$(date -d "$exp_date" +"%Y-%m-%d")
    else echo -e "${RED}Error: Angka tidak valid!${NC}"; read -p "Enter..." dummy; return; fi

    read -p "Limit IP (0 = Bebas): " limit_ip
    read -p "Limit Kuota GB (0 = Unli): " limit_kuota
    [[ -z "$limit_ip" ]] && limit_ip=0
    [[ -z "$limit_kuota" ]] && limit_kuota=0

    uuid=$(uuidgen); domain=$(cat "$DOMAIN_FILE")

    jq --arg uuid "$uuid" --arg user "$user" '
        .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}] |
        .inbounds[2].settings.clients += [{"id": $uuid, "email": $user}] |
        .inbounds[3].settings.clients += [{"id": $uuid, "email": $user}]
    ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"

    echo "${user}:${exp_date}" >> "$EXP_FILE"
    sed -i "/^${user}:/d" "$DB_IP" 2>/dev/null; sed -i "/^${user}:/d" "$DB_BW" 2>/dev/null
    echo "${user}:${limit_ip}" >> "$DB_IP"
    echo "${user}:${limit_kuota}" >> "$DB_BW"
    systemctl restart xray >/dev/null 2>&1

    vless_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
    vless_ntls="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
    vless_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"

    CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null); ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"

    PESAN_AKUN="${THICKLINE}
               VLESS
${THICKLINE}
Remarks        : ${user}
CITY           : ${CITY}
ISP            : ${ISP}
Domain         : ${domain}
Limit IP       : ${limit_ip}
Limit Kuota    : ${limit_kuota} GB
Port TLS       : 443
Port none TLS  : 80
id             : ${uuid}
Encryption     : none
Network        : ws,grpc
Path ws        : /vless
serviceName    : vless
Expired On     : ${tampil_exp}
${THICKLINE}
            VLESS WS TLS
${THICKLINE}
${vless_tls}
${THICKLINE}
          VLESS WS NO TLS
${THICKLINE}
${vless_ntls}
${THICKLINE}
             VLESS GRPC
${THICKLINE}
${vless_grpc}
${THICKLINE}"
    clear; echo -e "$PESAN_AKUN"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_HTML="${THICKLINE}
               <b>VLESS</b>
${THICKLINE}
<b>Remarks        :</b> <code>${user}</code>
<b>CITY           :</b> <code>${CITY}</code>
<b>ISP            :</b> <code>${ISP}</code>
<b>Domain         :</b> <code>${domain}</code>
<b>Port TLS       :</b> <code>443</code>
<b>Port none TLS  :</b> <code>80</code>
<b>id             :</b> <code>${uuid}</code>
<b>Encryption     :</b> <code>none</code>
<b>Network        :</b> <code>ws,grpc</code>
<b>Path ws        :</b> <code>/vless</code>
<b>serviceName    :</b> <code>vless</code>
<b>Expired On     :</b> <code>${tampil_exp}</code>
${THICKLINE}
            <b>VLESS WS TLS</b>
${THICKLINE}
<code>${vless_tls}</code>
${THICKLINE}
          <b>VLESS WS NO TLS</b>
${THICKLINE}
<code>${vless_ntls}</code>
${THICKLINE}
             <b>VLESS GRPC</b>
${THICKLINE}
<code>${vless_grpc}</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "disable_web_page_preview=true" --data-urlencode "parse_mode=html" --data-urlencode "text=${PESAN_HTML}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

trial_user() {
    clear; echo -e "${LINE}"; echo -e "            ${WHITE}BUAT AKUN VLESS TRIAL${NC}"; echo -e "${LINE}"
    if [ ! -f "$CONFIG_FILE" ]; then echo -e "${RED}ERROR: Xray belum terinstal!${NC}"; read -p "Enter..." dummy; return; fi

    user="trial-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 4)"
    while user_json_exists "$user"; do user="trial-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 5)"; done

    read -p "Masukkan Waktu (Contoh: 20m, 1h, 1d) : " waktu
    if [[ "$waktu" =~ ^[0-9]+m$ ]]; then exp_date=$(date -d "+${waktu%m} minutes" +"%Y-%m-%d %H:%M:%S")
    elif [[ "$waktu" =~ ^[0-9]+h$ ]]; then exp_date=$(date -d "+${waktu%h} hours" +"%Y-%m-%d %H:%M:%S")
    elif [[ "$waktu" =~ ^[0-9]+d$ ]]; then exp_date=$(date -d "+${waktu%d} days" +"%Y-%m-%d %H:%M:%S")
    else echo -e "${RED}Error: Format salah!${NC}"; read -p "Enter..." dummy; return; fi

    uuid=$(uuidgen); domain=$(cat "$DOMAIN_FILE")

    jq --arg uuid "$uuid" --arg user "$user" '
        .inbounds[1].settings.clients += [{"id": $uuid, "email": $user}] |
        .inbounds[2].settings.clients += [{"id": $uuid, "email": $user}] |
        .inbounds[3].settings.clients += [{"id": $uuid, "email": $user}]
    ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"

    echo "${user}:${exp_date}" >> "$EXP_FILE"
    sed -i "/^${user}:/d" "$DB_IP" 2>/dev/null; sed -i "/^${user}:/d" "$DB_BW" 2>/dev/null
    echo "${user}:0" >> "$DB_IP"; echo "${user}:0" >> "$DB_BW"
    systemctl restart xray >/dev/null 2>&1

    vless_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
    vless_ntls="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
    vless_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"

    CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null); ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"

    PESAN_AKUN="${THICKLINE}
             VLESS TRIAL
${THICKLINE}
Remarks        : ${user}
CITY           : ${CITY}
ISP            : ${ISP}
Domain         : ${domain}
Port TLS       : 443
Port none TLS  : 80
id             : ${uuid}
Encryption     : none
Network        : ws,grpc
Path ws        : /vless
serviceName    : vless
Expired On     : ${exp_date}
${THICKLINE}
          VLESS WS TLS
${THICKLINE}
${vless_tls}
${THICKLINE}
        VLESS WS NO TLS
${THICKLINE}
${vless_ntls}
${THICKLINE}
           VLESS GRPC
${THICKLINE}
${vless_grpc}
${THICKLINE}"
    clear; echo -e "$PESAN_AKUN"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_HTML="${THICKLINE}
               <b>VLESS TRIAL</b>
${THICKLINE}
<b>Remarks        :</b> <code>${user}</code>
<b>CITY           :</b> <code>${CITY}</code>
<b>ISP            :</b> <code>${ISP}</code>
<b>Domain         :</b> <code>${domain}</code>
<b>Port TLS       :</b> <code>443</code>
<b>Port none TLS  :</b> <code>80</code>
<b>id             :</b> <code>${uuid}</code>
<b>Encryption     :</b> <code>none</code>
<b>Network        :</b> <code>ws,grpc</code>
<b>Path ws        :</b> <code>/vless</code>
<b>serviceName    :</b> <code>vless</code>
<b>Expired On     :</b> <code>${exp_date}</code>
${THICKLINE}
            <b>VLESS WS TLS</b>
${THICKLINE}
<code>${vless_tls}</code>
${THICKLINE}
          <b>VLESS WS NO TLS</b>
${THICKLINE}
<code>${vless_ntls}</code>
${THICKLINE}
             <b>VLESS GRPC</b>
${THICKLINE}
<code>${vless_grpc}</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "disable_web_page_preview=true" --data-urlencode "parse_mode=html" --data-urlencode "text=${PESAN_HTML}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

delete_user() {
    select_user "HAPUS AKUN VLESS" "EXP"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    if [[ "$user" == *"trial"* ]]; then
        echo -e "\n${GREEN}Akun Trial '$user' berhasil dimusnahkan permanen!${NC}"
    else
        echo -e "\n${GREEN}Akun '$user' berhasil dimusnahkan permanen!${NC}"
    fi
    jq --arg user "$user" '
        .inbounds[1].settings.clients |= map(select(.email != $user)) |
        .inbounds[2].settings.clients |= map(select(.email != $user)) |
        .inbounds[3].settings.clients |= map(select(.email != $user)) |
        (.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $user))
    ' "$CONFIG_FILE" > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json "$CONFIG_FILE"

    sed -i "/^${user}:/d" "$EXP_FILE"
    sed -i "/^${user}:/d" "$DB_IP" 2>/dev/null; sed -i "/^${user}:/d" "$DB_BW" 2>/dev/null
    sed -i "/^${user}:/d" "$DB_LOCK" 2>/dev/null; sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
    systemctl restart xray >/dev/null 2>&1
    echo ""; read -p "Tekan Enter..." dummy
}

cek_user() {
    select_user "CEK & TAMPILKAN AKUN VLESS" "EXP"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    uuid=$(jq -r --arg email "$user" '.inbounds[1].settings.clients[] | select(.email == $email) | .id' "$CONFIG_FILE")
    domain=$(cat "$DOMAIN_FILE")
    exp_date=$(grep "^${user}:" "$EXP_FILE" | cut -d: -f2- | tail -n 1)
    [[ -z "$exp_date" ]] && exp_date="Lifetime"

    vless_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&host=${domain}&type=ws&sni=${domain}#${user}"
    vless_ntls="vless://${uuid}@${domain}:80?path=/vless-ntls&security=none&encryption=none&host=${domain}&type=ws#${user}"
    vless_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless&sni=${domain}#${user}"

    CITY=$(curl -s ip-api.com/line?fields=city 2>/dev/null); ISP=$(curl -s ip-api.com/line?fields=isp 2>/dev/null)
    [[ -z "$CITY" ]] && CITY="Unknown"; [[ -z "$ISP" ]] && ISP="Unknown"

    PESAN_AKUN="${THICKLINE}
               VLESS
${THICKLINE}
Remarks        : ${user}
CITY           : ${CITY}
ISP            : ${ISP}
Domain         : ${domain}
Port TLS       : 443
Port none TLS  : 80
id             : ${uuid}
Encryption     : none
Network        : ws,grpc
Path ws        : /vless
serviceName    : vless
Expired On     : ${exp_date}
${THICKLINE}
            VLESS WS TLS
${THICKLINE}
${vless_tls}
${THICKLINE}
          VLESS WS NO TLS
${THICKLINE}
${vless_ntls}
${THICKLINE}
             VLESS GRPC
${THICKLINE}
${vless_grpc}
${THICKLINE}"
    clear; echo -e "$PESAN_AKUN"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_HTML="<b>VLESS - CEK AKUN</b>
${THICKLINE}
<b>Remarks        :</b> <code>${user}</code>
<b>CITY           :</b> <code>${CITY}</code>
<b>ISP            :</b> <code>${ISP}</code>
<b>Domain         :</b> <code>${domain}</code>
<b>Port TLS       :</b> <code>443</code>
<b>Port none TLS  :</b> <code>80</code>
<b>id             :</b> <code>${uuid}</code>
<b>Encryption     :</b> <code>none</code>
<b>Network        :</b> <code>ws,grpc</code>
<b>Path ws        :</b> <code>/vless</code>
<b>serviceName    :</b> <code>vless</code>
<b>Expired On     :</b> <code>${exp_date}</code>
${THICKLINE}
            <b>VLESS WS TLS</b>
${THICKLINE}
<code>${vless_tls}</code>
${THICKLINE}
          <b>VLESS WS NO TLS</b>
${THICKLINE}
<code>${vless_ntls}</code>
${THICKLINE}
             <b>VLESS GRPC</b>
${THICKLINE}
<code>${vless_grpc}</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "parse_mode=html" --data-urlencode "disable_web_page_preview=true" --data-urlencode "text=${PESAN_HTML}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

renew_user() {
    select_user "PERPANJANG AKUN VLESS" "EXP"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    clear; echo -e "${LINE}"; echo -e "             ${WHITE}PERPANJANG AKUN VLESS${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Jumlah Hari Tambahan : " tambahan
    if [[ ! "$tambahan" =~ ^[0-9]+$ ]] || [ "$tambahan" -le 0 ]; then echo -e "${RED}Error: Angka tidak valid!${NC}"; read -p "Enter..." dummy; return; fi

    current_exp=$(grep "^${user}:" "$EXP_FILE" | cut -d: -f2- | tail -n 1)
    today_sec=$(date +%s)

    if [[ -n "$current_exp" && ${#current_exp} -eq 10 ]]; then current_exp="${current_exp} $(date +%H:%M:%S)"; fi
    if [ -z "$current_exp" ]; then base_sec=$today_sec
    else exp_sec=$(date -d "$current_exp" +%s 2>/dev/null); if [ -z "$exp_sec" ] || [ "$today_sec" -gt "$exp_sec" ]; then base_sec=$today_sec; else base_sec=$exp_sec; fi; fi

    new_exp=$(date -d "@$(( base_sec + (tambahan * 86400) ))" +"%Y-%m-%d %H:%M:%S")
    sed -i "/^${user}:/d" "$EXP_FILE"; echo "${user}:${new_exp}" >> "$EXP_FILE"
    systemctl restart xray >/dev/null 2>&1

    echo -e "\n${GREEN}Berhasil! Expired baru: $new_exp${NC}"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_RENEW="${THICKLINE}
         <b>RENEW VLESS</b>
${THICKLINE}
<b>User      :</b> <code>${user}</code>
<b>Added     :</b> <code>${tambahan} Days</code>
<b>Expires   :</b> <code>${new_exp}</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "disable_web_page_preview=true" --data-urlencode "parse_mode=html" --data-urlencode "text=${PESAN_RENEW}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

change_ip_user() {
    select_user "GANTI LIMIT IP VLESS" "IP"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    clear; echo -e "${LINE}"; echo -e "             ${WHITE}GANTI LIMIT IP VLESS${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Masukkan Limit IP Baru (0 = Bebas): " new_limit
    [[ ! "$new_limit" =~ ^[0-9]+$ ]] && new_limit=0

    sed -i "/^${user}:/d" "$DB_IP" 2>/dev/null; echo "${user}:${new_limit}" >> "$DB_IP"
    echo -e "\n${GREEN}Sukses! Limit IP user '${user}' diubah menjadi: ${new_limit}${NC}"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_IP="${THICKLINE}
      <b>CHANGE LIMIT IP VLESS</b>
${THICKLINE}
<b>User      :</b> <code>${user}</code>
<b>Limit IP  :</b> <code>${new_limit}</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "disable_web_page_preview=true" --data-urlencode "parse_mode=html" --data-urlencode "text=${PESAN_IP}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

change_bw_user() {
    select_user "GANTI LIMIT DATA VLESS" "BW"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    clear; echo -e "${LINE}"; echo -e "            ${WHITE}GANTI LIMIT DATA VLESS${NC}"; echo -e "${LINE}"
    echo -e " ${CYAN}User Terpilih : ${GREEN}${user}${NC}"
    read -p " Masukkan Limit Kuota Baru GB (0 = Unli): " new_limit
    [[ ! "$new_limit" =~ ^[0-9]+$ ]] && new_limit=0

    sed -i "/^${user}:/d" "$DB_BW" 2>/dev/null; echo "${user}:${new_limit}" >> "$DB_BW"
    /usr/local/sbin/algojo-kuota >/dev/null 2>&1
    echo -e "\n${GREEN}Sukses! Limit Kuota user '${user}' diubah menjadi: ${new_limit} GB${NC}"
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        PESAN_BW="${THICKLINE}
     <b>CHANGE LIMIT BW VLESS</b>
${THICKLINE}
<b>User      :</b> <code>${user}</code>
<b>Limit BW  :</b> <code>${new_limit} GB</code>
${THICKLINE}"
        curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" --data-urlencode "chat_id=${CHAT_ID}" --data-urlencode "disable_web_page_preview=true" --data-urlencode "parse_mode=html" --data-urlencode "text=${PESAN_BW}" >/dev/null 2>&1
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

recovery_vless() {
    exec menu-recovery VLESS
}

lock_unlock_user() {
    select_user "LOCK / UNLOCK AKUN VLESS" "EXP"
    [[ -z "$SELECTED_USER" ]] && return
    user="$SELECTED_USER"

    DB_LOCK="/etc/wibutunnel/locked_users.db"
    now=$(date +%s)

    if grep -q "^${user}:" "$DB_LOCK" 2>/dev/null; then
        jq --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json /usr/local/etc/xray/config.json
        sed -i "/^${user}:/d" "$DB_LOCK" 2>/dev/null
        systemctl restart xray >/dev/null 2>&1
        echo -e "\n${GREEN}Akun '$user' berhasil di-UNLOCK! Kini bisa login kembali.${NC}"
    else
        jq --arg user "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= (. + [$user] | unique)' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray_tmp.json && mv /etc/wibutunnel/tmp/xray_tmp.json /usr/local/etc/xray/config.json
        echo "$user:$now:0:LOCK" >> "$DB_LOCK"
        systemctl restart xray >/dev/null 2>&1
        echo -e "\n${RED}Akun '$user' berhasil di-LOCK! Dipindahkan ke Recovery.${NC}"
    fi
    echo ""; read -p "Tekan Enter..." dummy
}

# ===== MAIN MENU =====
clear; echo -e "${LINE}"
echo -e "              ${WHITE}MENU KELOLA VLESS${NC}"
echo -e "${LINE}"
echo -e " ${GREEN}[1]  Create Akun${NC}"
echo -e " ${CYAN}[2]  Create Trial${NC}"
echo -e " ${RED}[3]  Delete Akun${NC}"
echo -e " ${YELLOW}[4]  List Akun / Cek Akun${NC}"
echo -e " ${BLUE}[5]  Renew Akun (Masa Aktif)${NC}"
echo -e " ${CYAN}[6]  Ganti Limit IP User${NC}"
echo -e " ${YELLOW}[7]  Ganti Limit Kuota GB${NC}"
echo -e " ${GREEN}[8]  Cek Trafik & Monitor IP${NC}"
echo -e "${LINE}"
echo -e " ${RED}[9]  Lock / Unlock Akun${NC}"
echo -e " ${GREEN}[10] Recovery Akun${NC}"
echo -e "${LINE}"
echo -e " ${WHITE}[0]  Back to Menu Dashboard${NC}"
echo -e "${LINE}"
echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_menu

case $sub_menu in
    1) add_user; exec m-vless ;;
    2) trial_user; exec m-vless ;;
    3) delete_user; exec m-vless ;;
    4) cek_user; exec m-vless ;;
    5) renew_user; exec m-vless ;;
    6) change_ip_user; exec m-vless ;;
    7) change_bw_user; exec m-vless ;;
    8) /usr/local/bin/cek-trafik VLESS ;;
    9) lock_unlock_user; exec m-vless ;;
    10) recovery_vless ;;
    0) exec menu ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec m-vless ;;
esac
