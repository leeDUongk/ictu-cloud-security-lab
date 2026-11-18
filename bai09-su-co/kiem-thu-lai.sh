#!/usr/bin/env bash
# Bài 9 — chạy lại hai kịch bản và trả lời hai câu hỏi cho mỗi kịch bản:
#   (1) Bị chặn chưa?   (2) Lần thử có để lại dấu vết không (bị nhìn thấy)?
# Chạy trên ONE-Lab:  bash ~/ictu-cloud-security-lab/bai09-su-co/kiem-thu-lai.sh
# Chỉ thử, không sửa cấu hình. Lần thử của kịch bản 1 là một lệnh tắt máy ảo web-paas
# bằng tài khoản sv-thu: nếu lỗi ACL vẫn còn, web-paas sẽ bị tắt thật (script tự bật lại).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
require_root_sudo

ADM="sudo -u oneadmin -H"
W=~/lab9
WEB=172.16.100.205
KHACH=172.16.100.206
SSHOPT="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes"
LOG=/var/log/one/oned.log

echo "== Kịch bản 1: tài khoản sv-thu tắt máy ảo web-paas (ACL quá rộng) =="
truoc=$(sudo wc -l "$LOG" | cut -d' ' -f1)
# Gọi theo ID: nếu sv-thu không còn quyền thì không thấy tên web-paas, lệnh theo tên sẽ
# lỗi ngay ở phía máy khách và không tới oned (không để lại dấu vết).
WID=$($ADM onevm list --no-header | awk '$4=="web-paas"{print $1; exit}')
out=$(ONE_AUTH="$W/sv-thu.auth" onevm poweroff "$WID" 2>&1); rc=$?
echo "  Lệnh của sv-thu: onevm poweroff $WID (web-paas) -> mã thoát $rc"
[[ -n "$out" ]] && echo "  $out"
sleep 2
if (( rc == 0 )); then
  log_fail "Kịch bản 1 CÒN LỌT: sv-thu tắt được web-paas. Đang bật lại web-paas."
  sleep 15; $ADM onevm resume web-paas >/dev/null 2>&1 || true
else
  log_ok "Kịch bản 1 BỊ CHẶN."
fi
dong=$(sudo tail -n +"$((truoc+1))" "$LOG" | grep -E 'one\.vm\.action (invoked|result)' | grep -v 'UID:0 ' | tail -2)
if [[ -n "$dong" ]]; then
  log_ok "Kịch bản 1 BỊ NHÌN THẤY trong oned.log:"
  echo "$dong" | cut -c1-150 | sed 's/^/    /'
else
  log_fail "Kịch bản 1 không để lại dòng nào trong oned.log."
fi

echo
echo "== Kịch bản 2: vm-khach kết nối dịch vụ nội bộ 8080 của web-paas =="
# vm-khach có thể vừa được dựng lại: khóa máy chủ SSH mới, bỏ khóa cũ trong known_hosts.
ssh-keygen -R $KHACH >/dev/null 2>&1
if ! ssh $SSHOPT root@$KHACH true 2>/dev/null; then
  log_fail "Không SSH được vào vm-khach ($KHACH). Máy ảo còn ở mạng cách ly hoặc chưa dựng lại?"
  finish_check
fi
# Bắt trên tap của vm-khach (nguồn): gói bị nhóm bảo mật của web-paas chặn sẽ không tới tap của web-paas.
TAP=$($ADM onevm show -x vm-khach | grep -o 'one-[0-9]*-0' | head -1)
PCAP=$W/bangchung/kiem-thu-lai-$(date +%H%M%S).pcap
sudo timeout 14 tcpdump -i "$TAP" -nn -U -w "$PCAP" "host $KHACH and tcp port 8080" 2>/dev/null &
sleep 2
kq=$(ssh $SSHOPT root@$KHACH "nc -z -w 3 $WEB 8080 && echo MO || echo DONG" 2>/dev/null)
wget_kq=$(ssh $SSHOPT root@$KHACH "wget -q -T 4 -O - http://$WEB:8080/sinhvien-sao-luu.csv 2>/dev/null | wc -l" 2>/dev/null)
wait
echo "  nc tới $WEB:8080: $kq; số dòng tải được: ${wget_kq:-0}"
if [[ "$kq" == DONG && "${wget_kq:-0}" == 0 ]]; then
  log_ok "Kịch bản 2 BỊ CHẶN."
else
  log_fail "Kịch bản 2 CÒN LỌT: vm-khach vẫn tới được cổng 8080."
fi
syn=$(sudo tcpdump -nn -r "$PCAP" 'tcp[tcpflags] & tcp-syn != 0 and not tcp[tcpflags] & tcp-ack != 0' 2>/dev/null | wc -l)
tra=$(sudo tcpdump -nn -r "$PCAP" "src host $WEB" 2>/dev/null | wc -l)
echo "  Bắt trên $TAP: $syn gói SYN từ vm-khach, $tra gói trả lời từ web-paas (tệp $PCAP)"
if (( syn > 0 )); then
  log_ok "Kịch bản 2 BỊ NHÌN THẤY trên giao diện tap $TAP của vm-khach."
else
  log_fail "Kịch bản 2 không thấy gói nào trên $TAP."
fi
sha256sum "$PCAP" >> "$W/bangchung/SHA256SUMS"
finish_check
