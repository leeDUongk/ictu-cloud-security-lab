#!/bin/bash
# Doi che do CORS cua api.daotao.test.
# Dung: sudo bash che-do.sh sop|sao|phan-chieu|danh-sach|regex-sai
set -e
M="$1"
F="/etc/nginx/cors-lab/$M.conf"
[ -n "$M" ] && [ -f "$F" ] || { echo "Dung: sudo bash che-do.sh sop|sao|phan-chieu|danh-sach|regex-sai"; exit 1; }
cp "$F" /etc/nginx/cors-lab/hien-tai.conf
nginx -t 2>/dev/null
systemctl reload nginx
sleep 1   # Nginx nap lai bat dong bo
echo "Che do CORS hien tai: $M"
