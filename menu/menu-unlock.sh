#!/bin/bash
# ==========================================
# WIBU TUNNELING - menu-unlock.sh (v4.1 RECOVERY CENTER)
# Support: menu-unlock VLESS|VMESS|TROJAN (per-protocol mode)
#          menu-unlock (global mode, all protocols)
# ==========================================

source /usr/local/bin/common.sh
check_license

RED='\e[1;31m'
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
WHITE='\e[1;37m'
BLUE='\e[34m'
NC='\e[0m'
LINE="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DB_LOCK="/etc/wibutunnel/locked_users.db"

# Detect protocol mode
if [[ -n "$1" ]] && [[ "$1" =~ ^(VLESS|VMESS|TROJAN)$ ]]; then
    FILTER_PROTO="$1"
    proto_lower="${FILTER_PROTO,,}"
    proto_color="${GREEN}"
    [[ "$FILTER_PROTO" == "VMESS" ]] && proto_color="${CYAN}"
    [[ "$FILTER_PROTO" == "TROJAN" ]] && proto_color="${YELLOW}"
else
    FILTER_PROTO=""
fi

clear
if [[ -n "$FILTER_PROTO" ]]; then
    echo -e "${LINE}"
    echo -e "        ${proto_color}RECOVERY CENTER ${FILTER_PROTO}${NC}"
else
    echo -e "${LINE}"
    echo -e "              ${GREEN}RECOVERY CENTER USER${NC}"
fi
echo -e "${LINE}"

if [[ ! -s "$DB_LOCK" || -z $(cat "$DB_LOCK" 2>/dev/null) ]]; then
    echo -e " ${YELLOW}Aman Terkendali! Saat ini tidak ada user di ruang Recovery.${NC}"
    echo -e "${LINE}\n"
    read -p " Tekan Enter Untuk Kembali..."
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

declare -A USER_EXPS
declare -A USER_PROTOS

if [[ -n "$FILTER_PROTO" ]]; then
    proto_conf="/etc/xray/${proto_lower}_exp.conf"
    if [[ -f "$proto_conf" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            u="${line%%:*}"
            e_full="${line#*:}"
            e_clean="${e_full%% *}"
            [[ -n "$u" && "$u" != *"dummy"* ]] && {
                USER_EXPS["$u"]="$e_clean"
                USER_PROTOS["$u"]="$FILTER_PROTO"
            }
        done < "$proto_conf"
    fi
else
    for conf in /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf; do
        [[ ! -f "$conf" ]] && continue
        if [[ "$conf" == *"vless"* ]]; then proto="VLESS"
        elif [[ "$conf" == *"vmess"* ]]; then proto="VMESS"
        elif [[ "$conf" == *"trojan"* ]]; then proto="TROJAN"
        fi

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            u="${line%%:*}"
            e_full="${line#*:}"
            e_clean="${e_full%% *}"
            [[ -n "$u" && "$u" != *"dummy"* ]] && {
                USER_EXPS["$u"]="$e_clean"
                USER_PROTOS["$u"]="$proto"
            }
        done < "$conf"
    done
fi

echo -e " ${WHITE}NO  USERNAME       PROTO    REASON       STATUS${NC}"
echo -e "${LINE}"

idx=1
declare -a USER_NAMES
GHOST_FOUND=false

mapfile -t locked_list < "$DB_LOCK"

for line in "${locked_list[@]}"; do
    u="${line%%:*}"
    reason="${line##*:}"
    [[ -z "$u" ]] && continue
    
    proto="${USER_PROTOS[$u]}"
    
    # Per-protocol filter: skip users not in this protocol
    if [[ -n "$FILTER_PROTO" ]] && [[ "$proto" != "$FILTER_PROTO" ]]; then
        continue
    fi
    
    if [[ -z "$proto" ]]; then
        sed -i "/^${u}:/d" "$DB_LOCK" 2>/dev/null
        sed -i "/^${u}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null
        jq --arg user "$u" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $user))' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray.json && mv /etc/wibutunnel/tmp/xray.json /usr/local/etc/xray/config.json
        GHOST_FOUND=true
        continue
    fi

    USER_NAMES[$idx]=$u
    
    [[ "$reason" == "EXPIRED" ]]    && txt_rsn="${YELLOW}EXPIRED     ${NC}"
    [[ "$reason" == "QUOTA" ]]      && txt_rsn="${RED}QUOTA       ${NC}"
    [[ "$reason" == "IP_LIMIT" ]]   && txt_rsn="${RED}IP LIMIT    ${NC}"
    [[ "$reason" == "MANUAL_DEL" ]] && txt_rsn="${CYAN}DELETED     ${NC}"
    [[ "$reason" == "LOCK" ]]       && txt_rsn="${RED}LOCKED      ${NC}"
    
    status="${RED}RECOVERY${NC}"
    
    printf " %-3s %-14s %-8s %b %b\n" "$idx)" "$u" "$proto" "$txt_rsn" "$status"
    ((idx++))
