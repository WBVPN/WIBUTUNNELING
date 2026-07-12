# WIBUTUNNEL - AI Assistant Context Guide

Halo AI! Jika kamu membaca file ini, berarti kamu sedang membantu developer (Bosku) untuk mengembangkan project **WIBUTUNNEL**. File ini berisi ringkasan arsitektur, preferensi developer, dan aturan ketat yang wajib kamu patuhi agar tidak perlu diajari dari awal.

## 1. Filosofi & Preferensi Developer
- **Wuzz-Wuzz & Sat-Set**: Developer sangat memprioritaskan **Performa, Kecepatan, dan Keringanan**. Jangan pernah menambahkan fitur kosmetik yang memberatkan (seperti *conversational wizard*, tombol interaktif berlebihan, atau loop processing yang memakan CPU).
- **Batch Processing**: Selalu gunakan pemrosesan massal (Batch Processing). Hindari penggunaan `jq` atau *restart service* (seperti Xray) di dalam *loop* (perulangan). Kumpulkan data dalam *array*, lalu eksekusi satu kali di akhir.
- **Minimalis**: Fitur yang tidak berguna atau memberatkan (seperti `/topmember`) tidak disukai. Jangan asal menambahkan fitur yang tidak berfokus pada fungsi inti VPN manager.

## 2. Arsitektur Inti (Wajib Tahu)
- **bot-daemon.sh** (`/usr/local/bin/bot-daemon`): Jantung dari Bot Telegram. Menggunakan sistem *Long Polling* dengan `curl` secara manual. Pemanggilan API ke Telegram **wajib** menggunakan mode *Asynchronous* (ditambahkan `&` di akhir perintah curl) agar *event loop* tidak terhambat (*blocking*). Format list IP menggunakan pembatasan (maksimal 3 IP) untuk mencegah *spamming* di layar Telegram.
- **algojo-wibu** (`/usr/local/bin/algojo-wibu`): Sistem deteksi limit IP. Berjalan setiap beberapa menit, membaca `access.log` Xray menggunakan `awk` (sangat cepat), membandingkannya dengan `limit_ip.db`. Menggunakan logika **Batch Locking** (mengumpulkan user yang melanggar, lalu menguncinya sekaligus).
- **algojo-kuota** (`/usr/local/bin/algojo-kuota`): Sistem deteksi limit Kuota Bandwidth. Menggunakan `awk` untuk *batch processing* update database pemakaian (`user_usage.db`). Juga menggunakan **Batch Locking**.
- **xp.sh** (`/usr/local/bin/xp`): Skrip auto-delete user expired. Menggunakan *Batch Processing* (1x jq call) dan memiliki fitur **Log Rotation** untuk memotong `/var/log/xray/access.log` jika ukurannya melebihi 50MB agar disk VPS tidak penuh.
- **m-setting.sh / m-backup.sh**: Skrip menu untuk CLI. Fitur `Update Script (Safe Mode)` dirancang untuk memperbarui seluruh komponen (termasuk folder `sbin` dan `menu`) dan otomatis me-*restart* bot.

## 3. Database & File Penting
- Database IP: `/etc/wibutunnel/limit_ip.db` (Format `user:max_ip`)
- Database Kuota: `/etc/wibutunnel/limit_bw.db` (Format `user:limit_gb`)
- Pemakaian Kuota: `/etc/wibutunnel/user_usage.db` (Format `user:used_bytes:last_bytes`)
- Daftar Banned: `/etc/wibutunnel/locked_users.db` (Format `user:lock_time:unlock_time:reason`)

## 4. Aturan Coding / Modifikasi
1. **Jangan Menggunakan Bash Loop untuk I/O Berat**: Gunakan `awk` untuk memproses ratusan/ribuan baris teks.
2. **Restart Xray Seminimal Mungkin**: Menggunakan perintah `systemctl restart xray` memutuskan koneksi user aktif. Hanya lakukan 1x setelah semua perubahan file `config.json` selesai ditulis (Batching).
3. **Format Pesan Telegram**: Gunakan format HTML Telegram dengan ikon agar elegan, namun pastikan untuk melimitasi output yang panjang (seperti list IP address). Backup menggunakan metode `editMessageCaption` agar File ID menyatu dengan dokumen zip.

---
*Pesan untuk AI: Patuhi aturan di atas dan langsung eksekusi tanpa banyak basa-basi!*
