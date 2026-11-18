#!/usr/bin/env bash
# Bài 8 — thu thập bằng chứng cấu hình ONE-Lab cho phân tích theo ISO/IEC 27001.
# Mỗi lệnh ghi ra một tệp, đầu tệp có: lệnh, thời điểm, máy, người chạy.
# Cuối cùng tính SHA-256 của mọi tệp vào SHA256SUMS để chứng minh bằng chứng không bị sửa.
# Dùng: bash bai08-tuan-thu/thu-thap.sh [thư mục đích]   (mặc định ~/lab8/bangchung)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"

require_root_sudo

GOC="${1:-$HOME/lab8/bangchung}"
DICH="$GOC/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DICH"
chmod 700 "$GOC" "$DICH"

# ten_tep|mô tả (kiểm soát)|lệnh
DANHSACH=(
  "01-onehost|Danh mục host (5.9)|sudo -u oneadmin -H onehost list"
  "02-onevm|Danh mục máy ảo (5.9)|sudo -u oneadmin -H onevm list"
  "03-oneimage|Danh mục image (5.9)|sudo -u oneadmin -H oneimage list"
  "04-onedatastore|Datastore (5.9, 8.13)|sudo -u oneadmin -H onedatastore list"
  "05-onevnet|Mạng ảo (5.9, 8.20)|sudo -u oneadmin -H onevnet list"
  "06-onesecgroup|Nhóm bảo mật (8.20, 8.22)|sudo -u oneadmin -H onesecgroup list"
  "07-oneuser|Người dùng OpenNebula (5.16)|sudo -u oneadmin -H oneuser list"
  "08-onegroup|Nhóm OpenNebula (5.3, 5.15)|sudo -u oneadmin -H onegroup list"
  "09-oneacl|Quy tắc ACL (5.15, 5.18)|sudo -u oneadmin -H oneacl list"
  "10-onevdc|VDC (8.22)|sudo -u oneadmin -H onevdc list"
  "11-onebackupjob|Tác vụ sao lưu (8.13)|sudo -u oneadmin -H onebackupjob list"
  "12-phienban|Phiên bản OpenNebula (8.8)|oned -v | head -1; dpkg-query -W opennebula opennebula-fireedge"
  "13-capnhat|Gói chờ cập nhật (8.8)|apt list --upgradable"
  "14-cong|Cổng đang nghe (8.20, 8.24)|sudo ss -tlnp"
  "15-sshd|Cấu hình SSH hiệu lực (8.5)|sudo sshd -T"
  "16-thoigian|Đồng bộ thời gian (8.17)|timedatectl"
  "17-dacquyen|Thành viên nhóm sudo, oneadmin (8.2)|getent group sudo oneadmin"
  "18-sudoers|Tệp sudoers bổ sung (8.2)|sudo ls -l /etc/sudoers.d"
  "19-log-cauhinh|Cấu hình nhật ký oned (8.15)|sudo grep -A4 ^LOG /etc/one/oned.conf"
  "20-log-tep|Tệp nhật ký OpenNebula (8.15)|sudo ls -l /var/log/one"
  "21-logrotate|Xoay vòng nhật ký OpenNebula (8.15)|sudo cat /etc/logrotate.d/opennebula"
)

log_info "Thư mục bằng chứng: $DICH"
for muc in "${DANHSACH[@]}"; do
  IFS='|' read -r ten mota lenh <<<"$muc"
  tep="$DICH/$ten.txt"
  {
    echo "# Bang chung: $mota"
    echo "# Lenh      : $lenh"
    echo "# Thoi diem : $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "# May       : $(hostname)"
    echo "# Nguoi chay: $(id -un)"
    echo "#"
    bash -c "$lenh" 2>&1
    echo "# Ma thoat  : $?"
  } >"$tep"
  printf '  %-18s %s\n' "$ten" "$mota"
done

( cd "$DICH" && sha256sum ./*.txt >SHA256SUMS )
chmod 600 "$DICH"/*
log_ok "Đã ghi $(ls "$DICH"/*.txt | wc -l) tệp bằng chứng và SHA256SUMS."
echo "Kiểm tra toàn vẹn sau này: cd $DICH && sha256sum -c SHA256SUMS"
