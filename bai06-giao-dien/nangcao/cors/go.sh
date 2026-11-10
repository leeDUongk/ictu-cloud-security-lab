#!/bin/bash
# Go moi truong Bai tap nang cao 2 (CORS), dua ONE-Lab ve nhu truoc khi dung.
# Chay: sudo bash go.sh
# Luu y: lenh purge go ca Nginx. Neu Nginx cua Bai thuc hanh 6 van dang dung thi khong chay tep nay.
[ "$(id -u)" -eq 0 ] || { echo "Can chay bang sudo"; exit 1; }
systemctl stop cors-api 2>/dev/null
DEBIAN_FRONTEND=noninteractive apt-get purge -y nginx nginx-common >/dev/null
rm -rf /etc/nginx /var/www/cors-lab /opt/cors-lab /var/log/nginx
echo "Da go. Nho xoa dong *.test trong tep hosts cua Windows."
