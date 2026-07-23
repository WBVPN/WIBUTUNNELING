#!/bin/bash
# WIBU TUNNELING - recovery center (v4.3)
# Akses: menu-recovery [VLESS|VMESS|TROJAN]
source /usr/local/bin/common.sh
check_license

RED='\e[1;31m'; GREEN='\e[1;32m'; CYAN='\e[1;36m'; YELLOW='\e[1;33m'; WHITE='\e[1;37m'; BLUE='\e[34m'; NC='\e[0m'
LINE="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DB_LOCK="/etc/wibutunnel/locked_users.db"

if [[ -n "$1" ]] && [[ "$1" =~ ^(VLESS|VMESS|TROJAN)$ ]]; then
    FILTER_PROTO="$1"; proto_lower="${FILTER_PROTO,,}"
    proto_color="${GREEN}"; [[ "$FILTER_PROTO" == "VMESS" ]] && proto_color="${CYAN}"; [[ "$FILTER_PROTO" == "TROJAN" ]] && proto_color="${YELLOW}"
else FILTER_PROTO=""; fi

clear
[[ -n "$FILTER_PROTO" ]] && echo -e "${LINE}\n        ${proto_color}RECOVERY CENTER ${FILTER_PROTO}${NC}\n${LINE}" || echo -e "${LINE}\n              ${GREEN}RECOVERY CENTER USER${NC}\n${LINE}"

if [[ ! -s "$DB_LOCK" || -z $(cat "$DB_LOCK" 2>/dev/null) ]]; then
    echo -e " ${YELLOW}Tidak ada user di ruang Recovery.${NC}\n${LINE}\n"
    read -p " Tekan Enter..."; [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

declare -A USER_EXPS; declare -A USER_PROTOS

if [[ -n "$FILTER_PROTO" ]]; then
    proto_conf="/etc/xray/${proto_lower}_exp.conf"
    [[ -f "$proto_conf" ]] && while IFS= read -r line; do
        [[ -z "$line" ]] && continue; u="${line%%:*}"; e_full="${line#*:}"; e_clean="${e_full%% *}"
        [[ -n "$u" && "$u" != *"dummy"* ]] && { USER_EXPS["$u"]="$e_clean"; USER_PROTOS["$u"]="$FILTER_PROTO"; }
    done < "$proto_conf"
else
    for conf in /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf; do
        [[ ! -f "$conf" ]] && continue
        [[ "$conf" == *"vless"* ]] && proto="VLESS"; [[ "$conf" == *"vmess"* ]] && proto="VMESS"; [[ "$conf" == *"trojan"* ]] && proto="TROJAN"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue; u="${line%%:*}"; e_full="${line#*:}"; e_clean="${e_full%% *}"
            [[ -n "$u" && "$u" != *"dummy"* ]] && { USER_EXPS["$u"]="$e_clean"; USER_PROTOS["$u"]="$proto"; }
        done < "$conf"
    done
fi

echo -e " ${WHITE}NO  USERNAME       PROTO    REASON       STATUS${NC}\n${LINE}"

idx=1; declare -a USER_NAMES; GHOST_FOUND=false; mapfile -t locked_list < "$DB_LOCK"

for line in "${locked_list[@]}"; do
    u="${line%%:*}"; reason="${line##*:}"; [[ -z "$u" ]] && continue
    proto="${USER_PROTOS[$u]}"
    [[ -n "$FILTER_PROTO" && "$proto" != "$FILTER_PROTO" ]] && continue
    if [[ -z "$proto" ]]; then
        sed -i "/^${u}:/d" "$DB_LOCK" 2>/dev/null; sed -i "/^${u}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
        jq --arg user "$u" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $user))' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray.json && mv /etc/wibutunnel/tmp/xray.json /usr/local/etc/xray/config.json
        GHOST_FOUND=true; continue
    fi
    USER_NAMES[$idx]=$u
    [[ "$reason" == "EXPIRED" ]]    && txt_rsn="${YELLOW}EXPIRED     ${NC}"
    [[ "$reason" == "QUOTA" ]]      && txt_rsn="${RED}QUOTA       ${NC}"
    [[ "$reason" == "IP_LIMIT" ]]   && txt_rsn="${RED}IP LIMIT    ${NC}"
    [[ "$reason" == "MANUAL_DEL" ]] && txt_rsn="${CYAN}DELETED     ${NC}"
    [[ "$reason" == "LOCK" ]]       && txt_rsn="${RED}LOCKED      ${NC}"
    [[ -z "$txt_rsn" ]]            && txt_rsn="${RED}${reason}${NC}"
    printf " %-3s %-14s %-8s %b %b\n" "$idx)" "$u" "$proto" "$txt_rsn" "${RED}RECOVERY${NC}"; ((idx++))
