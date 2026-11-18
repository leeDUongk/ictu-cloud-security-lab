#!/usr/bin/env bash
# Bài 9 — dọn môi trường mô phỏng và đối chiếu với trạng thái ban đầu (~/lab9/truoc/).
# Chạy trên ONE-Lab:  bash ~/ictu-cloud-security-lab/bai09-su-co/don-dep.sh
# Xóa: máy ảo vm-khach, template vm-khach-tmpl, mạng vnet-cach-ly, tài khoản sv-thu,
#      quy tắc ACL thử còn sót, dịch vụ 8080 và tệp mồi trong web-paas.
# Giữ: thư mục ~/lab9 (bằng chứng, báo cáo) và các khắc phục đã làm ở Phần D.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
require_root_sudo

ADM="sudo -u oneadmin -H"
W=~/lab9
WEB=172.16.100.205
SSHOPT="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes"

echo "[1/5] Xóa máy ảo vm-khach"
for id in $($ADM onevm list --no-header | awk '$4=="vm-khach"{print $1}'); do
  $ADM onevm terminate --hard "$id" && echo "      đã xóa máy ảo $id"
done
for _ in $(seq 1 30); do
  $ADM onevm list --no-header | awk '{print $4}' | grep -qx vm-khach || break; sleep 2
done

echo "[2/5] Xóa template vm-khach-tmpl và mạng vnet-cach-ly"
$ADM onetemplate delete vm-khach-tmpl 2>/dev/null && echo "      đã xóa vm-khach-tmpl"
$ADM onevnet delete vnet-cach-ly 2>/dev/null && echo "      đã xóa vnet-cach-ly"
# OpenNebula không xóa cầu nối trên host khi xóa mạng ảo; cầu nối cachlybr không còn máy nào gắn vào.
if ip link show cachlybr >/dev/null 2>&1 && [ -z "$(ip -br link show master cachlybr)" ]; then
  sudo ip link delete cachlybr && echo "      đã xóa cầu nối cachlybr trên host"
fi

echo "[3/5] Xóa quy tắc ACL thử còn sót và tài khoản sv-thu"
for id in $($ADM oneacl list --no-header | awk '$2=="@1" && $3 ~ /^V/ && $5 ~ /m/ {print $1}'); do
  $ADM oneacl delete "$id" && echo "      đã xóa quy tắc ACL $id"
done
$ADM oneuser delete sv-thu 2>/dev/null && echo "      đã xóa sv-thu"
rm -f "$W/sv-thu.auth"

echo "[4/5] Dừng dịch vụ 8080 và xóa tệp mồi trong web-paas"
if ssh $SSHOPT root@$WEB true 2>/dev/null; then
  ssh $SSHOPT root@$WEB 'pkill -f "[h]ttp.server 8080"; rm -rf /srv/noibo /var/log/noibo.log /etc/local.d/noibo.start /etc/noibo.conf; echo "so cong 8080 con nghe: $(netstat -tln | grep -c ":8080 ")"'
else
  log_fail "web-paas đang tắt: bật lại ($ADM onevm resume web-paas) rồi chạy lại don-dep.sh."
fi

echo "[5/5] Đối chiếu với trạng thái ban đầu"
TMPD=$(mktemp -d)
$ADM oneacl list  > "$TMPD/oneacl.txt"
$ADM oneuser list > "$TMPD/oneuser.txt"
$ADM onevnet list > "$TMPD/onevnet.txt"
for f in oneacl oneuser onevnet; do
  if diff -q <(awk '{$NF=""; print}' "$W/truoc/$f.txt" | sed 's/ *$//') \
             <(awk '{$NF=""; print}' "$TMPD/$f.txt" | sed 's/ *$//') >/dev/null; then
    log_ok "$f giống trạng thái ban đầu"
  else
    log_fail "$f khác trạng thái ban đầu:"
    diff "$W/truoc/$f.txt" "$TMPD/$f.txt" | sed 's/^/    /'
  fi
done
rm -rf "$TMPD"
$ADM onesecgroup show sg-web-paas | sed -n '/RULES/,$p'
finish_check
