#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-setting.sh (v4.0 RECOVERY)
# Security Patch: Anti-Symlink Update + Fix Format Waktu + Speedtest Repo
# ==========================================

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi
check_license

source /etc/wibutunnel/bot.conf 2>/dev/null
source /etc/wibutunnel/lock.conf 2>/dev/null || LOCK_DURATION=15

if [[ -z "$BOT_TOKEN" ]]; then
    STATUS_TOKEN="${RED}Belum disetting${NC}"
else
    TAMPIL_TOKEN="${BOT_TOKEN:0:4}..."
    STATUS_TOKEN="${GREEN}Aktif (${TAMPIL_TOKEN})${NC}"
fi

if [[ -z "$CHAT_ID" ]]; then
    STATUS_CHATID="${RED}Belum disetting${NC}"
else
    STATUS_CHATID="${GREEN}${CHAT_ID}${NC}"
fi

CEK_REBOOT=$(crontab -l 2>/dev/null | awk '!/^#/ && /\/sbin\/reboot/ {printf "%02d:%02d", $2, $1; exit}')
STATUS_REBOOT=$([[ -z "$CEK_REBOOT" ]] && echo "${RED}Belum disetting${NC}" || echo "${GREEN}Tersetting pada ${CEK_REBOOT} WIB${NC}")

CEK_BACKUP=$(crontab -l 2>/dev/null | awk '!/^#/ && /m-backup auto/ {printf "%02d:%02d", $2, $1; exit}')
STATUS_BACKUP=$([[ -z "$CEK_BACKUP" ]] && echo "${RED}Belum disetting${NC}" || echo "${GREEN}Tersetting pada ${CEK_BACKUP} WIB${NC}")

safe_update() {
    local repo_path="$1"
    local base_name=$(basename "$repo_path")
    local target_name="${base_name%.sh}"
    
    local raw_url="https://raw.githubusercontent.com/WBVPN/WIBUTUNNEL/main/${repo_path}?$(date +%s)"
    
    wget -q -O "/etc/wibutunnel/tmp/${base_name}" "$raw_url" 2>/dev/null
    if [[ -s "/etc/wibutunnel/tmp/${base_name}" ]]; then
        mv "/etc/wibutunnel/tmp/${base_name}" "/usr/local/bin/${target_name}"
        chmod +x "/usr/local/bin/${target_name}"
        echo -e "${GREEN}√ Berhasil memperbarui ${target_name}${NC}"
    else
        echo -e "${RED}× Gagal mengunduh ${base_name} (Sistem dilindungi dari file kosong)${NC}"
    fi
}

clear
echo -e "$LINE"
echo -e "            ${WHITE}MENU SETTING & MONITOR${NC}"
echo -e "$LINE"
echo -e "  ${CYAN}Bot Telegram : ${NC}${STATUS_TOKEN}"
echo -e "  ${CYAN}ID Telegram  : ${NC}${STATUS_CHATID}"
echo -e "  ${CYAN}Auto Reboot  : ${NC}${STATUS_REBOOT}"
echo -e "  ${CYAN}Auto Backup  : ${NC}${STATUS_BACKUP}"
echo -e "  ${CYAN}Lock Duration: ${NC}${GREEN}${LOCK_DURATION} menit${NC}"
echo -e "$LINE"
echo -e " ${RED}[1] Restart Semua Service${NC}"
echo -e " ${GREEN}[2] Bersihkan Cache & RAM${NC}"
echo -e " ${CYAN}[3] Speedtest VPS${NC}"
echo -e " ${YELLOW}[4] Cek Bandwidth VPS (vnStat)${NC}"
echo -e " ${BLUE}[5] Update Script (Safe Mode)${NC}"
echo -e " ${WHITE}[6] Setup Bot Telegram${NC}"
echo -e " ${CYAN}[7] Setup Auto Reboot VPS${NC}"
echo -e " ${YELLOW}[8] Ganti Domain & Renew SSL${NC}"
echo -e " ${GREEN}[9] Atur Durasi Lock Otomatis${NC}"
echo -e " ${RED}[0] Kembali ke Dashboard Utama${NC}"
echo -e "$LINE"

echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_setting

