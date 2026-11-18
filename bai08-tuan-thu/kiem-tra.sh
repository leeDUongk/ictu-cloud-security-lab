#!/usr/bin/env bash
# Bài 8 — bảng kiểm kỹ thuật cho ONE-Lab (Bảng kiểm mẫu, mục 8.3.2 bài giảng).
# Mỗi mục in: số thứ tự, kiểm soát ISO/IEC 27001:2022, kết quả ĐẠT / KHÔNG ĐẠT / XEM TAY và bằng chứng.
# Script chỉ ĐỌC cấu hình, không thay đổi hệ thống. Kết quả cũng được ghi vào ~/lab8/ket-qua.tsv.
# Dùng: bash bai08-tuan-thu/kiem-tra.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_root_sudo
require_cmd xmllint ss

WEBPAAS_IP="${WEBPAAS_IP:-172.16.100.205}"
OUT="$HOME/lab8/ket-qua.tsv"
mkdir -p "$(dirname "$OUT")"
printf 'TT\tKiem soat\tKet qua\tBang chung\tThoi diem\n' >"$OUT"

DAT=0; KHONG=0; XEM=0
ghi() { # ghi <tt> <kiểm soát> <ĐẠT|KHÔNG ĐẠT|XEM TAY> <bằng chứng>
  # Đệm bằng tay vì printf đếm theo byte, chữ có dấu sẽ làm lệch cột.
  local mau="$C_INFO" nhan
  case "$3" in
    "ĐẠT") mau="$C_OK"; nhan="ĐẠT       "; DAT=$((DAT + 1)) ;;
    "KHÔNG ĐẠT") mau="$C_FAIL"; nhan="KHÔNG ĐẠT "; KHONG=$((KHONG + 1)) ;;
    *) nhan="XEM TAY   "; XEM=$((XEM + 1)) ;;
  esac
  printf '%2s  %-5s %s%s%s %s\n' "$1" "$2" "$mau" "$nhan" "$C_OFF" "$4"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(date '+%F %T')" >>"$OUT"
}

echo "Bảng kiểm ONE-Lab — $(hostname), $(date '+%F %T %z')"
echo "TT  KS    Kết quả    Bằng chứng"

# 1. 5.18 — không có quy tắc ACL cấp MANAGE/ADMIN trên máy ảo cho người dùng hoặc nhóm thường.
# Cột của oneacl list: ID USER RES_... RID OPE_UMAC ZONE; cột 3 bắt đầu bằng V khi quy tắc áp cho máy ảo,
# cột 5 có m (MANAGE) hoặc a (ADMIN) khi cấp quyền quản lý.
acl_xau="$(one oneacl list 2>/dev/null | awk 'NR>1 && $2 !~ /^(#0|@0)$/ && $3 ~ /^V/ && $5 ~ /[ma]/' || true)"
so_acl="$(one oneacl list 2>/dev/null | awk 'NR>1' | wc -l)"
if [[ -z "$acl_xau" ]]; then
  ghi 1 5.18 "ĐẠT" "$so_acl quy tắc ACL; không quy tắc nào cấp MANAGE/ADMIN trên VM cho người dùng thường"
else
  ghi 1 5.18 "KHÔNG ĐẠT" "Quy tắc cấp quyền rộng: $(echo "$acl_xau" | awk '{print "ID "$1" ("$2")"}' | paste -sd' ')"
fi

# 2. 5.16 — danh sách tài khoản OpenNebula để đối chiếu với danh sách được duyệt.
users="$(one oneuser list -l NAME,GROUP 2>/dev/null | awk 'NR>1 {print $1"("$2")"}' | paste -sd' ')"
ghi 2 5.16 "XEM TAY" "Tài khoản: ${users:-không đọc được}. Đối chiếu từng tài khoản với danh sách đã duyệt"

# 3. 8.5 — SSH chỉ dùng khóa, không cho root đăng nhập.
pa="$(sudo sshd -T 2>/dev/null | awk '$1=="passwordauthentication"{print $2}')"
pr="$(sudo sshd -T 2>/dev/null | awk '$1=="permitrootlogin"{print $2}')"
if [[ "$pa" == "no" && "$pr" == "no" ]]; then
  ghi 3 8.5 "ĐẠT" "passwordauthentication $pa, permitrootlogin $pr"
else
  ghi 3 8.5 "KHÔNG ĐẠT" "passwordauthentication ${pa:-?}, permitrootlogin ${pr:-?} (cần: no, no)"
fi

# 4. 8.24 — FireEdge (2616) chỉ nghe 127.0.0.1; giao diện ra ngoài qua TLS (443).
nghe2616="$(ss -Htln 'sport = :2616' | awk '{print $4}' | paste -sd' ')"
nghe443="$(ss -Htln 'sport = :443' | awk '{print $4}' | paste -sd' ')"
if [[ -n "$nghe2616" && "$nghe2616" != *0.0.0.0* && "$nghe2616" != *"[::]"* && "$nghe2616" != \** && -n "$nghe443" ]]; then
  ghi 4 8.24 "ĐẠT" "2616 nghe ${nghe2616}; 443 nghe ${nghe443}"
else
  ghi 4 8.24 "KHÔNG ĐẠT" "2616 nghe ${nghe2616:-không}; 443 nghe ${nghe443:-không} (cần: 2616 chỉ 127.0.0.1, có TLS 443)"