done

[[ "$GHOST_FOUND" == true ]] && if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi

total=$((idx - 1))
if [ "$total" -eq 0 ]; then
    echo -e " ${GREEN}Tidak ada user di Recovery.${NC}\n${LINE}\n"; read -p " Tekan Enter..."
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

echo -e "${LINE}\n ${CYAN}Total: ${WHITE}$total user${NC}\n${LINE}"
echo -e " Input type : ${GREEN}deleteallusers${NC}\n              for Delete All Users RECOVERY\n${LINE}"
read -p " Pilih akun [1-$total] / [nama] / [0] Batal: " target

if [[ "$target" == "deleteallusers" ]]; then
    for user in "${USER_NAMES[@]}"; do
        [[ -z "$user" ]] && continue
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
        ' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray.json && mv /etc/wibutunnel/tmp/xray.json /usr/local/etc/xray/config.json
        sed -i "/^${user}:/d" /etc/xray/vless_exp.conf
        sed -i "/^${user}:/d" /etc/xray/vmess_exp.conf
        sed -i "/^${user}:/d" /etc/xray/trojan_exp.conf
        sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null
        sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null
        sed -i "/^${user}:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
        sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
    done
    > /etc/wibutunnel/locked_users.db
    if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi
    echo -e "\n ${GREEN}SEMUA AKUN RECOVERY TELAH DIMUSNAHKAN PERMANEN!${NC}"
    read -p " Tekan Enter..." dummy
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

[[ -z "$target" || "$target" == "0" ]] && { [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu; }
if [[ "$target" =~ ^[0-9]+$ ]] && [ "$target" -ge 1 ] && [ "$target" -le "$total" ]; then user="${USER_NAMES[$target]}"
else user="$target"; fi

[[ -z $(grep "^${user}:" "$DB_LOCK" 2>/dev/null) ]] && { echo -e "\n ${RED}User '$user' tidak di Recovery!${NC}"; sleep 2; exec menu-recovery; }

echo -e "\n ${WHITE}Reaktivasi: ${GREEN}$user${NC}\n${LINE}"
read -p " Masa Aktif Baru (Hari): " hari_baru
[[ ! "$hari_baru" =~ ^[0-9]+$ || "$hari_baru" -le 0 ]] && { echo -e " ${RED}Format salah!${NC}"; sleep 2; exec menu-recovery; }
read -p " Limit IP Baru (0=Bebas): " ip_baru; [[ ! "$ip_baru" =~ ^[0-9]+$ ]] && ip_baru=0
read -p " Limit Kuota GB (0=Unli): " bw_baru; [[ ! "$bw_baru" =~ ^[0-9]+$ ]] && bw_baru=0

new_exp=$(date -d "+${hari_baru} days" +"%Y-%m-%d %H:%M:%S"); proto="${USER_PROTOS[$user]}"
[[ "$proto" == "VLESS" ]]  && { sed -i "/^${user}:/d" /etc/xray/vless_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/vless_exp.conf; }
[[ "$proto" == "VMESS" ]]  && { sed -i "/^${user}:/d" /etc/xray/vmess_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/vmess_exp.conf; }
[[ "$proto" == "TROJAN" ]] && { sed -i "/^${user}:/d" /etc/xray/trojan_exp.conf; echo "${user}:${new_exp}" >> /etc/xray/trojan_exp.conf; }

sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null; echo "${user}:${ip_baru}" >> /etc/wibutunnel/limit_ip.db
sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null; echo "${user}:${bw_baru}" >> /etc/wibutunnel/limit_bw.db
sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null

jq --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray.json && mv /etc/wibutunnel/tmp/xray.json /usr/local/etc/xray/config.json
sed -i "/^$user:/d" /etc/wibutunnel/locked_users.db 2>/dev/null; if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi

echo -e "\n ${GREEN}BERHASIL! Akun ${user} telah aktif kembali.${NC}"
read -p " Tekan Enter..."; [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
