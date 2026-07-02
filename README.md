# WIBU TUNNELING v4.0 KURUMI (FINAL PERFECT) 🦋

**Ultimate Xray VPN Auto Script** dengan arsitektur paling ringan dan mutakhir. Dibangun khusus untuk memberikan performa maksimal pada VPS dengan perlindungan keamanan, manajemen memori tingkat lanjut, dan sistem limit otomatis (Algojo).

---

## ✨ Fitur Unggulan (What's New in v4.0)

🚀 **100% Zero Disk I/O (RAM Disk Logging)**
Tidak ada lagi HDD/SSD yang rusak! Seluruh aktivitas *log* koneksi Xray kini diproses murni di atas awan (RAM / `tmpfs`), menjadikan VPS **Super Snappy** dan kebal terhadap antrean baca-tulis (I/O Wait).

🧠 **Otak Algojo Generasi Baru (Awk Engine)**
Script pengawas Limit IP (Multi-Login) kini beroperasi menggunakan `awk` tingkat rendah. Kecepatannya membedah ribuan *log* dalam **1 milidetik** tanpa membebani CPU, serta akurat memblokir akun meski menggunakan nama tanpa simbol `@`.

🛡️ **Anti URL-Encoding (100% Koneksi Sukses)**
Frontend HAProxy kini kebal terhadap eror akibat *copy-paste* link klien (seperti spasi atau karakter `%2F`). Apapun linknya, routing akan selalu sampai ke *backend* tanpa error 503.

🔄 **Sistem Recovery Cerdas**
Klien yang limit atau expired **TIDAK AKAN DIHAPUS**. Mereka otomatis dimasukkan ke "Ruang Recovery" (Akses Diblokir). Saat klien memperpanjang sewa, fitur **Unlock** memungkinkan klien langsung konek tanpa perlu repot ganti link di aplikasinya!

🤖 **Bot Telegram Super Admin**
Tidak perlu repot buka aplikasi SSH/Termius! Bos bisa Create, Renew, Hapus, Lock, Cek Trafik, dan Cek Real-time Login langsung dari *chat* Telegram dengan *layout* premium nan elegan.

🚫 **Auto IPv6 Disabler**
Sudah terintegrasi fitur pemusnah IPv6 di inti OS (via sysctl & GRUB). VPS yang baru diinstal dijamin **kebal dari error `apt update`** dan masalah *routing* Xray yang disebabkan oleh konflik IPv6!

## 📦 Protokol yang Didukung
- **VLESS** (WS TLS, WS Non-TLS, gRPC)
- **VMESS** (WS TLS, WS Non-TLS, gRPC)
- **TROJAN** (WS TLS, gRPC)

---

## ⚡ Instalasi Cepat (1-Click Install)

Cukup *copy-paste* perintah berikut di terminal VPS (Ubuntu/Debian) Anda yang masih *fresh*:

```bash
apt update -y && apt install -y curl wget && bash <(curl -s https://raw.githubusercontent.com/WBVPN/wibutunnel/main/setup.sh)
```

## 📋 Daftar Menu

| Menu Utama | Sub-Fitur |
| :--- | :--- |
| **Kelola VLESS** | Create, Delete, Renew, Trial, Cek Kuota |
| **Kelola VMESS** | Create, Delete, Renew, Trial, Cek Kuota |
| **Kelola TROJAN** | Create, Delete, Renew, Trial, Cek Kuota |
| **Recovery Center** | Lock Akun, Unlock Akun, Hapus Permanen |
| **Cek Trafik** | Monitor Real-Time IP dan Bandwidth |
| **Sistem Panel** | Backup & Restore via Telegram (File ID / Path) |

---

## 📞 Support & Kontak

- **WhatsApp** : [087757315408](https://wa.me/6287757315408)
- **Telegram** : [t.me/wibuvpn](https://t.me/wibuvpn)

> **Developed by WIBU TUNNELING Team**  
> **Versi:** v4.0 KURUMI (Juli 2026)
