#!/bin/bash
# ==========================================
# WIBU TUNNELING - m-backup.sh (v4.1 FIXED)
# Fixed: license check tidak membunuh cron job, logging, PATH
# ==========================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

source /usr/local/bin/common.sh
if ! command -v jq &> /dev/null; then apt-get install -y jq &>/dev/null; fi

source /etc/wibutunnel/bot.conf 2>/dev/null

IP_VPS="${MYIP:-$(curl -sS --max-time 5 ipv4.icanhazip.com)}"
[[ -z "$IP_VPS" ]] && IP_VPS="Unknown"

VPS_NAME="PROJECT-WIBU"
BACKUP_DIR="/etc/wibutunnel/tmp"
mkdir -p "$BACKUP_DIR"
LOG_FILE="/var/log/wibu-backup.log"
DOMAIN_VPS=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")

# ===== AUTO BACKUP (via Cron) =====
# DIJALANKAN PERTAMA: mencegah check_license_silent membunuh cron job
if [[ "$1" == "auto" ]]; then
    # License check dalam subshell — exit 1 tidak akan membunuh script utama
    (check_license >/dev/null 2>&1) || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] LICENSE CHECK FAILED — backup aborted" >> "$LOG_FILE"
        exit 0
    }

    [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]] && {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BOT NOT CONFIGURED — backup aborted" >> "$LOG_FILE"
        exit 0
    }

    DATE=$(date +"%Y-%m-%d_%H-%M")
    BACKUP_FILE="${BACKUP_DIR}/${DOMAIN_VPS}-${IP_VPS}.zip"

    cd /
    ZIP_PASS=$(echo -n "$CHAT_ID" | md5sum | awk '{print $1}' | cut -c 1-8)
    zip -q -P "$ZIP_PASS" -r "$BACKUP_FILE" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/xray/domain 2>/dev/null

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ZIP CREATION FAILED — source files missing?" >> "$LOG_FILE"
        exit 0
    fi

    TGL=$(date "+%Y-%m-%d %H:%M:%S")
    CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n<i>File dienkripsi menggunakan CHAT ID Anda.</i>")

    RESPONSE=$(curl -s --max-time 30 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${BACKUP_FILE}" \
        -F "caption=${CAPTION}" \
        -F "parse_mode=html")

    FILE_ID=$(echo "$RESPONSE" | jq -r '.result.document.file_id // empty')
    MSG_ID=$(echo "$RESPONSE" | jq -r '.result.message_id // empty')
    
    if [[ -n "$FILE_ID" && -n "$MSG_ID" ]]; then
        NEW_CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${FILE_ID}</code>\n\n🔐 <b>Password:</b> <code>${ZIP_PASS}</code>")
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
            -F "chat_id=${CHAT_ID}" \
            -F "message_id=${MSG_ID}" \
            -F "caption=${NEW_CAPTION}" \
            -F "parse_mode=html" >/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto backup SUCCESS — File ID: ${FILE_ID}" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto backup PARTIAL — ZIP sent but no File ID in response" >> "$LOG_FILE"
    fi
    rm -f "$BACKUP_FILE"
    exit 0
fi

# ===== INTERACTIVE MODE (dari menu) — baru jalankan license check =====
check_license_silent

# ===== MANUAL BACKUP =====
do_backup() {
    clear
    echo -e "${LINE}"
    echo -e "             ${WHITE}BACKUP MANUAL DATA VPS${NC}"
    echo -e "${LINE}"

    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        echo -e "${RED}ERROR: Bot Telegram belum di-setting!${NC}"
        echo -e "${YELLOW}Gunakan menu Setting untuk setup Bot.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${CYAN}[+] Mempersiapkan backup...${NC}"

    DATE=$(date +"%Y-%m-%d_%H-%M")
    BACKUP_FILE="${BACKUP_DIR}/${DOMAIN_VPS}-${IP_VPS}.zip"

    cd /
    ZIP_PASS=$(echo -n "$CHAT_ID" | md5sum | awk '{print $1}' | cut -c 1-8)
    zip -q -P "$ZIP_PASS" -r "$BACKUP_FILE" \
        usr/local/etc/xray/config.json \
        etc/xray/vless_exp.conf \
        etc/xray/vmess_exp.conf \
        etc/xray/trojan_exp.conf \
        etc/wibutunnel/limit_ip.db \
        etc/wibutunnel/limit_bw.db \
        etc/wibutunnel/locked_users.db \
        etc/wibutunnel/user_usage.db \
        etc/xray/domain 2>/dev/null

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo -e "${RED}[!] Gagal membuat file backup. Periksa apakah file sumber ada.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${YELLOW}[+] Mengirim ke Telegram...${NC}"

    TGL=$(date "+%Y-%m-%d %H:%M:%S")
    CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n<i>File dienkripsi menggunakan CHAT ID Anda.</i>")

    RESPONSE=$(curl -s --max-time 30 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${BACKUP_FILE}" \
        -F "caption=${CAPTION}" \
        -F "parse_mode=html")

    if echo "$RESPONSE" | jq -e '.ok' >/dev/null 2>&1; then
        echo -e "${GREEN}[+] Backup berhasil dikirim ke Telegram!${NC}"
        FILE_ID=$(echo "$RESPONSE" | jq -r '.result.document.file_id // empty')
        MSG_ID=$(echo "$RESPONSE" | jq -r '.result.message_id // empty')
        
        if [[ -n "$FILE_ID" && -n "$MSG_ID" ]]; then
            NEW_CAPTION=$(echo -e "📦 <b>Backup Wibutunnel VPS</b>\n🗓 Tanggal: <code>${TGL}</code>\n\n🔑 <b>DATA RESTORE:</b>\n<code>${FILE_ID}</code>\n\n🔐 <b>Password:</b> <code>${ZIP_PASS}</code>")
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageCaption" \
                -F "chat_id=${CHAT_ID}" \
                -F "message_id=${MSG_ID}" \
                -F "caption=${NEW_CAPTION}" \
                -F "parse_mode=html" >/dev/null
        fi
    else
        echo -e "${RED}[!] Gagal mengirim ke Telegram. Cek koneksi atau konfigurasi Bot.${NC}"
    fi
    rm -f "$BACKUP_FILE"
    echo ""; read -p "Tekan Enter..." dummy
}

# ===== RESTORE =====
do_restore() {
    clear
    echo -e "${LINE}"
    echo -e "             ${WHITE}SMART RESTORE DATA VPS${NC}"
    echo -e "${LINE}"
    echo -e "${YELLOW}Masukkan: Link URL / File Path / File ID Telegram${NC}"
    echo -e "${LINE}"
    echo -ne "${WHITE}Masukkan Data Restore : ${NC}"
    read -r link_backup

    [[ -z "$link_backup" ]] && { echo -e "${RED}Batal.${NC}"; sleep 1; return; }

    rm -f "${BACKUP_DIR}/restore.zip"

    if [[ "$link_backup" =~ ^https?:// ]]; then
        echo -e "${CYAN}[+] Mendeteksi Link URL...${NC}"
        wget -q -O "${BACKUP_DIR}/restore.zip" "$link_backup" 2>/dev/null
    elif [[ "$link_backup" =~ ^documents/ ]] || [[ "$link_backup" =~ \.zip$ ]]; then
        echo -e "${CYAN}[+] Mendeteksi File Path Telegram...${NC}"
        [[ -z "$BOT_TOKEN" ]] && { echo -e "${RED}Bot Token belum diatur!${NC}"; read -p "Enter..."; return; }
        wget -q -O "${BACKUP_DIR}/restore.zip" "https://api.telegram.org/file/bot${BOT_TOKEN}/${link_backup}" 2>/dev/null
    else
        echo -e "${CYAN}[+] Mendeteksi File ID Telegram...${NC}"
        [[ -z "$BOT_TOKEN" ]] && { echo -e "${RED}Bot Token belum diatur!${NC}"; read -p "Enter..."; return; }
        FILE_PATH=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${link_backup}" | jq -r '.result.file_path // empty')
        if [[ -n "$FILE_PATH" ]]; then
            wget -q -O "${BACKUP_DIR}/restore.zip" "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}" 2>/dev/null
        else
            echo -e "${RED}[!] File ID tidak valid.${NC}"
        fi
    fi

    if [[ ! -s "${BACKUP_DIR}/restore.zip" ]]; then
        echo -e "${RED}[!] Gagal restore. File kosong atau link bermasalah.${NC}"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${GREEN}[+] File diterima. Verifikasi dan ekstrak...${NC}"

    apt-get install -y unzip >/dev/null 2>&1
    mkdir -p "${BACKUP_DIR}/restore-tmp"

    ZIP_PASS=$(echo -n "$CHAT_ID" | md5sum | awk '{print $1}' | cut -c 1-8)
    unzip -P "$ZIP_PASS" -o "${BACKUP_DIR}/restore.zip" -d "${BACKUP_DIR}/restore-tmp" >/dev/null 2>&1 || {
        unzip -o "${BACKUP_DIR}/restore.zip" -d "${BACKUP_DIR}/restore-tmp" >/dev/null 2>&1
    }

    # Verifikasi hasil ekstrak
    if [[ ! -f "${BACKUP_DIR}/restore-tmp/usr/local/etc/xray/config.json" ]]; then
        echo -e "${RED}[!] File backup tidak valid atau password salah. Data lama AMAN.${NC}"
        rm -rf "${BACKUP_DIR}/restore-tmp" "${BACKUP_DIR}/restore.zip"
        read -p "Tekan Enter..." dummy
        return
    fi

    echo -e "${GREEN}[+] Backup valid. Membersihkan data lama...${NC}"
    rm -f /usr/local/etc/xray/config.json
    rm -f /etc/xray/vless_exp.conf /etc/xray/vmess_exp.conf /etc/xray/trojan_exp.conf
    rm -f /etc/wibutunnel/limit_ip.db /etc/wibutunnel/limit_bw.db /etc/wibutunnel/locked_users.db /etc/wibutunnel/user_usage.db
    rm -f /etc/xray/domain

    cp -a "${BACKUP_DIR}/restore-tmp/usr/local/etc/xray/config.json" /usr/local/etc/xray/ 2>/dev/null
    cp -a "${BACKUP_DIR}/restore-tmp/etc/xray/"*.conf /etc/xray/ 2>/dev/null
    cp -a "${BACKUP_DIR}/restore-tmp/etc/wibutunnel/"*.db /etc/wibutunnel/ 2>/dev/null
    cp -a "${BACKUP_DIR}/restore-tmp/etc/xray/domain" /etc/xray/ 2>/dev/null
    chmod 600 /etc/wibutunnel/*.db 2>/dev/null
    rm -rf "${BACKUP_DIR}/restore-tmp"

    if jq empty /usr/local/etc/xray/config.json >/dev/null 2>&1; then
        systemctl restart xray haproxy cron >/dev/null 2>&1
    else
        systemctl restart haproxy cron >/dev/null 2>&1
        echo -e "${RED}[!] WARNING: Config Xray hasil restore korup! Xray tidak di-restart.${NC}"
    fi
    rm -f "${BACKUP_DIR}/restore.zip"

    echo -e "${GREEN}[+] RESTORE BERHASIL! Semua data berhasil dikembalikan.${NC}"
    read -p "Tekan Enter..." dummy
}

# ===== AUTO BACKUP SCHEDULE =====
do_autobackup() {
    clear
    echo -e "${LINE}"
    echo -e "          ${WHITE}SETTING AUTO BACKUP BERJADWAL${NC}"
    echo -e "${LINE}"
    echo -e "${CYAN}Format 24 jam (contoh: ketik 3 untuk jam 03:00 WIB)${NC}"
    echo -ne " ${WHITE}Masukkan Jam (0-23) : ${NC}"
    read -r input_jam

    if [[ ! "$input_jam" =~ ^[0-9]+$ ]] || [ "$input_jam" -gt 23 ]; then
        echo -e "${RED}[!] Input harus angka 0-23.${NC}"
        sleep 2
        return
    fi

    crontab -l 2>/dev/null | grep -v "/usr/local/bin/m-backup auto" | crontab -
    (crontab -l 2>/dev/null; echo "0 $input_jam * * * /usr/local/bin/m-backup auto >> /var/log/wibu-backup.log 2>&1") | crontab -
    systemctl restart cron

    printf -v tampil_jam "%02d" "$input_jam"
    echo -e "${GREEN}[+] Auto Backup aktif setiap jam ${tampil_jam}:00 WIB.${NC}"
    echo ""
    read -p "Tekan Enter..." dummy
}

# ===== MAIN MENU =====
clear
echo -e "${LINE}"
echo -e "          ${WHITE}MENU BACKUP & RESTORE${NC}"
echo -e "${LINE}"
echo -e " ${GREEN}[1] Backup Manual ke Telegram${NC}"
echo -e " ${CYAN}[2] Restore Data (URL / File Path / File ID)${NC}"
echo -e " ${YELLOW}[3] Setup Auto Backup Berjadwal${NC}"
echo -e " ${RED}[0] Kembali ke Menu Utama${NC}"
echo -e "${LINE}"
echo -ne "${WHITE}Pilih menu: ${NC}"
read -r sub_br

case $sub_br in
    1) do_backup ; exec m-backup ;;
    2) do_restore ; exec m-backup ;;
    3) do_autobackup ; exec m-backup ;;
    0) exec menu ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; exec m-backup ;;
esac
