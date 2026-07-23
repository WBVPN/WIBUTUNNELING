#!/bin/bash
# ==========================================
# WIBU TUNNELING - MIGRATION SCRIPT V2
# ==========================================
# Digunakan untuk VPS lama yang sudah terinstall V1
# agar bisa memakai arsitektur gRPC Zero Downtime.

RED='\e[1;31m'
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
WHITE='\e[1;37m'
NC='\e[0m'
LINE="${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

clear
echo -e "$LINE"
echo -e "      ${WHITE}MIGRASI KE ZERO DOWNTIME V2${NC}"
echo -e "$LINE"

REPO="https://raw.githubusercontent.com/WBVPN/WIBUTUNNEL/main"
CONFIG="/usr/local/etc/xray/config.json"
CACHE_BYPASS="t=$(date +%s)"

echo -e "[1/4] Mengunduh dependensi wibu-utils.sh..."
wget -qO /usr/local/bin/wibu-utils.sh "${REPO}/wibu-utils.sh?${CACHE_BYPASS}"
chmod +x /usr/local/bin/wibu-utils.sh

echo -e "[2/4] Patching Xray config.json untuk API Handler..."
if grep -q "HandlerService" "$CONFIG"; then
    echo -e "      ${GREEN}Config sudah menggunakan HandlerService.${NC}"
else
    TMP_CFG=$(mktemp)
    jq '
      .api.services |= (. + ["HandlerService"] | unique) |
      .inbounds[1].tag = "vless-ws-tls" |
      .inbounds[2].tag = "vmess-ws-tls" |
      .inbounds[3].tag = "trojan-ws-tls" |
      .inbounds[4].tag = "vless-grpc" |
      .inbounds[5].tag = "vmess-grpc" |
      .inbounds[6].tag = "trojan-grpc" |
      .inbounds[7].tag = "vless-ws-ntls" |
      .inbounds[8].tag = "vmess-ws-ntls"
    ' "$CONFIG" > "$TMP_CFG"
    
    if jq empty "$TMP_CFG" >/dev/null 2>&1; then
        mv "$TMP_CFG" "$CONFIG"
        echo -e "      ${GREEN}Patch config.json berhasil.${NC}"
    else
        echo -e "      ${RED}Gagal memodifikasi config.json!${NC}"
        rm -f "$TMP_CFG"
        exit 1
    fi
fi

echo -e "[3/4] Mengunduh ulang semua script core & menu..."
cd /usr/local/bin
wget -qO m-vless "${REPO}/menu/m-vless.sh?${CACHE_BYPASS}"
wget -qO m-vmess "${REPO}/menu/m-vmess.sh?${CACHE_BYPASS}"
wget -qO m-trojan "${REPO}/menu/m-trojan.sh?${CACHE_BYPASS}"
wget -qO m-setting "${REPO}/menu/m-setting.sh?${CACHE_BYPASS}"
wget -qO m-backup "${REPO}/menu/m-backup.sh?${CACHE_BYPASS}"
wget -qO bot-daemon "${REPO}/menu/bot-daemon.sh?${CACHE_BYPASS}"
wget -qO cek-trafik "${REPO}/menu/cek-trafik.sh?${CACHE_BYPASS}"
wget -qO menu-recovery "${REPO}/menu/menu-recovery.sh?${CACHE_BYPASS}"
wget -qO menu-lock "${REPO}/menu/menu-lock.sh?${CACHE_BYPASS}"
wget -qO menu-unlock "${REPO}/menu/menu-unlock.sh?${CACHE_BYPASS}"
wget -qO common.sh "${REPO}/common.sh?${CACHE_BYPASS}"
chmod +x *

cd /usr/local/sbin
wget -qO lock-user "${REPO}/sbin/lock-user?${CACHE_BYPASS}"
wget -qO unlock-user "${REPO}/sbin/unlock-user?${CACHE_BYPASS}"
wget -qO algojo-wibu "${REPO}/sbin/algojo-wibu?${CACHE_BYPASS}"
chmod +x *

# Patch Wibu Daemon
sed -i 's/sleep 10/sleep 30/g' /usr/local/bin/wibu-daemon 2>/dev/null

echo -e "[4/4] Restarting system services..."
systemctl restart xray
systemctl restart wibutunnel-bot
systemctl restart wibu-daemon

echo -e "$LINE"
echo -e "${GREEN}MIGRASI V2 BERHASIL!${NC}"
echo -e "Silakan ketik ${WHITE}menu${NC} untuk kembali."
echo -e "$LINE"