fi

# 5. 8.6 — mọi nhóm (trừ oneadmin) có hạn mức số máy ảo.
thieu=""
for gid in $(one onegroup list -x 2>/dev/null | xmllint --xpath '//GROUP/ID/text()' - 2>/dev/null); do
  [[ "$gid" == 0 ]] && continue
  gname="$(one_xpath /GROUP/NAME onegroup show -x "$gid")"
  vms="$(one_xpath '/GROUP/VM_QUOTA/VM/VMS' onegroup show -x "$gid")"
  [[ -n "$vms" && "$vms" != "-1" && "$vms" != "-2" ]] || thieu+="$gname "
done
if [[ -z "$thieu" ]]; then
  ghi 5 8.6 "ĐẠT" "Mọi nhóm (trừ oneadmin) có hạn mức VMS"
else
  ghi 5 8.6 "KHÔNG ĐẠT" "Nhóm chưa có hạn mức VMS: ${thieu% }"
fi

# 6. 8.8 — không còn bản vá bảo mật chưa cài.
sec="$(apt list --upgradable 2>/dev/null | grep -c -- '-security' || true)"
tong="$(apt list --upgradable 2>/dev/null | grep -c '/' || true)"
if (( sec == 0 )); then
  ghi 6 8.8 "ĐẠT" "Không có gói bảo mật chờ cài (tổng $tong gói chờ cập nhật)"
else
  ghi 6 8.8 "KHÔNG ĐẠT" "$sec gói từ kho -security chưa cài (tổng $tong gói chờ cập nhật)"
fi

# 7. 8.13 — có datastore sao lưu (TYPE 3) và có tác vụ sao lưu.
ds_bk="$(one onedatastore list -x 2>/dev/null | xmllint --xpath 'count(//DATASTORE[TYPE=3])' - 2>/dev/null || echo 0)"
bj="$(one onebackupjob list -x 2>/dev/null | xmllint --xpath 'count(//BACKUPJOB)' - 2>/dev/null || echo 0)"
if (( ${ds_bk%.*} > 0 && ${bj%.*} > 0 )); then
  ghi 7 8.13 "ĐẠT" "$ds_bk datastore sao lưu, $bj tác vụ sao lưu (còn cần biên bản khôi phục thử)"
else
  ghi 7 8.13 "KHÔNG ĐẠT" "${ds_bk%.*} datastore sao lưu, ${bj%.*} tác vụ sao lưu"
fi

# 8. 8.15 — oned ghi nhật ký mức gỡ lỗi và nhật ký được chuyển ra máy khác.
lvl="$(sudo awk '/^LOG *=/{f=1} f && /DEBUG_LEVEL/{gsub(/[^0-9]/,"");print;exit}' /etc/one/oned.conf)"
sysl="$(sudo awk '/^LOG *=/{f=1} f && /SYSTEM/{gsub(/.*= *"|".*/,"");print;exit}' /etc/one/oned.conf)"
fwd="$(sudo grep -rhsE '^[^#]*(@@?[A-Za-z0-9.-]+|action\(.*type="omfwd")' /etc/rsyslog.conf /etc/rsyslog.d 2>/dev/null | head -1)"
if [[ -n "$fwd" && "$sysl" == "syslog" ]]; then
  ghi 8 8.15 "ĐẠT" "oned: SYSTEM=$sysl, DEBUG_LEVEL=$lvl; rsyslog chuyển tiếp: $fwd"
else
  ghi 8 8.15 "KHÔNG ĐẠT" "oned: SYSTEM=${sysl:-?}, DEBUG_LEVEL=${lvl:-?}; nhật ký chưa được chuyển ra máy khác"
fi

# 9. 8.17 — ONE-Lab đồng bộ NTP; web-paas có dịch vụ ntpd đang chạy, bật khi khởi động, lệch không quá 2 giây.
syn="$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
lech="?"; ntp="không kiểm được"
if kq="$(ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new root@"$WEBPAAS_IP" \
      'date +%s; rc-service ntpd status >/dev/null 2>&1 && echo "đang chạy" || echo "đang dừng"; rc-update show default | grep -qw ntpd && echo có || echo không' 2>/dev/null)"; then
  t2="$(sed -n 1p <<<"$kq")"; ntp="ntpd $(sed -n 2p <<<"$kq"), bật khi khởi động: $(sed -n 3p <<<"$kq")"
  lech=$(( $(date +%s) - t2 )); lech=${lech#-}
fi
if [[ "$syn" == "yes" && "$ntp" == "ntpd đang chạy, bật khi khởi động: có" && "$lech" =~ ^[0-9]+$ ]] && (( lech <= 2 )); then
  ghi 9 8.17 "ĐẠT" "ONE-Lab NTPSynchronized=yes; web-paas $ntp, lệch ${lech}s"
else
  ghi 9 8.17 "KHÔNG ĐẠT" "ONE-Lab NTPSynchronized=${syn:-?}; web-paas $ntp, lệch ${lech}s"
fi

echo
echo "Tổng: $DAT ĐẠT, $KHONG KHÔNG ĐẠT, $XEM XEM TAY. Kết quả đã ghi: $OUT"
