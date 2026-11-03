#!/bin/sh
# Bài 7 — cài ứng dụng "Đăng ký học phần" vào máy ảo web-paas (Alpine), đúng các bước B, C của Bài thực hành 5.
# Chạy TRONG máy ảo web-paas bằng root, sau khi đã chép thư mục bai05-paas vào /root:
#   sh /root/bai07-van-hanh/cai-ung-dung.sh
# Chạy lại nhiều lần không sao: bước nào đã làm thì bỏ qua.
set -eu

SRC=/root/bai05-paas
[ -d "$SRC/app" ] || { echo "[LỖI] Không thấy $SRC/app. Chép bai05-paas vào /root trước." >&2; exit 1; }

echo "[1/5] Gói hệ thống và tài khoản webapp"
apk update -q && apk add -q nginx python3 openssl curl
getent group webapp >/dev/null || addgroup -S webapp
id webapp >/dev/null 2>&1 || \
  adduser -S -D -H -h /srv/demoapp -s /sbin/nologin -G webapp webapp

echo "[2/5] Môi trường Python"
mkdir -p /srv/demoapp /var/lib/demoapp /var/log/demoapp /etc/demoapp
[ -x /srv/demoapp/venv/bin/python ] || python3 -m venv /srv/demoapp/venv
/srv/demoapp/venv/bin/pip install -q --disable-pip-version-check -r "$SRC/app/requirements.txt"

echo "[3/5] Chứng chỉ tự ký và Nginx"
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/web-paas.crt ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -subj "/CN=web-paas" -addext "subjectAltName=IP:172.16.100.205" \
    -keyout /etc/nginx/ssl/web-paas.key -out /etc/nginx/ssl/web-paas.crt 2>/dev/null
  chmod 600 /etc/nginx/ssl/web-paas.key
fi
rm -f /etc/nginx/http.d/default.conf
cp "$SRC/deploy/nginx-demoapp.conf" /etc/nginx/http.d/demoapp.conf
nginx -t 2>/dev/null

echo "[4/5] Mã nguồn (chỉ đọc), tệp bí mật, dịch vụ"
rm -rf /srv/demoapp/app
cp -r "$SRC/app" /srv/demoapp/app
chown -R root:root /srv/demoapp/app
chmod -R go-w /srv/demoapp/app
chown webapp:webapp /var/lib/demoapp /var/log/demoapp
if [ ! -f /etc/demoapp/env ]; then
  SK=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
  printf 'DEMOAPP_SECRET_KEY=%s\nDEMOAPP_DB=/var/lib/demoapp/demo.db\n' "$SK" > /etc/demoapp/env
fi
chown webapp:webapp /etc/demoapp/env && chmod 600 /etc/demoapp/env
cp "$SRC/deploy/demoapp.initd" /etc/init.d/demoapp
chmod 755 /etc/init.d/demoapp
rc-update add demoapp default >/dev/null 2>&1 || true
rc-update add nginx default >/dev/null 2>&1 || true
rc-service demoapp restart >/dev/null
rc-service nginx restart >/dev/null

echo "[5/5] Kiểm tra"
sleep 2
rc-status default | grep -E 'demoapp|nginx'
code=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1/login)
if [ "$code" = 200 ]; then
  echo "[PASS] https://172.16.100.205/login trả 200"
else
  echo "[FAIL] /login trả $code" >&2; exit 1
fi