case $sub_setting in
    1)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}MERESTART SERVICES...${NC}"; echo -e "$LINE"
        if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then
            systemctl restart xray haproxy cron
            echo -e "${GREEN}Semua service berhasil direstart!${NC}"
        else
            echo -e "${RED}[!] Config Xray error, restart xray dibatalkan.${NC}"
            systemctl restart haproxy cron
        fi
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    2)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}MEMBERSIHKAN CACHE & RAM...${NC}"; echo -e "$LINE"
        sync; echo 1 > /proc/sys/vm/drop_caches
        sync; echo 2 > /proc/sys/vm/drop_caches
        sync; echo 3 > /proc/sys/vm/drop_caches
        echo -e "${GREEN}RAM berhasil dibersihkan!${NC}"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    3)
        clear; echo -e "$LINE"; echo -e "            ${WHITE}SPEEDTEST VPS${NC}"; echo -e "$LINE"
        # Install Ookla Speedtest CLI (binary langsung)
        if ! command -v speedtest &> /dev/null; then
            apt-get remove -y speedtest-cli >/dev/null 2>&1
            rm -f /usr/bin/speedtest /usr/local/bin/speedtest
            ARCH=$(uname -m)
            [[ "$ARCH" == "x86_64" ]] && ARCH="x86_64"
            [[ "$ARCH" == "aarch64" ]] && ARCH="aarch64"
            wget -qO- "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${ARCH}.tgz" | tar xz -C /usr/bin speedtest 2>/dev/null
            chmod +x /usr/bin/speedtest 2>/dev/null
        fi
        if command -v speedtest &> /dev/null; then
            echo -e "${GREEN}[+] Speedtest Ookla Resmi Berhasil Diinstal!${NC}"
            speedtest --accept-license --accept-gdpr
        else
            echo -e "${RED}Speedtest gagal diinstall.${NC}"
        fi
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    4)
        clear; echo -e "$LINE"; echo -e "          ${WHITE}MONITOR BANDWIDTH VPS${NC}"; echo -e "$LINE"
        if ! command -v vnstat &> /dev/null; then
            apt-get install -y vnstat >/dev/null 2>&1
            systemctl enable --now vnstat >/dev/null 2>&1
        fi
        MAIN_IFACE=$(ip -4 route show default | awk '{print $5}' | head -n1)
        
        # Raw Data (Realtime from kernel)
        RX_B=$(cat /sys/class/net/$MAIN_IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
        TX_B=$(cat /sys/class/net/$MAIN_IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
        
        # Format to human readable
        rx_mb=$(awk -v b="$RX_B" 'BEGIN { printf "%.2f MB", b / 1048576 }')
        rx_gb=$(awk -v b="$RX_B" 'BEGIN { printf "%.2f GB", b / 1073741824 }')
        tx_mb=$(awk -v b="$TX_B" 'BEGIN { printf "%.2f MB", b / 1048576 }')
        tx_gb=$(awk -v b="$TX_B" 'BEGIN { printf "%.2f GB", b / 1073741824 }')
        
        if (( RX_B > 1073741824 )); then rx_print=$rx_gb; else rx_print=$rx_mb; fi
        if (( TX_B > 1073741824 )); then tx_print=$tx_gb; else tx_print=$tx_mb; fi
        
        echo -e " ${GREEN}REALTIME BANDWIDTH (Sejak VPS ON)${NC}"
        echo -e "  - Download (RX) : ${WHITE}$rx_print${NC}"
        echo -e "  - Upload (TX)   : ${WHITE}$tx_print${NC}"
        echo -e "$LINE"
        
        # Vnstat output
        VNSTAT_OUT=$(vnstat -d -i "$MAIN_IFACE" 2>&1)
        if echo "$VNSTAT_OUT" | grep -q "Not enough data"; then
            echo -e " ${YELLOW}Catatan:${NC} Vnstat sedang merekam data."
            echo -e " Tunggu 5-10 menit untuk melihat log harian/bulanan."
        else
            echo -e " ${CYAN}DATA HARIAN (DAILY)${NC}"
            vnstat -d -i "$MAIN_IFACE" | grep -v "$MAIN_IFACE" | grep -v "^$" | head -n 8
            echo -e ""
            echo -e " ${CYAN}DATA BULANAN (MONTHLY)${NC}"
            vnstat -m -i "$MAIN_IFACE" | grep -v "$MAIN_IFACE" | grep -v "^$" | head -n 8
        fi
        echo -e "$LINE"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    5)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}UPDATE SCRIPT (SAFE MODE)${NC}"; echo -e "$LINE"
        echo -e "${YELLOW}Mengecek dan mengunduh pembaruan...${NC}"
        
        safe_update "menu/menu.sh"
        safe_update "menu/m-vless.sh"
        safe_update "menu/m-vmess.sh"
        safe_update "menu/m-trojan.sh"
        safe_update "menu/m-setting.sh"
        safe_update "menu/xp.sh"
        safe_update "menu/m-backup.sh"
        safe_update "menu/menu-lock.sh"
        safe_update "menu/menu-unlock.sh"
        safe_update "menu/menu-recovery.sh"
        safe_update "menu/cek-trafik.sh"
        safe_update "menu/bot-daemon.sh"
        
        safe_update "sbin/algojo-kuota"
        safe_update "sbin/algojo-wibu"
        safe_update "sbin/lock-user"
        safe_update "sbin/unlock-user"
        safe_update "sbin/unlocker-wibu"
        
        safe_update "common.sh"
        
        dos2unix /usr/local/bin/* >/dev/null 2>&1
        systemctl restart wibutunnel-bot >/dev/null 2>&1
        echo -e "\n${GREEN}Update Selesai! Semua menu sudah versi terbaru.${NC}"
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    6)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}SETUP BOT TELEGRAM${NC}"; echo -e "$LINE"
        bot_status=$(systemctl is-active wibutunnel-bot 2>/dev/null)
        [[ "$bot_status" == "active" ]] && text_sts="${GREEN}Aktif & Berjalan${NC}" || text_sts="${RED}Mati (Stopped)${NC}"
        echo -e " Status Daemon Bot : $text_sts\n"
        echo -e " [1] Ganti BOT TOKEN & CHAT ID"
        echo -e " [2] Hidupkan (Start) Bot"
        echo -e " [3] Matikan (Stop) Bot"
        echo -e " [0] Kembali"
        echo -e "$LINE"
        read -p " Pilih opsi [0-3]: " sub_bot
        case $sub_bot in
            1)
                read -p "Masukkan BOT TOKEN : " input_token
                read -p "Masukkan CHAT ID   : " input_chatid
                if [[ -n "$input_token" && -n "$input_chatid" ]]; then
                    echo "BOT_TOKEN=\"${input_token}\"" > /etc/wibutunnel/bot.conf
                    echo "CHAT_ID=\"${input_chatid}\"" >> /etc/wibutunnel/bot.conf
                    systemctl restart wibutunnel-bot 2>/dev/null
                    echo -e "${GREEN}Bot berhasil disimpan & direstart!${NC}"
                fi
                ;;
            2)
                systemctl enable wibutunnel-bot >/dev/null 2>&1
                systemctl start wibutunnel-bot >/dev/null 2>&1
                echo -e "${GREEN}Bot Telegram berhasil dihidupkan!${NC}"
                ;;
            3)
                systemctl stop wibutunnel-bot >/dev/null 2>&1
                systemctl disable wibutunnel-bot >/dev/null 2>&1
                echo -e "${YELLOW}Bot Telegram telah dimatikan!${NC}"
                ;;
            0) exec m-setting ;;
            *) echo -e "${RED}Pilihan salah!${NC}" ;;
        esac
        read -n 1 -s -r -p "Tekan tombol apa saja..."
        exec m-setting
        ;;
    7)
        clear; echo -e "$LINE"; echo -e "            ${WHITE}SETUP AUTO REBOOT${NC}"; echo -e "$LINE"
        read -p "Masukkan Jam (0-23): " input_jam
        if [[ "$input_jam" =~ ^[0-9]+$ ]] && [ "$input_jam" -le 23 ]; then
            crontab -l 2>/dev/null | grep -v "/sbin/reboot" | crontab -
            (crontab -l 2>/dev/null; echo "0 $input_jam * * * /sbin/reboot") | crontab -
            systemctl restart cron
            echo -e "${GREEN}Auto Reboot disetel jam $input_jam:00 WIB${NC}"
        fi
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    8)
        clear; echo -e "$LINE"; echo -e "       ${WHITE}GANTI DOMAIN & RENEW SSL${NC}"; echo -e "$LINE"
        read -p "Masukkan Domain Baru: " new_domain
        if [[ -n "$new_domain" ]]; then
            systemctl stop haproxy xray
            # Deteksi versi certbot
            if certbot --version 2>/dev/null | grep -qE "certbot 2\."; then
                certbot certonly --standalone --non-interactive --agree-tos -m "admin@${new_domain}" -d "$new_domain" --force-renewal 2>/dev/null
            else
                certbot certonly --standalone --register-unsafely-without-email --no-eff-email --agree-tos -d "$new_domain" --force-renewal 2>/dev/null
            fi
            if [[ -f "/etc/letsencrypt/live/${new_domain}/fullchain.pem" ]]; then
                cat "/etc/letsencrypt/live/${new_domain}/fullchain.pem" "/etc/letsencrypt/live/${new_domain}/privkey.pem" > "/etc/haproxy/certs/${new_domain}.pem"
                echo "$new_domain" > /etc/xray/domain
                sed -i "s|bind \*:443 ssl crt .*\.pem|bind *:443 ssl crt /etc/haproxy/certs/${new_domain}.pem|g" /etc/haproxy/haproxy.cfg
                systemctl start haproxy xray
                echo -e "${GREEN}Domain berhasil diganti!${NC}"
            else
                echo -e "${RED}SSL gagal untuk $new_domain!${NC}"
            fi
        fi
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    9)
        clear; echo -e "$LINE"; echo -e "         ${WHITE}ATUR DURASI LOCK OTOMATIS${NC}"; echo -e "$LINE"
        echo -e "${CYAN}Saat ini durasi lock otomatis: ${GREEN}${LOCK_DURATION} menit${NC}\n"
        read -p "Durasi Lock (menit): " new_duration
        if [[ ! "$new_duration" =~ ^[0-9]+$ ]] || [ "$new_duration" -lt 1 ]; then
            echo -e "${RED}Durasi minimal 1!${NC}"
            sleep 2
            exec m-setting
        fi
        echo "LOCK_DURATION=$new_duration" > /etc/wibutunnel/lock.conf
        echo -e "${GREEN}Berhasil! Durasi lock diubah menjadi ${new_duration} menit.${NC}"
        read -p "Tekan Enter..." dummy
        exec m-setting
        ;;
    0)
        exec menu
        ;;
    *)
        echo -e "${RED}Pilihan tidak valid!${NC}"
        sleep 1
        exec m-setting
        ;;
esac