done

if [[ "$GHOST_FOUND" == true ]]; then if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi; fi

total=$((idx - 1))
if [ "$total" -eq 0 ]; then
    if [[ -n "$FILTER_PROTO" ]]; then
        echo -e " ${GREEN}Tidak ada user ${FILTER_PROTO} di Recovery saat ini.${NC}"
    else
        echo -e " ${GREEN}Sisa data hantu berhasil dibersihkan! Penjara sekarang kosong.${NC}"
    fi
    echo -e "${LINE}\n"
    read -p " Tekan Enter Untuk Kembali..."
    [[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
fi

echo -e "${LINE}"
echo -e " ${CYAN}Total Akun di Recovery: ${WHITE}$total user${NC}"
echo -e "${LINE}"
echo -e " ${YELLOW}Press CTRL+C for CANCEL${NC}\n"
read -p " Pilih akun untuk diaktifkan [1-$total] / [nama] : " target

if [[ -z "$target" ]]; then
    echo -e "\n ${RED}[!] Pilihan tidak boleh kosong!${NC}"
    sleep 2
    [[ -n "$FILTER_PROTO" ]] && exec "menu-unlock ${FILTER_PROTO}" || exec menu-unlock
fi

if [[ "$target" =~ ^[0-9]+$ ]] && [ "$target" -ge 1 ] && [ "$target" -le "$total" ]; then
    user="${USER_NAMES[$target]}"
else
    user="$target"
fi

is_locked=$(grep "^${user}:" "$DB_LOCK" 2>/dev/null)
if [[ -z "$is_locked" ]]; then
    echo -e "\n ${RED}[!] User '$user' tidak ditemukan di ruang Recovery!${NC}"
    sleep 2
    [[ -n "$FILTER_PROTO" ]] && exec "menu-unlock ${FILTER_PROTO}" || exec menu-unlock
fi

echo -e "\n ${WHITE}Memulai Proses Reactivate untuk: ${GREEN}$user${NC}"
echo -e "${LINE}"
read -p " Masukkan Masa Aktif Baru (Hari) : " hari_baru
if [[ ! "$hari_baru" =~ ^[0-9]+$ ]] || [ "$hari_baru" -le 0 ]; then
    echo -e " ${RED}Format salah!${NC}"
    sleep 2
    [[ -n "$FILTER_PROTO" ]] && exec "menu-unlock ${FILTER_PROTO}" || exec menu-unlock
fi

read -p " Masukkan Limit IP Baru (0=Bebas): " ip_baru
[[ ! "$ip_baru" =~ ^[0-9]+$ ]] && ip_baru=0

read -p " Masukkan Limit Kuota GB (0=Unli): " bw_baru
[[ ! "$bw_baru" =~ ^[0-9]+$ ]] && bw_baru=0

# UPDATE DATA
new_exp=$(date -d "+${hari_baru} days" +"%Y-%m-%d %H:%M:%S")
proto="${USER_PROTOS[$user]}"
if [[ "$proto" == "VLESS" ]]; then
    sed -i "/^${user}:/d" /etc/xray/vless_exp.conf
    echo "${user}:${new_exp}" >> /etc/xray/vless_exp.conf
fi
if [[ "$proto" == "VMESS" ]]; then
    sed -i "/^${user}:/d" /etc/xray/vmess_exp.conf
    echo "${user}:${new_exp}" >> /etc/xray/vmess_exp.conf
fi
if [[ "$proto" == "TROJAN" ]]; then
    sed -i "/^${user}:/d" /etc/xray/trojan_exp.conf
    echo "${user}:${new_exp}" >> /etc/xray/trojan_exp.conf
fi

sed -i "/^${user}:/d" /etc/wibutunnel/limit_ip.db 2>/dev/null
echo "${user}:${ip_baru}" >> /etc/wibutunnel/limit_ip.db
sed -i "/^${user}:/d" /etc/wibutunnel/limit_bw.db 2>/dev/null
echo "${user}:${bw_baru}" >> /etc/wibutunnel/limit_bw.db
sed -i "/^${user}:/d" /etc/wibutunnel/user_usage.db 2>/dev/null

# UNLOCK DARI XRAY
jq --arg u "$user" '(.routing.rules[] | select(.user != null and .outboundTag == "blocked") | .user) |= map(select(. != $u))' /usr/local/etc/xray/config.json > /etc/wibutunnel/tmp/xray.json && mv /etc/wibutunnel/tmp/xray.json /usr/local/etc/xray/config.json
sed -i "/^$user:/d" /etc/wibutunnel/locked_users.db 2>/dev/null
if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl restart xray >/dev/null 2>&1; fi

echo -e "\n ${GREEN}BERHASIL! Akun ${user} telah aktif kembali.${NC}"
read -p " Tekan Enter Untuk Kembali..."
[[ -n "$FILTER_PROTO" ]] && exec "m-${proto_lower}" || exec menu
