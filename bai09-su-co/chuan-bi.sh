#!/usr/bin/env bash
# Bài 9 — dựng môi trường mô phỏng sự cố trên ONE-Lab.
# Chạy trên ONE-Lab bằng tài khoản thường có sudo:
#   bash ~/ictu-cloud-security-lab/bai09-su-co/chuan-bi.sh
# Việc script làm (chạy lại nhiều lần không sao):
#   1. Ghi trạng thái ban đầu vào ~/lab9/truoc/ để Phần F đối chiếu khi dọn dẹp.
#   2. Tạo tài khoản thử sv-thu (nhóm users) và tệp xác thực ~/lab9/sv-thu.auth.
#   3. Tạo mạng cách ly vnet-cach-ly (cầu nối riêng cachlybr, host không có địa chỉ trên cầu này).
#   4. Tạo máy ảo vm-khach (172.16.100.206) trên vnet-paas: đóng vai một máy ảo đã bị chiếm.
#   5. Trong web-paas: tạo tệp mồi (dữ liệu giả) và dịch vụ nội bộ cổng 8080 phục vụ tệp đó.
# Script KHÔNG tạo lỗi cấu hình: hai lỗi của bài (ACL quá rộng, quy tắc 8080) do sinh viên tự gõ.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$HERE/../lib/common.sh"
require_root_sudo

ADM="sudo -u oneadmin -H"
W=~/lab9
WEB=172.16.100.205
KHACH=172.16.100.206
SSHOPT="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes"
mkdir -p "$W/truoc" "$W/bangchung"
chmod 700 "$W"
TMPD=$(mktemp -d /tmp/lab9.XXXX); chmod 755 "$TMPD"
trap 'rm -rf "$TMPD"' EXIT

ten_co() { $ADM "$1" list --no-header 2>/dev/null | awk -v n="$2" '$4==n{f=1} END{exit !f}'; }

$ADM onevm list --no-header | awk '{print $4}' | grep -qx web-paas \
  || die "Chưa có máy ảo web-paas. Dựng lại bằng: bash bai07-van-hanh/dung-web-paas.sh"

echo "[1/5] Ghi trạng thái ban đầu vào $W/truoc/"
if [[ ! -s "$W/truoc/oneacl.txt" ]]; then
  $ADM oneacl list            > "$W/truoc/oneacl.txt"
  $ADM onesecgroup show sg-web-paas > "$W/truoc/sg-web-paas.txt"
  $ADM onevnet list           > "$W/truoc/onevnet.txt"
  $ADM oneuser list           > "$W/truoc/oneuser.txt"
  $ADM onevm list             > "$W/truoc/onevm.txt"
  $ADM onetemplate list       > "$W/truoc/onetemplate.txt"
else
  echo "      Đã có từ lần chạy trước, giữ nguyên."
fi

echo "[2/5] Tài khoản thử sv-thu"
if ! $ADM oneuser list --no-header | awk '{print $2}' | grep -qx sv-thu; then
  $ADM oneuser create sv-thu "$SVTHU_PASSWORD" >/dev/null
fi
$ADM oneuser enable sv-thu >/dev/null 2>&1 || true
( umask 077; printf 'sv-thu:%s\n' "$SVTHU_PASSWORD" > "$W/sv-thu.auth" )
$ADM oneuser show sv-thu | grep -E '^(ID|NAME|GROUP|ENABLED)'

echo "[3/5] Mạng cách ly vnet-cach-ly"
if ! ten_co onevnet vnet-cach-ly; then
  cat > "$TMPD/vnet-cach-ly.txt" <<'EOF'
NAME = "vnet-cach-ly"
DESCRIPTION = "Mang cach ly: cau noi rieng, khong gateway, khong noi ra ngoai"
VN_MAD = "fw"
BRIDGE = "cachlybr"
NETWORK_ADDRESS = "10.99.99.0"
NETWORK_MASK = "255.255.255.0"
AR = [ TYPE = "IP4", IP = "10.99.99.10", SIZE = "10" ]
EOF
  $ADM onevnet create "$TMPD/vnet-cach-ly.txt" >/dev/null
fi
$ADM onevnet list | grep -E 'NAME|vnet'

echo "[4/5] Máy ảo vm-khach ($KHACH)"
if ! ten_co onetemplate vm-khach-tmpl; then
  KEY=$(cat ~/.ssh/id_ed25519.pub)
  cat > "$TMPD/vm-khach-tmpl.txt" <<EOF
NAME = "vm-khach-tmpl"
CPU = "0.5"
VCPU = "1"
MEMORY = "256"
DISK = [ IMAGE_ID = "0", SIZE = "1024" ]
NIC = [ NETWORK = "vnet-paas", NETWORK_UNAME = "oneadmin", IP = "$KHACH" ]
NIC_DEFAULT = [ MODEL = "virtio" ]
GRAPHICS = [ LISTEN = "0.0.0.0", TYPE = "vnc" ]
OS = [ ARCH = "x86_64" ]
CONTEXT = [ NETWORK = "YES", SSH_PUBLIC_KEY = "$KEY", SET_HOSTNAME = "vm-khach" ]
EOF
  $ADM onetemplate create "$TMPD/vm-khach-tmpl.txt" >/dev/null
fi
if ! ten_co onevm vm-khach; then
  $ADM onetemplate instantiate vm-khach-tmpl --name vm-khach >/dev/null
fi
WSTATE=$($ADM onevm list --no-header | awk '$4=="web-paas"{print $5; exit}')
case "$WSTATE" in poff|stop|unde|susp) $ADM onevm resume web-paas ;; esac

echo "      Chờ web-paas và vm-khach mở SSH (tối đa 3 phút)"
for ip in $WEB $KHACH; do
  for _ in $(seq 1 60); do ssh $SSHOPT root@$ip true 2>/dev/null && break; sleep 3; done
  ssh $SSHOPT root@$ip true 2>/dev/null || die "Chưa SSH được vào root@$ip"
done

echo "[5/5] Tệp mồi và dịch vụ nội bộ cổng 8080 trong web-paas"
ssh $SSHOPT root@$WEB 'sh -s' <<'EOF'
mkdir -p /srv/noibo
if [ ! -s /srv/noibo/sinhvien-sao-luu.csv ]; then
  awk 'BEGIN{srand(9); print "ma_sv,ho_ten,ngay_sinh,so_dien_thoai,danh_dau";
    for(i=1;i<=40000;i++) printf "DTC%06d,Sinh Vien Gia %d,2005-%02d-%02d,09%08d,MOI-LAB9-%05d\n",
      i,i,1+int(rand()*12),1+int(rand()*28),int(rand()*1e8),i}' > /srv/noibo/sinhvien-sao-luu.csv
fi
if ! netstat -tln 2>/dev/null | grep -q ':8080 '; then
  # Dịch vụ "nội bộ" để máy sao lưu kéo tệp; lắng nghe trên mọi địa chỉ (đây là thiết kế chưa tốt).
  busybox httpd -f -vv -p 0.0.0.0:8080 -h /srv/noibo >>/var/log/noibo.log 2>&1 &
  sleep 1
fi
ls -l /srv/noibo; netstat -tln | grep 8080
EOF

echo
log_ok "Môi trường Bài 9 đã sẵn sàng. Thư mục làm việc: $W"
$ADM onevm list
