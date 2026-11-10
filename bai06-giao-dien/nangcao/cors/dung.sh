#!/bin/bash
# Dung moi truong Bai tap nang cao 2 cua Bai thuc hanh 6 (CORS) tren ONE-Lab.
# Chay: sudo bash dung.sh   (tu thu muc bai06-giao-dien/nangcao/cors)
# Cai Nginx (chi nghe cong 443), chung chi tu ky cho bon ten mien gia lap, API mau o 127.0.0.1:8000.
set -e
D="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Can chay bang sudo"; exit 1; }

echo "[1/5] Cai Nginx"
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >/dev/null
rm -f /etc/nginx/sites-enabled/default   # cong 80 dang dung cho Sunstone cu, Nginx chi nghe 443

echo "[2/5] Tao chung chi tu ky cho cac ten mien .test"
mkdir -p /etc/nginx/cors-lab /var/www/cors-lab /opt/cors-lab
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=daotao.test" \
  -addext "subjectAltName=DNS:api.daotao.test,DNS:portal.daotao.test,DNS:cntt.khoa.test,DNS:la.test,DNS:ladaotao.test" \
  -keyout /etc/nginx/cors-lab/tls.key -out /etc/nginx/cors-lab/tls.crt 2>/dev/null
chmod 600 /etc/nginx/cors-lab/tls.key

echo "[3/5] Chep cau hinh, trang thu, API"
cp "$D"/che-do/*.conf /etc/nginx/cors-lab/
cp "$D/che-do/sop.conf" /etc/nginx/cors-lab/hien-tai.conf
cp "$D/trang/thu.html" /var/www/cors-lab/
cp "$D/api.py" /opt/cors-lab/
cp "$D/nginx-cors.conf" /etc/nginx/sites-available/cors-lab
ln -sf /etc/nginx/sites-available/cors-lab /etc/nginx/sites-enabled/cors-lab

echo "[4/5] Chay API mau (tai khoan tam, khong dac quyen)"
systemctl stop cors-api 2>/dev/null || true
systemd-run --quiet --unit=cors-api -p DynamicUser=yes /usr/bin/python3 /opt/cors-lab/api.py
sleep 1

echo "[5/5] Khoi dong lai Nginx"
# Luc cai, Nginx khong chay duoc vi cong 80 da co Sunstone cu; nay da bo site mac dinh nen khoi dong lai.
nginx -t 2>&1 | tail -1
systemctl restart nginx
sleep 1
echo "Xong. Che do CORS hien tai: sop"
echo "Tren may Windows, them vao tep hosts (quyen quan tri):"
echo "  192.168.50.10  api.daotao.test portal.daotao.test cntt.khoa.test la.test ladaotao.test"
